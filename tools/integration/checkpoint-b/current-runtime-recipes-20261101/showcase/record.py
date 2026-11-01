#!/usr/bin/env python3
"""Root-only native replay. --check is host-only and never acquires runtime locks."""
import argparse
import contextlib
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import uuid
import time
import threading
import os
import signal
import importlib.util
from pathlib import Path

sys.dont_write_bytecode = True  # Preserve the read-only B checkout, including import caches.

HERE = Path(__file__).resolve().parent
ENV = Path.home() / 'Developer/Pokemon-PlayDate-env'
PROOF = json.loads((HERE / 'provenance.json').read_text())
PROJECT = Path(PROOF['project'])
BOUNDARY = Path(PROOF['scenario']['initial_save']['resume']['path'])
KOGA = 'pokered:FUCHSIA_GYM:objects:1'
TRAINER = 'pokered:ROUTE_12:objects:6'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def load(p):
    return json.loads(p.read_text())

def verify(project):
    # Docs-only descendants retain exact pinned Source/harness inventories.
    subprocess.run(['git', 'merge-base', '--is-ancestor', PROOF['revision'], 'HEAD'], cwd=project, check=True)
    assert not subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all', '--', 'Source', 'tools'], cwd=project, text=True).strip(), 'B Source/tooling dirty'
    source = {p.relative_to(project / 'Source').as_posix(): sha(p)
              for p in (project / 'Source').rglob('*') if p.is_file()}
    harness = {p.relative_to(project).as_posix(): sha(p)
               for p in (project / 'tools/harness').rglob('*')
               if p.is_file() and '__pycache__' not in p.parts}
    assert hashlib.sha256(json.dumps(source, sort_keys=True, separators=(',', ':')).encode()).hexdigest() == PROOF['source_inventory_sha256'], 'Source changed; do not silently substitute runtime'
    assert hashlib.sha256(json.dumps(harness, sort_keys=True, separators=(',', ':')).encode()).hexdigest() == PROOF['harness_inventory_sha256'], 'harness changed; prepare a separately reviewed recipe'
    assert sha(BOUNDARY) == PROOF['boundary_sha256']
    observation = Path(PROOF['boundary_saved_observation']['path'])
    assert sha(observation) == PROOF['boundary_saved_observation']['sha256']
    assert sha(BOUNDARY.parent.parent.parent / 'run.json') == PROOF['producer_run_sha256']
    marker = load(BOUNDARY)
    assert marker['files'] == PROOF['boundary_files']
    saved = load(observation)
    assert all(saved[k] == marker[k] for k in ('build_id', 'session_id'))
    assert saved['results'][0]['observation']['payload'] == marker['state']['codec']
    slots = [load(BOUNDARY.parent / 'runtime-data' / row['file']) for row in marker['files']]
    assert json.loads(max(slots, key=lambda slot: int(slot['sequence']))['payload']) == marker['state']['codec']
    for name, digest in PROOF['reuse'].items():
        assert sha(Path(name)) == digest, name
    return PROOF

def map_event_ids(source, manifest):
    """Project only IDs from the exact copied records; query live owners later."""
    def checked(relative):
        path = source / relative
        assert path.resolve().is_relative_to(source.resolve())
        assert sha(path) == manifest[relative], 'copied map bytes differ: ' + relative
        return load(path)

    catalogue = checked('data/sourceMaps.json')
    result = {}
    seen = set()
    for name, entry in sorted(catalogue['maps'].items()):
        definition = checked(entry['path'])
        assert definition['schema'] == 1
        assert definition['source_revision'] == catalogue['source_revision']
        assert definition['name'] == name and definition['id'] == entry['id']
        groups = {}
        for group in ('objects', 'background_events'):
            groups[group] = []
            for event in definition['events'][group]:
                identity = event['id']
                assert isinstance(identity, str) and identity not in seen
                seen.add(identity)
                groups[group].append({'id': identity})
        result[name] = groups
    return result


def patch_owner_projection(text):
    old = ('        for _, name in ipairs(SourceMaps.names()) do\n'
           '            local definition = SourceMaps.definition(name)\n')
    new = ('        local decodeFile <const> = json.decodeFile\n'
           '        local mapEvents <const> = assert(decodeFile("dev/showcase-event-ids.json"))\n'
           '        for _, name in ipairs(SourceMaps.names()) do\n'
           '            local definition = {events = assert(mapEvents[name])}\n')
    assert text.count(old) == 1, 'owner enumeration changed; review before staging'
    return text.replace(old, new, 1)


