#!/usr/bin/env python3
"""Compile a passive startup probe. Only the root Simulator owner may --execute."""
import argparse
from contextlib import nullcontext
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


def instrument(text, session, mode):
    # Same observer in both modes, starting before any import. No dev dependency.
    before = 'local startupProbeBegin = playdate.getCurrentTimeMilliseconds()\n'
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
    return before + text + after


def prepare(project, sdk, output, session, mode):
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
    main.write_text(instrument(original, session, mode))
    (output / 'uninstrumented-main.lua').write_text(original)
    metadata.update(probe_mode=mode, session_id=session,
                    compiled_source_sha256=run.fingerprint(output, exclude_generated=False),
                    measurement='instrumented Simulator startup and Lua heap; two explicit full GC passes; no native allocation claim')
    with (output / 'probe-build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(output / 'Source'), metadata['bundle']],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    atomic_json(output / 'build.json', metadata)
    return metadata


def execute(metadata, output, timeout):
    data = Path(metadata['data_dir'])
    data.mkdir(parents=True, exist_ok=False)
    process = None
    try:
        with OwnerLock(data / 'owner.lock'), (output / 'simulator.log').open('w') as log:
            try:
                process = subprocess.Popen([metadata['simulator'], metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
                atomic_json(output / 'run.json', dict(metadata, simulator_pid=process.pid))
                deadline = time.monotonic() + timeout
                while not (data / 'startup-probe.json').exists():
                    if process.poll() is not None or time.monotonic() >= deadline:
                        raise ProtocolError('startup probe exited or timed out before publication')
                    time.sleep(0.05)
                report = json.loads((data / 'startup-probe.json').read_text())
                if (report.get('session_id'), report.get('mode'), report.get('simulator')) != (metadata['session_id'], metadata['probe_mode'], True):
                    raise ProtocolError('startup probe identity mismatch')
                atomic_json(output / 'startup-probe.json', report)
            finally:
                if process is not None and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=3)
    finally:
        shutil.copytree(data, output / 'runtime-data')
        shutil.rmtree(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('legacy-production', 'production', 'harness'), required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--project', type=Path, default=run.PROJECT, help='read-only source checkout to measure')
    parser.add_argument('--sdk')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--timeout', type=float, default=30)
    args = parser.parse_args()
    sdk = run.sdk_path(args.sdk)
    output = Path(args.output).expanduser().resolve()
    with OwnerLock(run.runtime_lock_path(sdk)) if args.execute else nullcontext():
        metadata = prepare(args.project.expanduser().resolve(), sdk, output, uuid.uuid4().hex, args.mode)
        if args.execute:
            execute(metadata, output, args.timeout)
    print(output)


if __name__ == '__main__':
    main()
