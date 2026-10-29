#!/usr/bin/env python3
"""Compile startup or supplemental checkpoint probes; root alone may --execute.

Root checkpoint command, using the actual earned slot directory:
  python tools/harness/startup_probe.py --mode production --checkpoint \
    --save-dir /path/to/earned/checkpoint-slots --output /path/to/fresh/evidence \
    --timeout 120 --execute

startup-probe.json contains post-GC Lua heap and worst measured update durations
for one real map traversal and one supplemental battle entry. No natural-journey,
device-RAM or display-presentation result is implied. Omitting --execute compiles
only and never creates Simulator Data. The original passive modes are unchanged.
"""
import argparse
from contextlib import nullcontext
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.build import stage_production
from tools.harness import run
from tools.harness.protocol import OwnerLock, ProtocolError, atomic_json

RESOURCE_LUA = Path(__file__).with_name('checkpoint_resource_probe.lua')


def seed_saves(directory, output):
    directory = Path(directory).expanduser().resolve()
    target = output / 'seed-saves'
    target.mkdir()
    files = []
    for name in ('adventure.a.json', 'adventure.b.json'):
        source = directory / name
        if source.is_symlink() or not source.is_file():
            raise ProtocolError('checkpoint probe needs both actual earned save slots')
        content = source.read_bytes()
        (target / name).write_bytes(content)
        files.append({'file': name, 'sha256': hashlib.sha256(content).hexdigest()})
    record = {'directory': str(directory), 'files': files,
              'classification': 'copied earned slots; gameplay values are loaded only by GameSaves'}
    atomic_json(output / 'starting-save.json', record)
    return record


def instrument(text, session, mode, checkpoint=False):
    # Same observer in both modes, starting before any import. No dev dependency.
    before = 'local startupProbeBegin = playdate.getCurrentTimeMilliseconds()\n'
    if checkpoint:
        imports = '\nimport "probe/checkpoint_config"\nimport "probe/checkpoint_resource"\n'
        after = 'CheckpointResourceConfig.startup_ms = playdate.getCurrentTimeMilliseconds() - startupProbeBegin\nCheckpointResourceProbe.install()\n'
        if 'GameBootstrap.start' in text:
            after = '\nGameBootstrap.afterReady(function()\n' + after + '\nend)\n'
        return before + text + imports + after
    after = '''
local startupProbe = {
    session_id = SESSION, mode = MODE,
    simulator = not not playdate.isSimulator,
    startup_ms = playdate.getCurrentTimeMilliseconds() - startupProbeBegin,
    heap_kib_before_gc = collectgarbage("count"),
}
collectgarbage("collect")
collectgarbage("collect")
startupProbe.heap_kib_after_gc = collectgarbage("count")
local startupProbeUpdate = playdate.update
function playdate.update()
    startupProbeUpdate()
    startupProbe.first_frame_heap_kib = collectgarbage("count")
    -- Stop every producer before publishing the final report.
    playdate.update = function() end
    local file = assert(playdate.file.open("startup-probe.tmp", playdate.file.kFileWrite))
    assert(file:write(json.encode(startupProbe)))
    file:close()
    assert(playdate.file.rename("startup-probe.tmp", "startup-probe.json"))
end
'''.replace('SESSION', json.dumps(session)).replace('MODE', json.dumps(mode))
    if 'GameBootstrap.start' in text:
        after = '\nGameBootstrap.afterReady(function()\n' + after + '\nend)\n'
    return before + text + after