def stage_owner_projection(output, metadata):
    source = output / 'Source'
    manifest = load(output / 'source-manifest.json')
    projection = map_event_ids(source, manifest)
    path = source / 'dev/showcase-event-ids.json'
    path.write_text(json.dumps(projection, sort_keys=True, separators=(',', ':')) + '\n')
    diagnostics = source / 'dev/diagnostics.lua'
    assert sha(diagnostics) == manifest['dev/diagnostics.lua'], 'copied diagnostics differ'
    original = diagnostics.read_bytes()
    (output / 'original-diagnostics.lua').write_bytes(original)
    diagnostics.write_text(patch_owner_projection(original.decode()))
    metadata['generated_overlays'].extend(['Source/dev/showcase-event-ids.json',
                                            'Source/dev/diagnostics.lua'])
    metadata['showcase_owner_enumeration'] = {
        'maps': len(projection),
        'events': sum(len(group) for groups in projection.values() for group in groups.values()),
        'projection_sha256': sha(path),
        'original_diagnostics_sha256': hashlib.sha256(original).hexdigest(),
        'staged_diagnostics_sha256': sha(diagnostics),
        'scope': 'Exact copied map event IDs only; live has/descriptor/shop/trainer/codec checks unchanged.',
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--project', type=Path, default=PROJECT)
    ap.add_argument('--output', type=Path)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--compile-only', action='store_true', help='Stage and compile only; no runtime or locks')
    selection = ap.add_mutually_exclusive_group()
    selection.add_argument('--preflight-only', action='store_true', help='Capture only the first native walk for root inspection')
    selection.add_argument('--segment', choices=('walk', 'trainer', 'cutscene', 'gym'),
                           help='One independent earned-save replay in a fresh guarded process')
    ap.add_argument('--execute-root-owned', action='store_true')
    ap.add_argument('--root-gates-verified', action='store_true', help='Root asserts Accessibility/Clear/reclamation and long-run hold release are already verified, with 16 MiB retained')
    args = ap.parse_args()
    project = args.project.resolve()
    verify(project)
    sys.path.insert(0, str(project))
    from tools.harness import run as runner, restarting
    from tools.harness.midgame_journey import MidgameJourney

    class ShowcaseJourney(MidgameJourney):
        # The private framebuffer overlay already records selected chapters.
        # Retain ordinary no-input frames without a second diagnostic PNG stream.
        def send(self, *commands):
            selected = []
            for command in commands:
                if isinstance(command, str) and command.startswith('record '):
                    _, label, frames = command.split()
                    self.summary.setdefault('unretained_diagnostic_recordings', []).append(
                        {'label': label, 'frames': int(frames), 'replacement': 'ordinary wait'})
                    command = 'wait ' + frames
                selected.append(command)
            return super().send(*selected)

        def battle(self, name, strategy='attack', expected=None):
            stable = self.state.get('event', {}).get('id')
            label = getattr(self, 'capture_targets', {}).get(stable)
            if label:
                self.summary.setdefault('captured_battle_ids', []).append(stable)
                with self.capture_chapter(label):
                    return super().battle(name, strategy, expected)
            return super().battle(name, strategy, expected)

    from tools.harness.protocol import Client, OwnerLock, atomic_json
    scenario = PROOF['scenario']
    config = scenario['processes'][0]['journey']
    # Reuse the strict importer in a disposable host directory. No SDK Data or locks.
    with tempfile.TemporaryDirectory(prefix='showcase-host-') as temp:
        temp = Path(temp)
        (temp / 'data').mkdir(); (temp / 'out').mkdir()
        accepted = restarting.import_chain_save(scenario, project, temp / 'data', temp / 'out')
        assert all(accepted[k] == v for k, v in PROOF['accepted_A'].items() if k != 'accepted_boundary')
        assert all(accepted['accepted_boundary'][k] == v for k, v in PROOF['accepted_A']['accepted_boundary'].items())
    verify(project)
    print('Pinned Source/harness, archived slots, stopped producer and accepted A ancestry verified.')
    if args.check:
        return
    if (not args.execute_root_owned and not args.compile_only) or args.output is None:
        ap.error('Recording requires --execute-root-owned and a new --output; root alone executes it.')
    if not args.compile_only and not args.preflight_only and not args.segment and not args.root_gates_verified:
        ap.error('Root must verify Accessibility, exact Clear/reclamation and release the long-run hold first')
    output = args.output.resolve()
    if not args.compile_only:
        assert shutil.disk_usage(ENV / 'evidence').free >= 51 * 1024**3, '51 GiB runtime batch admission required'
    output.mkdir(parents=True, exist_ok=False)
    sdk = runner.sdk_path()
    assert (sdk / 'VERSION.txt').read_text().strip() == '3.1.2', 'exact SDK 3.1.2 required'
    process = client = None
    captures_finalized = False
    confirmed_exit = True
    guard_stop = threading.Event()
    guard_errors = []
    guard_thread = None
    runtime_seconds = 90 if args.preflight_only else 1800
    runtime_lock = contextlib.nullcontext() if args.compile_only else OwnerLock(runner.runtime_lock_path(sdk))
    device_lock = contextlib.nullcontext() if args.compile_only else OwnerLock(runner.device_lock_path())
    with runtime_lock, device_lock:
        if not args.compile_only:
            runner.simulator_preflight()
        metadata = runner.prepare(project, sdk, output, uuid.uuid4().hex,
                                  recent_interval=60, journey=True)
        assert metadata['source_sha256'] == PROOF['source_sha256']
        stage_owner_projection(output, metadata)
        overlay = output / 'Source/dev/showcase_capture.lua'
        shutil.copyfile(HERE / 'capture.lua', overlay)
        with (output / 'Source/main.lua').open('a') as f:
            f.write('\nimport "dev/showcase_capture"\n')
        metadata['generated_overlays'].append('Source/dev/showcase_capture.lua')
        metadata['compiled_source_sha256'] = runner.fingerprint(output, exclude_generated=False)
        metadata['compiler_sha256'] = sha(sdk / 'bin/pdc')
        metadata['showcase'] = dict(recipe=str(HERE), capture_overlay_sha256=sha(overlay),
            source_revision=metadata['revision'], recipe_provenance_sha256=sha(HERE / 'provenance.json'),
            classification='earned-state input replay; not a new campaign or performance acceptance',
            audio='silent; audio activation not claimed', timing='captured SDK wall timestamps; no speedup',
            host_guard=dict(maximum_bytes=1024**3, maximum_seconds=runtime_seconds,
                admission='bounded three-second capture preflight; no long-run or Clear qualification'
                    if args.preflight_only else ('fresh process segment: ' + args.segment + '; no long-run/Clear qualification'
                          if args.segment else 'Root verified long-run prerequisites')))
        with (output / 'capture-build.log').open('w') as log:
            subprocess.run([str(sdk / 'bin/pdc'), str(output / 'Source'), metadata['bundle']],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        atomic_json(output / 'build.json', metadata)
        verify(project)
        if args.compile_only:
            print('Compile only; no runtime or locks: ' + str(output))
            return
        data = Path(metadata['data_dir']); data.mkdir(parents=True, exist_ok=False)
        with OwnerLock(data / 'owner.lock') as owner:
            try:
                restarting.import_chain_save(scenario, project, data, output)
                with (output / 'simulator.log').open('w') as log:
                    process = subprocess.Popen([metadata['simulator'], metadata['bundle']],
                                               stdout=log, stderr=subprocess.STDOUT)
                    # Reuse the existing host footprint reader. No AX/GUI/settings calls.
                    helper = Path(PROOF['footprint_reader']['path'])
                    assert sha(helper) == PROOF['footprint_reader']['sha256']
                    spec = importlib.util.spec_from_file_location('showcase_footprint', helper)
                    footprint = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(footprint)
                    def guard():
                        started = time.monotonic()
                        try:
                            while not guard_stop.wait(0.5):
                                if process.poll() is not None:
                                    return
                                amount = footprint.process_footprint(process.pid)
                                with (output / 'host-footprint.jsonl').open('a') as log:
                                    log.write(json.dumps(dict(seconds=time.monotonic()-started, bytes=amount)) + '\n')
                                if (amount > 1024**3 or time.monotonic()-started > runtime_seconds
                                        or shutil.disk_usage(ENV / 'evidence').free < 50 * 1024**3):
                                    raise RuntimeError('1 GiB footprint, 50 GiB reserve or bounded showcase deadline exceeded')
                        except BaseException as error:
                            guard_errors.append(str(error))
                            os.kill(os.getpid(), signal.SIGINT)  # Main finally stops only its owned child.
                    guard_thread = threading.Thread(target=guard, daemon=True)
                    guard_thread.start()
                    metadata['simulator_pid'] = process.pid
                    atomic_json(output / 'run.json', metadata)
                    client = Client(data, metadata['build_id'], metadata['session_id'], output, owner=owner)
                    client.ready(60)
                    d = ShowcaseJourney(client, output, config, output, output / 'frames')
                    d.send('snapshot')
                    d.start_earned()  # Actual CONTINUE and complete saved codec equality.
                    chapters = []
                    @contextlib.contextmanager
                    def capture(label):
                        atomic_json(output / 'journey-summary.json', d.summary)
                        control = data / 'showcase-control.txt'
                        temporary = data / 'showcase-control.tmp'
                        temporary.write_text(label); temporary.replace(control)
                        row = dict(label=label, status='recording')
                        chapters.append(row); atomic_json(output / 'chapters.json', chapters)
                        try:
                            d.send('wait 2')
                            yield
                            d.send('wait 15')
                            row['status'] = 'complete'
                        except BaseException:
                            row['status'] = 'failed'
                            raise
                        finally:
                            control.unlink(missing_ok=True)
                            atomic_json(output / 'chapters.json', chapters)
                    d.capture_chapter = capture
                    d.capture_targets = {}
                    if args.segment == 'trainer':
                        d.capture_targets[TRAINER] = 'trainer'
                    elif args.segment == 'gym':
                        d.capture_targets[KOGA] = 'gym'
                    if args.preflight_only:
                        # The recorder caps this label at 3 SDK wall seconds.
                        with capture('preflight'):
                            d.send('press down', 'wait 12')  # Real D-pad input from saved (3,3).
                            d.require(**{'player.x': 3, 'player.y': 4, 'player.settled': True})
                            deadline = time.monotonic() + 3
                            while time.monotonic() < deadline:
                                d.send('wait 1')
                    else:
                        selected = {args.segment} if args.segment else {'walk', 'trainer', 'cutscene', 'gym'}
                        if 'walk' in selected:
                            with capture('walk'):
                                d.travel(d.zone('LavenderTown'))
                                d.source_waypoint(9, 17)
                        if selected != {'walk'}:
                            restored = all(mon['hp'] == mon['maxHP']
                                and mon.get('status') in (None, 'none') and mon['pp'] == mon['maxPP']
                                for mon in d.party())
                            if not restored:
                                d.heal_here('LavenderPokecenter')
                            assert not d.defeated(TRAINER), 'Target already defeated; never rematch/reset'
                            d.fight(TRAINER)
                            if args.segment == 'trainer':
                                assert d.summary.get('captured_battle_ids') == [TRAINER]
                            assert d.defeated(TRAINER)
                        if selected.intersection({'cutscene', 'gym'}):
                            d.heal_here('LavenderPokecenter')
                            assert not d.flag('EVENT_BEAT_ROUTE12_SNORLAX')
                            d.travel(d.zone('Route12'), goal=(10, 61))
                            d.source_waypoint(10, 61)
                            with capture('cutscene') if 'cutscene' in selected else contextlib.nullcontext():
                                d.wake_snorlax('ROUTE_12', 1, (10, 61))
                            assert d.flag('EVENT_BEAT_ROUTE12_SNORLAX')
                            d.completed_steps.add('route12-snorlax')
                            d.save()
                        if 'gym' in selected:
                            d.restock('LavenderMart')
                            d.enter_route14_from_east()
                            d.refill_after_route13()
                            d.enter_route14_from_east()
                            d.finish_eastern_road_to_fuchsia()
                            d.heal_here('FuchsiaPokecenter')
                            assert not d.defeated(KOGA)
                            d.leader('FUCHSIA_GYM', 'BADGE_SOUL', 'tm06',
                                     'FuchsiaPokecenter', 'FuchsiaMart')
                            if args.segment == 'gym':
                                assert d.summary.get('captured_battle_ids') == [KOGA]
                            assert d.defeated(KOGA) and d.flag('BADGE_SOUL')
                            assert d.flag('EVENT_GOT_TM06') and d.quantity('tm06') >= 1
                    atomic_json(output / 'journey-summary.json', dict(d.summary, ok=True,
                        acceptance='showcase component replay only; no final chain export'))
                    runner.finalize_captures(client, data, output)
                    captures_finalized = True
                    assert not guard_errors, guard_errors
                    atomic_json(output / 'outcome.json', dict(ok=True, motion_inspection='root pending'))
            except BaseException as error:
                atomic_json(output / 'outcome.json', dict(ok=False, error=str(error), host_guard_errors=guard_errors))
                raise
            finally:
                (data / 'showcase-control.txt').unlink(missing_ok=True)
                if client is not None and not captures_finalized and not guard_errors:
                    try:
                        runner.finalize_captures(client, data, output)
                    except BaseException as final_error:
                        atomic_json(output / 'artifact-finalization.json', dict(ok=False, error=str(final_error)))
                guard_stop.set()
                if guard_thread is not None:
                    guard_thread.join(timeout=2)
                if process is not None:
                    try:
                        restarting.stop_owned(process, owner, data)
                    except restarting.UnconfirmedExit:
                        confirmed_exit = False
                        raise
                if confirmed_exit:
                    shutil.copytree(data, output / 'runtime-data')
                    shutil.rmtree(data)
    print(output)

if __name__ == '__main__':
    main()
