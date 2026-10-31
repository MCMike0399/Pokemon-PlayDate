#!/usr/bin/env python3
"""Prepare an exact checkpoint B portal census. --execute is root-only.

No runtime locks, Simulator preferences, USB, GUI or Data are touched unless
--execute is explicitly supplied. Run from this implementation checkout, with
--project pointing at the immutable production input checkout.
"""
import argparse
import ctypes
from bisect import bisect_right
from collections import Counter
from contextlib import ExitStack
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = '0bc2e5fe8a79cda83602c7e754ad832e8c24ccff'
DIRECTIONS = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}
CARDINAL = {'north': 'up', 'south': 'down', 'west': 'left', 'east': 'right'}
CLASSIFICATION = 'isolated setup plus real portal input; not natural journey, earned traversal or device acceptance'
MAX_PROCESS_BYTES = 1024**3
MAX_ROW_WAIT_SECONDS = 60


class _ProcessUsage(ctypes.Structure):
    _fields_ = [('uuid', ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64) for name in (
            'user_time', 'system_time', 'pkg_idle_wkups', 'interrupt_wkups',
            'pageins', 'wired_size', 'resident_size', 'phys_footprint',
            'proc_start_abstime', 'proc_exit_abstime')]


_rusage_function = None


def process_footprint(pid):
    """macOS rusage_info_v0; includes compressed/swapped footprint, unlike RSS."""
    global _rusage_function
    if _rusage_function is None:
        library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
        _rusage_function = library.proc_pid_rusage
        _rusage_function.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        _rusage_function.restype = ctypes.c_int
    usage = _ProcessUsage()
    if _rusage_function(pid, 0, ctypes.byref(usage)) != 0:
        raise OSError(ctypes.get_errno(), 'cannot inspect owned Simulator footprint')
    return usage.phys_footprint


def check_host_limits(footprint, elapsed_without_row):
    if footprint > MAX_PROCESS_BYTES:
        raise RuntimeError('owned Simulator exceeds 1 GiB host footprint; stop this diagnostic')
    if elapsed_without_row > MAX_ROW_WAIT_SECONDS:
        raise RuntimeError('no completed census row for 60 seconds; stop this diagnostic')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')


def tooling(project):
    # Import the INPUT checkout's production staging and identity tooling, not
    # this worker's potentially different map count, exclusions or qualifiers.
    sys.path.insert(0, str(project))
    from tools import build
    from tools.device.build_smoke import manifest
    from tools.device_cycle import inventory, tree_hash
    from tools.harness import run
    from tools.harness.protocol import OwnerLock, atomic_json
    if Path(build.__file__).resolve().parents[1] != project:
        raise ValueError('production staging tooling was imported from another checkout')
    return build, manifest, inventory, tree_hash, run, OwnerLock, atomic_json


def cell(compact, descriptor, x, y):
    if not (0 <= x < descriptor['width'] and 0 <= y < descriptor['height']):
        return None
    index = int(descriptor['tile_rows'][y][2*x:2*x+2], 16)
    value = compact['tiles'][descriptor['palette'][index-1]]
    return dict(key=value['key'], collision=1 if str(y*descriptor['width']+x+1) in descriptor['blocked']
                else value['collision'], terrain=value['terrain'])


def approaches(compact, d, x, y, edge=None):
    result = []
    for direction, (dx, dy) in DIRECTIONS.items():
        if edge and edge != direction:
            continue
        ax, ay = (x, y) if edge else (x-dx, y-dy)
        surface = cell(compact, d, ax, ay)
        result.append(dict(x=ax, y=ay, direction=direction,
                           geometry_gap='outside source geometry' if surface is None else
                           ('solid source approach' if surface['collision'] else None),
                           tile_key=surface['key'] if surface else None))
    return result


