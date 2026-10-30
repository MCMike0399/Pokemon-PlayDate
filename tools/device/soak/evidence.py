"""Host-only exact soak artifact and runtime evidence validation."""
import json
import math
from pathlib import Path
from tools.device_cycle import inventory, tree_hash, sha, SLOTS


PROJECT = Path(__file__).resolve().parents[3]
TOOL_PATHS = tuple('tools/device/soak/'+name for name in (
    'prepare.py', 'sampler.lua', 'evidence.py', 'simulator.py', 'lifecycle.py', 'device-cycle-root.patch')) + (
    'tools/device_cycle.py', 'tools/harness/run.py', 'tools/harness/protocol.py',
    'tools/harness/build.py', 'tools/harness/dev_imports.lua', 'tools/harness/__init__.py',
    'tools/build.py', 'tools/device/build_smoke.py')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(stage):
    stage = Path(stage).resolve()
    build = json.loads((stage / 'build.json').read_text())
    require(set(build['tool_files']) == set(TOOL_PATHS), 'incomplete tool dependency closure')
    require(inventory(stage/'soak-tools') == build['tool_files'], 'retained tools changed')
    require(all(sha(PROJECT/name) == digest for name, digest in build['tool_files'].items()), 'current dependencies differ from compiled packet; rebuild AFTER root owner patch')
    source = inventory(stage / 'Source')
    base = build['production_source_manifest']
    require(build['mode'] == 'private-soak-compile-only-NOT-ADMITTED', 'wrong build mode')
    require(source == build['compiled_source_manifest'] and tree_hash(source) == build['compiled_source_sha256'], 'compiled source changed')
    require(tree_hash(base) == build['production_source_sha256'] and not any(n.startswith('dev/') for n in base), 'base hash/boundary')
    require(set(source)-set(base) == {'dev/deviceSmoke.lua', 'dev/soakSampler.lua'} and not set(base)-set(source)
            and {n for n in base if source[n] != base[n]} == {'main.lua', 'pdxinfo'}, 'overlay boundary')
    require(build['bundle_id'] == 'com.poc.pokemon.soak.'+build['build_id'], 'bundle identity')
    require(Path(build['bundle']).resolve() == stage/'Soak.pdx', 'retained PDX path')
    require(inventory(stage/'Soak.pdx') == build['pdx_files'] and tree_hash(build['pdx_files']) == build['pdx_sha256'], 'PDX changed')
    require(source['dev/soakSampler.lua'] == build['sampler_sha256'], 'sampler identity')
    require(sha(stage/'earned-save.json') == build['earned_manifest_sha256'], 'earned manifest changed')
    earned = json.loads((stage/'earned-save.json').read_text())
    require(earned['files'] == build['earned_slots'] and earned.get('provenance'), 'earned provenance')
    require(len(earned['files']) == 2 and {r['file'] for r in earned['files']} == SLOTS, 'two earned slots required')
    for row in earned['files']:
        require(sha(Path(earned['directory'])/row['file']) == row['sha256'], 'earned source changed')
    info = dict(line.split('=', 1) for line in (stage/'Source/pdxinfo').read_text().splitlines() if '=' in line)
    require(info['bundleID'] == build['bundle_id'], 'source bundle mismatch')
    return build