def prepare(project, sdk, output, session, mode, checkpoint=None, device_test=False):
    output.mkdir(parents=True, exist_ok=False)
    if mode == 'harness':
        metadata = run.prepare(project, sdk, output, session)
    else:
        if mode == 'legacy-production':
            shutil.copytree(project / 'Source', output / 'Source')
        else:
            stage_production(project, output)
        bundle_id = 'com.poc.pokemon.startupprobe.' + session
        pdxinfo = output / 'Source/pdxinfo'
        if sum(line.startswith('bundleID=') for line in pdxinfo.read_text().splitlines()) != 1:
            raise ProtocolError('probe requires exactly one bundleID for private save isolation')
        pdxinfo.write_text('\n'.join('bundleID=' + bundle_id if line.startswith('bundleID=') else line
                                     for line in pdxinfo.read_text().splitlines()) + '\n')
        metadata = {'bundle': str(output / 'Production.pdx'), 'bundle_id': bundle_id,
                    'data_dir': str(sdk / 'Disk/Data' / bundle_id),
                    'simulator': str(sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'),
                    'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
                    'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
                    'source_sha256': run.fingerprint(project)}
    main = output / 'Source/main.lua'
    original = main.read_text()
    if device_test:
        original = "DEVICE_TEST_BUILD = true\n" + original
    staged_hash = run.fingerprint(output, exclude_generated=False)
    if checkpoint:
        if mode != 'production':
            raise ProtocolError('checkpoint resource measurements require a production stage')
        record = seed_saves(checkpoint['save_dir'], output)
        config = dict(session_id=session, source_sha256=staged_hash,
                      save_hashes=record['files'], door_index=checkpoint['door_index'],
                      battle_species=checkpoint['battle_species'], battle_level=checkpoint['battle_level'],
                      battle_frames=checkpoint['battle_frames'], settle_frames=checkpoint['settle_frames'],
                      observer_sha256=hashlib.sha256(RESOURCE_LUA.read_bytes()).hexdigest())
        config_hash = hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()
        config['build_id'] = metadata['revision'] + ':' + staged_hash + ':' + config_hash
        folder = output / 'Source/probe'
        folder.mkdir()
        (folder / 'checkpoint_config.lua').write_text('CheckpointResourceConfig = ' + '{\n' + ''.join(
            '    ' + key + ' = ' + json.dumps(value, ensure_ascii=False) + ',\n'
            for key, value in config.items() if key != 'save_hashes') + '}\n')
        shutil.copyfile(RESOURCE_LUA, folder / 'checkpoint_resource.lua')
        metadata.update(build_id=config['build_id'], resource_checkpoint=True,
                        seed_saves=record, observer_sha256=config['observer_sha256'],
                        staged_source_sha256=staged_hash,
                        measurement='Supplemental earned-save Simulator heap/map-load/battle-start update CPU; full-GC pauses excluded; not natural journey or device proof')
    main.write_text(instrument(original, session, mode, checkpoint=checkpoint is not None))
    (output / 'uninstrumented-main.lua').write_text(original)
    metadata.update(probe_mode=mode, session_id=session,
                    compiled_source_sha256=run.fingerprint(output, exclude_generated=False),
                    measurement=metadata.get('measurement', 'instrumented Simulator startup and Lua heap; two explicit full GC passes; no native allocation claim'))
    with (output / 'probe-build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(output / 'Source'), metadata['bundle']],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    metadata['main_pdz_sha256'] = hashlib.sha256((Path(metadata['bundle']) / 'main.pdz').read_bytes()).hexdigest()
    atomic_json(output / 'build.json', metadata)
    return metadata


def execute(metadata, output, timeout):
    compiled = Path(metadata['bundle']) / 'main.pdz'
    if hashlib.sha256(compiled.read_bytes()).hexdigest() != metadata['main_pdz_sha256']:
        raise ProtocolError('compiled probe entry point changed after preparation')
    data = Path(metadata['data_dir'])
    data.mkdir(parents=True, exist_ok=False)
    for record in metadata.get('seed_saves', {}).get('files', []):
        source = output / 'seed-saves' / record['file']
        content = source.read_bytes()
        if hashlib.sha256(content).hexdigest() != record['sha256']:
            raise ProtocolError('private checkpoint seed bytes changed after compilation')
        (data / record['file']).write_bytes(content)
    atomic_json(data / 'boot-profile-build.json', {'build_id': metadata.get('build_id', metadata['main_pdz_sha256'])})
    process = None
    try:
        with OwnerLock(data / 'owner.lock'), (output / 'simulator.log').open('w') as log:
            try:
                run.simulator_preflight()
                process = subprocess.Popen([metadata['simulator'], metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
                atomic_json(output / 'run.json', dict(metadata, simulator_pid=process.pid))
                deadline = time.monotonic() + timeout
                while not (data / 'startup-probe.json').exists():
                    trace = data / 'boot-trace.tsv'
                    if trace.exists() and '\terror.' in trace.read_text():
                        raise ProtocolError('guarded profile stopped; inspect runtime-data/boot-trace.tsv')
                    if process.poll() is not None or time.monotonic() >= deadline:
                        raise ProtocolError('startup probe exited or timed out before publication')
                    time.sleep(0.05)
                report = json.loads((data / 'startup-probe.json').read_text())
                if (report.get('session_id'), report.get('mode'), report.get('simulator')) != (metadata['session_id'], metadata['probe_mode'], True):
                    raise ProtocolError('startup probe identity mismatch')
                atomic_json(output / 'startup-probe.json', report)
                if metadata.get('resource_checkpoint'):
                    if report.get('build_id') != metadata['build_id']:
                        raise ProtocolError('checkpoint performance build identity differs')
                    if report.get('ok') is not True:
                        raise ProtocolError('checkpoint performance setup failed: ' + str(report.get('error')))
            finally:
                if process is not None and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=3)
    finally:
        if data.exists():
            shutil.copytree(data, output / 'runtime-data')
            if process is None or process.poll() is not None:
                shutil.rmtree(data)
            else:
                raise ProtocolError('probe process exit unconfirmed; private Data retained: ' + str(data))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('legacy-production', 'production', 'harness'), required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--project', type=Path, default=run.PROJECT, help='read-only source checkout to measure')
    parser.add_argument('--sdk')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--device-test', action='store_true', help='enable crash-avoidance guards for the private profile')
    parser.add_argument('--timeout', type=float, default=30)
    parser.add_argument('--checkpoint', action='store_true', help='supplemental earned-save resource probe, production only')
    parser.add_argument('--save-dir', type=Path, help='actual earned slot directory, copied without edits')
    parser.add_argument('--door-index', type=int, default=1, help='one-based actual non-self current-map door')
    parser.add_argument('--battle-species', default='rattata')
    parser.add_argument('--battle-level', type=int, default=5)
    parser.add_argument('--battle-frames', type=int, default=30)
    parser.add_argument('--settle-frames', type=int, default=300)
    args = parser.parse_args()
    sdk = run.sdk_path(args.sdk)
    output = Path(args.output).expanduser().resolve()
    checkpoint = None
    if args.checkpoint:
        if args.mode != 'production' or args.save_dir is None:
            parser.error('--checkpoint requires --mode production and --save-dir')
        if not 1 <= args.door_index <= 128 or not 1 <= args.battle_level <= 100 \
                or not 1 <= args.battle_frames <= 1800 or not 1 <= args.settle_frames <= 1800:
            parser.error('checkpoint probe bounds are invalid')
        checkpoint = {key: getattr(args, key) for key in ('save_dir', 'door_index', 'battle_species',
                      'battle_level', 'battle_frames', 'settle_frames')}
    elif args.save_dir:
        parser.error('--save-dir requires the labelled --checkpoint mode')
    with OwnerLock(run.runtime_lock_path(sdk)) if args.execute else nullcontext():
        metadata = prepare(args.project.expanduser().resolve(), sdk, output, uuid.uuid4().hex, args.mode, checkpoint, args.device_test)
        if args.execute:
            execute(metadata, output, args.timeout)
    print(output)


if __name__ == '__main__':
    main()