def authored_inventory(source):
    """Strictly read the existing literal authored door tables, never evaluate Lua.

    These declarations are candidates only. Runtime rechecks the actual Zone
    door table and collision. Unsupported syntax fails rather than omitting it.
    """
    text = (source / 'data/maps.lua').read_text()
    zones = list(re.finditer(r'registerZone\("([^"]+)", Zone\(\{', text))
    rows = []
    for i, match in enumerate(zones):
        block = text[match.end():zones[i+1].start() if i+1 < len(zones) else len(text)]
        tables = list(re.finditer(r'\bdoors\s*=\s*\{(.*?)\n\s*\},', block, re.S))
        if not tables and not re.search(r'\bdoors\s*=', block):
            continue  # Source-owned authored test map has no portal declaration.
        if len(tables) != 1:
            raise ValueError('authored door table shape changed: ' + match[1])
        body = tables[0][1]
        literals = re.findall(r'\{([^{}]+)\}', body)
        remainder = re.sub(r'\{[^{}]+\}|--[^\n]*|[\s,]', '', body)
        if remainder:
            raise ValueError('unsupported authored door syntax')
        for n, literal in enumerate(literals, 1):
            fields = dict(re.findall(r'(\w+)\s*=\s*("[^"]*"|-?\d+)', literal))
            residual = re.sub(r'\w+\s*=\s*("[^"]*"|-?\d+)|[\s,]', '', literal)
            if residual or not {'x', 'y', 'to', 'toX', 'toY'} <= fields.keys():
                raise ValueError('unsupported authored door fields')
            door = {k: json.loads(v) for k, v in fields.items()}
            row = dict(id=f'authored:{match[1]}:door:{n}', kind='authored_door',
                       source_name=match[1], source_key=match[1], source_id=match[1],
                       source_file='data/maps.lua', declaration=door, x=door['x'], y=door['y'],
                       target_class='authored', edge=door.get('edge'))
            row['approaches'] = [dict(x=door['x'] if door.get('edge') else door['x']-dx,
                                     y=door['y'] if door.get('edge') else door['y']-dy,
                                     direction=direction, geometry_gap=None)
                                 for direction, (dx, dy) in DIRECTIONS.items()
                                 if not door.get('edge') or direction == door['edge']]
            rows.append(row)
    # This is an explicit source-owned adapter, separate from manifest targets.
    seam = (source / 'data/viridianSlice.lua').read_text()
    anchor = 'name=="pallet_town" and direction=="up" and y==0 and (x==9 or x==10)'
    if seam.count(anchor) != 1:
        raise ValueError('authored Pallet seam changed; inventory adapter needs review')
    for x in (9, 10):
        rows.append(dict(id=f'authored:pallet_town:connection:up:{x}', kind='authored_connection',
                         source_name='pallet_town', source_key='pallet_town', source_id='pallet_town',
                         source_file='data/viridianSlice.lua', x=x, y=0, direction='up',
                         target_class='manifest', declared_target='Route1',
                         approaches=[dict(x=x, y=0, direction='up', geometry_gap=None)]))
    return rows