def rows(data, build, short=False):
    """Recompute from raw rows. A short proof cannot satisfy hardware acceptance."""
    raw = (data/'soak-minute.jsonl').read_text().splitlines()
    minutes = build.get('phase_minutes', 60)
    require(minutes in (30, 60), 'unknown hardware soak duration')
    count = 1 if short else minutes
    require(len(raw) == 2*count+5, 'incomplete/extra soak rows')
    records = [json.loads(line) for line in raw]
    expected = ['title-start']+['minute']*count+['continue-input', 'overworld-start']+['minute']*count+['complete', 'safety']
    require([r['kind'] for r in records] == expected, 'marker order')
    profile = 'simulator-short-v1' if short else f'hardware-{count}+{count}'
    last_clock, last_wall = -1, -1
    monotonic = {k: 0 for k in ('guard_checks', 'observed_heap_kib', 'maximum_slice_ms', 'segments', 'guard_total_ms', 'guard_max_ms', 'scalar_total_ms', 'scalar_max_ms')}
    for row in records:
        require(row['build'] == build['build_id'] and row['profile'] == profile, 'runtime identity/profile')
        require(row['clock_ms'] >= last_clock and int(row['wall_seconds']) >= last_wall, 'clock regression')
        last_clock, last_wall = row['clock_ms'], int(row['wall_seconds'])
        for key, previous in monotonic.items():
            value = row[key]
            require(type(value) in (int, float) and math.isfinite(value) and value >= previous, 'invalid aggregate '+key)
            monotonic[key] = value
    title, world, end, safety = records[0], records[count+2], records[-2], records[-1]
    require(title['sampler_version'] == 3 and title['phase_samples'] == count and title['sample_interval_ms'] == 60000, 'sampler schema')
    for phase, start, samples in [('title', title, records[1:count+1]), ('overworld', world, records[count+3:-2])]:
        previous = start
        for index, row in enumerate(samples, 1):
            require(row['phase'] == phase and row['minute'] == index and row['state'] == phase, 'minute phase/order')
            # phaseStart precedes start-row publication; its IO is not idle time.
            # Later samples schedule the next minute after publication.
            require((index == 1 or row['clock_ms']-previous['clock_ms'] >= 60000) and row['elapsed_ms'] >= index*60000, 'active minute missing')
            require(row['saved'] == 0 and row['loaded'] == (phase == 'overworld'), 'unexpected load/save')
            require(type(row['heap_kib']) in (int, float) and math.isfinite(row['heap_kib']) and 0 <= row['heap_kib'] <= 9*1024, 'minute heap')
            if phase == 'overworld':
                require(row['zone'] == start['zone'] and row['player'] == start['player'] and row['player']['moving'] is False, 'idle moved')
            previous = row
        require(int(samples[-1]['wall_seconds'])-int(start['wall_seconds']) >= count*60, 'wall duration missing')
    require(records[count+1]['command'] == 'DS1 1 press a 1', 'Continue input')
    require(end['samples'] == 2*count and end.get('periodic_full_gc', end.get('idle_full_gc')) == 0, 'completion totals')
    for key in ('sampler_total_ms', 'sampler_max_ms', 'sampler_last_ms'):
        require(type(end[key]) in (int, float) and math.isfinite(end[key]) and end[key] >= 0, 'invalid overhead')
    require(end['sampler_last_ms'] <= end['sampler_max_ms'] <= end['sampler_total_ms'], 'overhead summary')
    minutes = [r for r in records if r['kind'] == 'minute']
    costs = [r['previous_sampler_ms'] for r in minutes]+[end['sampler_last_ms']]
    require(costs[0] == 0 and all(type(v) in (int, float) and math.isfinite(v) and v >= 0 for v in costs), 'overhead costs')
    require(sum(costs) == end['sampler_total_ms'] and max(costs) == end['sampler_max_ms'], 'overhead raw/summary mismatch')
    require(end['sampler_total_ms'] <= end['clock_ms']-title['clock_ms'], 'overhead exceeds elapsed time')
    require(end['guard_checks'] > 2*count and end['segments'] > 2*count, 'missing per-frame aggregates')
    for row in build['earned_slots']:
        require(sha(data/row['file']) == row['sha256'], 'earned runtime bytes changed')
    replies = [json.loads(line) for line in (data/'device-smoke-replies.jsonl').read_text().splitlines()]
    require([(r['seq'], r['status']) for r in replies] == [(0, 'ready'), (1, 'accepted'), (1, 'done')], 'DS1 transcript')
    require(all(r['build'] == build['build_id'] for r in replies), 'DS1 identity')
    require(replies[1]['value'] == 'press' and replies[-1]['value']['loaded'] == 1
            and replies[-1]['value']['saved'] == 0 and not replies[-1]['value'].get('error'), 'real Continue completion')
    trace = (data/'boot-trace.tsv').read_text()
    require(trace.startswith(f"schema\t1\tbuild\t{build['build_id']}\tplatform\t"+('simulator' if short else 'device')+'\n')
            and '\terror.' not in trace, 'trace error/identity')
    require(safety['boundary'] == 'after complete IO and final game guard', 'final application boundary missing')
    publication = json.loads((data/'soak-publication.json').read_text())
    require(publication['build'] == build['build_id'] and publication['kind'] == 'publication'
            and publication['guard_after_safety'] is True, 'terminal publication identity/guard')
    for key in ('application_maximum_slice_ms', 'observer_ms', 'observed_heap_kib'):
        value = publication[key]
        require(type(value) in (int, float) and math.isfinite(value) and value >= 0, 'invalid publication '+key)
    require(publication['application_maximum_slice_ms'] >= safety['maximum_slice_ms']
            and publication['observed_heap_kib'] >= safety['observed_heap_kib'], 'publication regressed')
    terminal_limit = 150 if short else 5000
    require(publication['application_maximum_slice_ms'] <= terminal_limit and publication['observer_ms'] <= terminal_limit
            and publication['observed_heap_kib'] <= 9*1024, 'terminal slice/9 MiB bound failed')
    require((data/'soak-done.txt').read_text() == build['build_id']+'\n', 'missing post-assertion completion witness')
    return dict(profile=profile, samples=2*count, maximum_slice_ms=publication['application_maximum_slice_ms'],
                observed_heap_bytes=publication['observed_heap_kib']*1024,
                terminal_observer_ms=publication['observer_ms'],
                maximum_slice_measurement_boundary='before publication receipt IO; complete IO and final application guard included',
                terminal_combined_slice_asserted_upper_bound_ms=terminal_limit,
                terminal_observed_heap_asserted_upper_bound_bytes=9*1024*1024,
                terminal_receipt_tail=f'locally guarded/asserted <={terminal_limit} ms including receipt; DONE print unmeasured',
                sampler_total_ms=end['sampler_total_ms'], sampler_max_ms=end['sampler_max_ms'],
                guard_total_ms=safety['guard_total_ms'], scalar_total_ms=safety['scalar_total_ms'],
                hardware_soak_accepted=not short)


def admission(stage, report_path):
    build = verify(stage)
    report_path = Path(report_path).resolve()
    report = json.loads(report_path.read_text())
    require(report['build'] == build and report['status'] == 'simulator-soak-proof-passed'
            and report['malloc_pool_preflight'] == 16645684 and report['malloc_pool_mb'] == 16
            and report['hardware_soak_accepted'] is False, 'exact Simulator proof required')
    recomputed = rows(report_path.parent/'runtime-data', build, short=True)
    require(report['measurements'] == recomputed, 'proof aggregates changed')
    require(inventory(report_path.parent/'runtime-data') == report['runtime_files'], 'proof raw files changed')
    log = report_path.parent/'simulator.log'
    require(sha(log) == report['simulator_log_sha256'], 'proof log changed')
    require(not any(word in log.read_text().lower() for word in ('booterror', 'not enough memory', 'update failed', 'soak1 {"kind":"error"')), 'runtime error log')
    console_rows(log, report_path.parent/'runtime-data')
    run = json.loads((report_path.parent/'run.json').read_text())
    require(run['build'] == build and run['malloc_pool_preflight'] == report['malloc_pool_preflight'], 'run identity/pool')
    preflight = report_path.parent/'malloc-preflight.ini'
    require(sha(preflight) == report['malloc_preflight_sha256'] == run['malloc_preflight_sha256'], 'pool preflight bytes changed')
    values = dict(line.split('=', 1) for line in preflight.read_text().splitlines() if '=' in line)
    require(int(values['MallocPoolSize']) == report['malloc_pool_preflight'], 'pool preflight measurement mismatch')
    require(report['owned_child_reaped'] is True and report['pty_eof'] is True
            and report['publication_confirmed'] is True and run['capture'] == 'owned-child-pty', 'unconfirmed publication/cleanup')
    return build, report


def console_rows(log, data):
    expected = [json.loads(line) for line in (data/'soak-minute.jsonl').read_text().splitlines()]
    build = expected[0]['build']
    observed = []
    for line in log.read_text().splitlines():
        if 'SOAK1 ' in line:
            row, _ = json.JSONDecoder().raw_decode(line.split('SOAK1 ', 1)[1])
            if row.get('build') == build:
                observed.append(row)
    require(observed == expected, 'console/file markers differ')

    publication = json.loads((data/'soak-publication.json').read_text())
    receipts = [json.loads(line.split('SOAK-PUBLISHED ', 1)[1])
                for line in log.read_text().splitlines() if 'SOAK-PUBLISHED ' in line]
    receipts = [row for row in receipts if row.get('build') == build]
    require(receipts == [publication], 'publication console/file markers differ')
    require([line for line in log.read_text().splitlines() if line == 'SOAK-DONE '+build]
            == ['SOAK-DONE '+publication['build']], 'post-publication guard acknowledgement missing')