def build_inventory(project):
    source = project / 'Source'
    manifest = json.loads((source / 'data/sourceMaps.json').read_bytes())
    compact = json.loads((source / 'data/sourceMapCache/compact.json').read_bytes())
    maps = manifest['maps']
    if set(compact['maps']) != set(maps):
        raise ValueError('compact map inventory differs from manifest')
    if compact['manifest_sha256'] != sha(source / 'data/sourceMaps.json'):
        raise ValueError('compact cache manifest identity differs')
    entries, map_rows = [], []
    for name, entry in sorted(maps.items()):
        path = source / entry['path']
        if not path.resolve().is_relative_to(source.resolve()) or path.is_symlink() or sha(path) != entry['source_sha256']:
            raise ValueError('source input pin mismatch: ' + name)
        raw = json.loads(path.read_bytes())
        d = compact['maps'][name]
        width, height = raw['dimensions']['cells']
        if (raw['id'], width + 2*entry['padding'] <= entry['width'], height) != (entry['id'], True, entry['height']):
            raise ValueError('source geometry differs: ' + name)
        if len(raw['events']['warps']) != len(d['warps']) or raw['connections'] != d['connections']:
            raise ValueError('generated portal inventory differs: ' + name)
        base = dict(source_name=name, source_key=entry['key'], source_id=entry['id'], source_file=entry['path'])
        for original, event in zip(raw['events']['warps'], d['warps']):
            if (original['id'], original['x']+entry['padding'], original['y'], original['destination']) != (
                    event['id'], event['x'], event['y'], event['destination']):
                raise ValueError('padded source warp differs: ' + event['id'])
            scripted = event['id'] in entry.get('scripted_warps', [])
            edge = 'down' if not scripted and (entry['profile'] == 'viridian' or
                d['tileset']['constant'] not in ('OVERWORLD', 'FOREST')) and event['y'] == d['height']-1 else None
            entries.append(dict(base, id=event['id'], kind='warp', source_index=event['source_index'],
                                x=event['x'], y=event['y'], source_x=original['x'], source_y=original['y'],
                                destination=event['destination'], last_outdoor=d.get('last_outdoor'),
                                scripted=scripted, declared_blocked=event['id'] in entry.get('blocked_events', []),
                                surface_blocked=str(event['y']*d['width']+event['x']+1) in d['blocked'],
                                target_class='runtime_script' if scripted else 'manifest_or_unresolved', edge=edge,
                                approaches=approaches(compact, d, event['x'], event['y'], edge)))
        for n, connection in enumerate(raw['connections'], 1):
            direction = CARDINAL[connection['direction']]
            vertical = direction in ('up', 'down')
            for lateral in range(d['width'] if vertical else d['height']):
                x = lateral if vertical else (0 if direction == 'left' else d['width']-1)
                y = (0 if direction == 'up' else d['height']-1) if vertical else lateral
                surface = cell(compact, d, x, y)
                entries.append(dict(base, id=f'{entry["id"]}:connection:{n}:{direction}:{lateral}',
                                    kind='connection', connection_index=n, declaration=connection,
                                    x=x, y=y, direction=direction,
                                    declared_blocked=connection['direction']+':'+connection['target_map'] in d['blocked_connections'],
                                    target_class='authored_seam' if connection['target_map']=='PALLET_TOWN' else
                                    ('manifest' if any(v['id']=='pokered:'+connection['target_map'] for v in maps.values()) else 'outside_manifest'),
                                    approaches=[dict(x=x, y=y, direction=direction,
                                                     geometry_gap='solid source approach' if surface['collision'] else None,
                                                     tile_key=surface['key'])]))
        map_rows.append(dict(name=name, **entry, warps=len(raw['events']['warps']),
                             directional_connections=len(raw['connections'])))
    entries.extend(authored_inventory(source))
    if len({row['id'] for row in entries}) != len(entries):
        raise ValueError('duplicate census case identity')
    return dict(schema=1, classification=CLASSIFICATION, maps=map_rows, entries=entries,
                counts=dict(maps=len(maps), directional_connections=sum(r['directional_connections'] for r in map_rows),
                            **Counter(row['kind'] for row in entries)),
                source_manifest_sha256=sha(source / 'data/sourceMaps.json'),
                resolution='declared destinations only; actual SourceMaps warpSpec/connection and live Zone owners resolve at runtime')


def prepare(project, sdk, output, earned=None, only=None):
    build, manifest, inventory, tree_hash, run, _, _ = tooling(project)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
    if revision != EXPECTED:
        raise ValueError('expected exact B ' + EXPECTED + ', found ' + revision)
    dirty = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all', '--', 'Source', 'tools'],
                                    cwd=project, text=True).strip()
    if dirty:
        raise ValueError('exact input Source/tooling must be clean: ' + dirty)
    if (sdk / 'VERSION.txt').read_text().strip() != '3.1.2':
        raise ValueError('SDK 3.1.2 required')
    original = manifest(project / 'Source')
    census = build_inventory(project)
    if census['counts']['maps'] != 149:
        raise ValueError('exact checkpoint B needs all 149 input maps')
    output.mkdir(parents=True, exist_ok=False)
    source = build.stage_production(project, output)
    production = manifest(source)
    write_json(output / 'inventory.json', census)
    selected = census['entries']
    if only:
        selected = [row for row in selected if row['id'] in only]
        if {r['id'] for r in selected} != set(only):
            raise ValueError('unknown --case identity')
    case_dir = source / 'census'
    case_dir.mkdir()
    for i, row in enumerate(selected, 1):
        write_json(case_dir / f'{i}.json', row)
    identity = uuid.uuid4().hex
    config = dict(schema=1, build_id=identity, count=len(selected), earned=bool(earned),
                  classification=CLASSIFICATION, trials=2, max_frames=240,
                  seed_restore_policy='once per bounded process; actual case effects retained',
                  gc_policy='explicit boundary GC plus loading-suspension collection at 8 MiB; diagnostic only')
    write_json(case_dir / 'config.json', config)
    seed = None
    if earned:
        from tools.harness.startup_probe import seed_saves
        seed = seed_saves(earned, output)
    (source / 'dev').mkdir()
    shutil.copyfile(ROOT / 'Source/dev/doorCensus.lua', source / 'dev/doorCensus.lua')
    main = source / 'main.lua'
    original_main = main.read_text()
    hook = '\nimport "dev/doorCensus"\nGameBootstrap.afterReady(function() DoorCensus.install() end)\n'
    main.write_text(original_main + hook)
    (output / 'uninstrumented-main.lua').write_text(original_main)
    info = source / 'pdxinfo'
    lines = info.read_text().splitlines()
    if sum(line.startswith('bundleID=') for line in lines) != 1:
        raise ValueError('one private bundleID required')
    bundle_id = 'com.poc.pokemon.doorcensus.' + identity
    info.write_text('\n'.join('bundleID='+bundle_id if line.startswith('bundleID=') else line for line in lines)+'\n')
    staged = manifest(source)
    changed = {n for n in production if staged.get(n) != production[n]}
    added = set(staged)-set(production)
    if changed != {'main.lua', 'pdxinfo'} or added != {'dev/doorCensus.lua'} | {
            'census/'+p.name for p in case_dir.iterdir()}:
        raise ValueError('private overlay exceeded diagnostic boundary')
    bundle = output / 'DoorCensus.pdx'
    compiler = sdk / 'bin/pdc'
    compiler_hash = sha(compiler)
    with (output / 'compile.log').open('w') as log:
        subprocess.run([str(compiler), str(source), str(bundle)], stdout=log, stderr=subprocess.STDOUT, check=True)
    current_revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
    if current_revision != revision or manifest(project / 'Source') != original or sha(compiler) != compiler_hash:
        raise ValueError('input or compiler changed during preparation')
    payload = inventory(bundle)
    metadata = dict(schema=1, mode='door-census-compile-only', runtime_executed=False,
                    classification=CLASSIFICATION, build_id=identity, bundle_id=bundle_id, bundle=str(bundle),
                    project=str(project), revision=revision, sdk=str(sdk), sdk_version='3.1.2',
                    compiler_sha256=compiler_hash, project_source_manifest=original,
                    project_source_sha256=tree_hash(original), production_source_manifest=production,
                    production_source_sha256=tree_hash(production), compiled_source_manifest=staged,
                    compiled_source_sha256=tree_hash(staged), source_sha256=run.fingerprint(output, exclude_generated=False),
                    pdx_files=payload, pdx_sha256=tree_hash(payload), seed_saves=seed,
                    inventory_sha256=sha(output / 'inventory.json'), counts=census['counts'],
                    selected_cases=len(selected), selected_ids=[r['id'] for r in selected],
                    implementation_sha256=sha(Path(__file__)), observer_sha256=sha(ROOT / 'Source/dev/doorCensus.lua'))
    write_json(output / 'build.json', metadata)
    write_json(output / 'preparation.json', dict(runtime_executed=False,
        counts=census['counts'], selected_cases=len(selected), planned_trials=2*len(selected),
        static_surface_blocked_warps=sum(r.get('surface_blocked', False) for r in selected),
        scripted_warps=sum(r.get('scripted', False) for r in selected),
        earned_save_supplied=bool(earned), gaps=['Runtime has not been executed.',
        'Actor, script, field and arrival feasibility require the real runtime.',
        'Cache labels describe actual provider residency, not an enforced cold content cache.',
        'The first available static land approach is attempted; other approaches remain inventoried.']))
    return metadata


def read_observations(output, metadata):
    """Read the existing BootTrace and observed SDK segments, never synthesize CPU."""
    directory = output / 'runtime-data'
    phases, segments = [], {}
    trace = directory / 'boot-trace.tsv'
    if trace.exists():
        with trace.open() as stream:
            if stream.readline().strip() != f"schema\t1\tbuild\t{metadata['build_id']}\tplatform\tsimulator":
                raise ValueError('BootTrace build/platform mismatch')
            stream.readline()
            previous = 0
            for line in stream:
                sequence, phase, clock, since_yield, phase_ms, heap, peak = line.rstrip('\n').split('\t')
                numbers = [float(v) for v in (clock, since_yield, phase_ms, heap, peak)]
                if int(sequence) <= previous or any(not math.isfinite(v) or v < 0 for v in numbers):
                    raise ValueError('invalid BootTrace row')
                previous = int(sequence)
                phases.append(dict(sequence=previous, phase=phase, clock_ms=numbers[0],
                                   since_yield_ms=numbers[1], phase_wall_ms=numbers[2],
                                   lua_heap_kib=numbers[3], peak_lua_heap_kib=numbers[4]))
    path = directory / 'door-census-segments.tsv'
    if path.exists():
        with path.open() as stream:
            for line in stream:
                build, case, trial, ordinal, kind, active, trace_seq, start, loading = line.strip().split('\t')
                key = (int(case), int(trial))
                active, start = float(active), float(start)
                group = segments.setdefault(key, [])
                if (build != metadata['build_id'] or not 1 <= key[0] <= metadata['selected_cases']
                        or key[1] not in (1, 2) or int(ordinal) != len(group)+1
                        or kind not in ('yield', 'return', 'error') or loading not in ('0', '1')
                        or not all(math.isfinite(v) and v >= 0 for v in (active, start))):
                    raise ValueError('invalid SDK segment row')
                group.append(dict(ordinal=int(ordinal), kind=kind, active_ms=active,
                                  start_ms=start, trace_sequence=int(trace_seq), loading=loading=='1'))
    return phases, segments


def summarize(output, metadata, failure=None):
    """Join every expected case/trial, including missing/crashed tails, once."""
    path = output / 'runtime-data/door-census.jsonl'
    phases, segments = read_observations(output, metadata)
    census = json.loads((output / 'inventory.json').read_text())
    entries = {r['id']: r for r in census['entries']}
    target_ids = {m['key']: m['id'] for m in census['maps']}
    rows, seen = [], set()
    sequences = [r['sequence'] for r in phases]
    case_indices = {identity: index for index, identity in enumerate(metadata['selected_ids'], 1)}
    if path.exists():
        with path.open() as stream:
            for line in stream:
                row = json.loads(line)
                key = (row.get('id'), row.get('trial'))
                if (row.get('build_id') != metadata['build_id'] or key in seen
                        or key[0] not in metadata['selected_ids'] or type(key[1]) is not int or key[1] not in (1, 2)
                        or row.get('status') not in ('measured', 'gap', 'failure')):
                    raise ValueError('invalid, duplicate or foreign runtime row')
                seen.add(key)
                index = case_indices[key[0]]
                if row.get('case_index') != index:
                    raise ValueError('runtime case order differs')
                row['segments'] = segments.get((index, key[1]), [])
                trace_end = row.get('trace_end', -1)
                trace_begin = row.get('trace_begin', row.get('trace_setup_begin', trace_end))
                row['boot_trace'] = phases[bisect_right(sequences, trace_begin):bisect_right(sequences, trace_end)]
                row['inventory'] = entries[key[0]]
                if row['status'] == 'measured':
                    trigger, resolved, arrived = (row.get(k, {}) for k in ('trigger', 'resolved', 'arrived'))
                    entry = entries[key[0]]
                    expected = row.get('authored_resolution') or row.get('source_resolution') or entry.get('declaration')
                    trigger_ok = (trigger.get('source_event_id') == key[0] if entry['kind']=='warp' else
                                  trigger.get('connection') is True if 'connection' in entry['kind'] else
                                  (trigger.get('x'), trigger.get('y')) == (entry['x'], entry['y']))
                    target_id = target_ids.get(resolved.get('to'), resolved.get('to'))
                    if (row.get('input_completion_verified') is not True or row.get('door_entries') != 1
                            or not trigger_ok or not resolved.get('to') or row.get('input_frames') != 1
                            or (arrived.get('zone_id'), arrived.get('x'), arrived.get('y')) !=
                               (target_id, resolved.get('x'), resolved.get('y'))
                            or not row['segments'] or not any(r['phase']=='door.map.begin' for r in row['boot_trace'])
                            or not any(r['phase']=='door.map.end' for r in row['boot_trace'])):
                        raise ValueError('measured row lacks real portal completion evidence')
                    # Script targets are recorded only after their real resolver.
                    if expected and expected.get('to') and (expected['to'], expected.get('toX', expected.get('x')),
                            expected.get('toY', expected.get('y'))) != (resolved['to'], resolved.get('x'), resolved.get('y')):
                        raise ValueError('real destination differs from source-owned resolution')
                    for name in ('wall_ms', 'active_ms', 'max_segment_ms', 'post_gc_lua_heap_kib'):
                        if type(row.get(name)) not in (int, float) or not math.isfinite(row[name]) or row[name] < 0:
                            raise ValueError('invalid measured timing/heap')
                    if (abs(sum(s['active_ms'] for s in row['segments'])-row['active_ms']) > .05
                            or abs(max(s['active_ms'] for s in row['segments'])-row['max_segment_ms']) > .01):
                        raise ValueError('segment totals disagree with runtime row')
                rows.append(row)
    for identity in metadata['selected_ids']:
        for trial in (1, 2):
            if (identity, trial) not in seen:
                rows.append(dict(id=identity, trial=trial, status='not_run', gap=failure or 'missing runtime row',
                                 inventory=entries[identity]))
    measured = [r for r in rows if r.get('status') == 'measured']
    result = dict(schema=1, build_id=metadata['build_id'], classification=CLASSIFICATION,
                  runtime_executed=True, failure=failure, counts=dict(Counter(r['status'] for r in rows)),
                  complete=len(measured)==len(rows) and failure is None,
                  all_cases_reported=len(seen)==metadata['selected_cases']*2, rows=rows,
                  worst_wall=[{k:r[k] for k in ('id', 'trial', 'wall_ms', 'max_segment_ms', 'target_cache')} for r in
                              sorted(measured, key=lambda r:r['wall_ms'], reverse=True)[:20]],
                  worst_segments=[{k:r[k] for k in ('id', 'trial', 'wall_ms', 'max_segment_ms', 'target_cache')} for r in
                                  sorted(measured, key=lambda r:r['max_segment_ms'], reverse=True)[:20]],
                  limits='Simulator Lua heap only; no native-memory inference or hardware admission; private suspension GC at 8 MiB is excluded from active spans but included in wall phases; fixture setup excluded; BootTrace phase gaps are wall intervals')
    write_json(output / 'result.json', result)
    return result


def execute(project, sdk, output, metadata, timeout, locks_held=False):
    _, manifest, inventory, tree_hash, run, OwnerLock, atomic_json = tooling(project)
    if manifest(output / 'Source') != metadata['compiled_source_manifest'] or inventory(Path(metadata['bundle'])) != metadata['pdx_files']:
        raise ValueError('staged Source or PDX changed')
    if sha(sdk / 'bin/pdc') != metadata['compiler_sha256'] or sha(output / 'inventory.json') != metadata['inventory_sha256']:
        raise ValueError('compiler or inventory changed')
    process = None
    failure = None
    peak_footprint, footprint_samples = 0, 0
    data = sdk / 'Disk/Data' / metadata['bundle_id']
    with ExitStack() as ownership:
        if not locks_held:
            ownership.enter_context(OwnerLock(run.runtime_lock_path(sdk)))
            ownership.enter_context(OwnerLock(run.device_lock_path()))
        run.simulator_preflight()  # Existing USB ownership and actual 16 MiB pool checks.
        data.mkdir(parents=True, exist_ok=False)
        try:
            with OwnerLock(data / 'owner.lock'):
                for row in (metadata.get('seed_saves') or {}).get('files', []):
                    path = output / 'seed-saves' / row['file']
                    if sha(path) != row['sha256']:
                        raise ValueError('earned slot changed')
                    shutil.copyfile(path, data / row['file'])
                atomic_json(data / 'boot-profile-build.json', {'build_id': metadata['build_id']})
                simulator = sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'
                with (output / 'simulator.log').open('w') as log:
                    try:
                        process = subprocess.Popen([str(simulator), metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
                        atomic_json(output / 'run.json', dict(build_id=metadata['build_id'], pid=process.pid,
                                                             simulator=str(simulator), simulator_sha256=sha(simulator)))
                        deadline = time.monotonic() + timeout
                        progress_at = time.monotonic()
                        row_size = 0
                        trace_offset, trace_tail = 0, ''
                        while not (data / 'door-census-done.json').exists():
                            if process.poll() is not None or time.monotonic() > deadline:
                                raise RuntimeError('owned Simulator exited or census deadline expired')
                            footprint = process_footprint(process.pid)
                            footprint_samples += 1
                            peak_footprint = max(peak_footprint, footprint)
                            row_file = data / 'door-census.jsonl'
                            size = row_file.stat().st_size if row_file.exists() else 0
                            if size != row_size:
                                progress_at, row_size = time.monotonic(), size
                            try:
                                check_host_limits(footprint, time.monotonic() - progress_at)
                            except RuntimeError:
                                with (output / 'host-memory-summary.txt').open('w') as summary:
                                    try:
                                        subprocess.run(['vmmap', '-summary', str(process.pid)],
                                            stdout=summary, stderr=subprocess.STDOUT, timeout=3)
                                    except (OSError, subprocess.TimeoutExpired) as error:
                                        summary.write(str(error))
                                raise
                            trace = data / 'boot-trace.tsv'
                            if trace.exists():
                                with trace.open() as source_trace:
                                    source_trace.seek(trace_offset)
                                    chunk = source_trace.read(65536)
                                    trace_offset = source_trace.tell()
                                if '\terror.' in trace_tail + chunk:
                                    raise RuntimeError('production guard stopped the census; inspect BootTrace')
                                trace_tail = chunk[-32:]
                            time.sleep(.05)
                        done = json.loads((data / 'door-census-done.json').read_text())
                        if done != {'build_id': metadata['build_id'], 'rows': metadata['selected_cases']*2}:
                            raise ValueError('terminal census identity/count mismatch')
                    except Exception as error:
                        failure = str(error)
                    finally:
                        atomic_json(output / 'host-resource-limits.json', {
                            'max_process_bytes': MAX_PROCESS_BYTES,
                            'max_row_wait_seconds': MAX_ROW_WAIT_SECONDS,
                            'peak_process_bytes': peak_footprint,
                            'footprint_samples': footprint_samples,
                            'scope': 'Simulator host protection; not device RAM or Lua-heap acceptance'})
                        if process is not None and process.poll() is None:
                            process.terminate()
                            try:
                                process.wait(timeout=3)
                            except subprocess.TimeoutExpired:
                                process.kill()
                                process.wait(timeout=3)
        finally:
            if process is not None and process.poll() is None:
                raise RuntimeError('owned child exit unconfirmed; private Data retained')
            shutil.copytree(data, output / 'runtime-data')
            shutil.rmtree(data)
    try:
        result = summarize(output, metadata, failure)
    except (ValueError, KeyError, TypeError) as error:
        result = dict(schema=1, build_id=metadata['build_id'], runtime_executed=True, complete=False,
                      failure='Runtime evidence validation failed: '+str(error),
                      counts={'not_run': metadata['selected_cases']*2}, worst_wall=[], worst_segments=[],
                      rows=[dict(id=identity, trial=trial, status='not_run', gap='runtime evidence is unvalidated')
                            for identity in metadata['selected_ids'] for trial in (1, 2)])
        write_json(output / 'result.json', result)
    # Preserve/verify optional canonical earned input bytes; private saves also
    # must not have been written by incidental world hooks.
    for row in (metadata.get('seed_saves') or {}).get('files', []):
        if sha(Path(metadata['seed_saves']['directory']) / row['file']) != row['sha256'] or sha(output / 'runtime-data' / row['file']) != row['sha256']:
            result.update(complete=False, failure='earned/private slot bytes changed')
            write_json(output / 'result.json', result)
            return 1
    return 0 if result['complete'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path('~/Developer/PlaydateSDK'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--earned-save-dir', type=Path, help='optional actual earned slot directory; copied byte for byte')
    parser.add_argument('--case', action='append', help='exact inventory ID; inventory always retains all maps and portals')
    parser.add_argument('--execute', action='store_true', help='ROOT ONLY, after the physical sequence/title/installer work')
    parser.add_argument('--timeout', type=float, default=14400, help='whole serial census wall deadline')
    args = parser.parse_args()
    project, sdk, output = [p.expanduser().resolve() for p in (args.project, args.sdk, args.output)]
    earned = args.earned_save_dir.expanduser().resolve() if args.earned_save_dir else None
    if args.timeout <= 0 or not project.is_dir() or output.is_relative_to(project) or (earned and (output.is_relative_to(earned) or earned.is_relative_to(output))):
        parser.error('positive timeout and private output outside the input checkout required')
    with ExitStack() as ownership:
        if args.execute:
            *_, run, OwnerLock, _ = tooling(project)
            ownership.enter_context(OwnerLock(run.runtime_lock_path(sdk)))
            ownership.enter_context(OwnerLock(run.device_lock_path()))
            run.simulator_preflight()
        metadata = prepare(project, sdk, output, earned, args.case)
        print(json.dumps({'output': str(output), 'counts': metadata['counts'], 'runtime_executed': False}))
        return execute(project, sdk, output, metadata, args.timeout, locks_held=True) if args.execute else 0


if __name__ == '__main__':
    sys.exit(main())
