#!/usr/bin/env python3
"""Private native audio feasibility probe. Compile only unless root opts in."""
import argparse
from contextlib import nullcontext
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
import uuid
import wave

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness.protocol import OwnerLock, ProtocolError, atomic_json
from tools.harness.run import runtime_lock_path, sdk_path

PROJECT = Path(__file__).resolve().parents[2]
HELPER = Path(__file__).with_suffix('') / 'main.lua'
MODES = ('streams', 'sequence')
LOOPS = 100
RATE = 44100
FRAMES = 5292  # exactly 120 ms; deliberately synthetic, not source music


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inventory(directory):
    return {p.relative_to(directory).as_posix(): sha(p)
            for p in sorted(directory.rglob('*')) if p.is_file()}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def bounded_seconds(value):
    try:
        number = float(value)
    except (ValueError, TypeError):
        raise argparse.ArgumentTypeError('timeout must be 20..90 seconds') from None
    if not math.isfinite(number) or not 20 <= number <= 90:
        raise argparse.ArgumentTypeError('timeout must be 20..90 seconds')
    return number


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk')
    parser.add_argument('--output', help='new directory beneath environment evidence/')
    parser.add_argument('--mode', choices=('both',) + MODES, default='both')
    parser.add_argument('--execute', action='store_true', help='root runtime owner only')
    parser.add_argument('--runtime-owner', choices=('root',), help='explicit root ownership assertion')
    parser.add_argument('--audible', action='store_true', help='root opt-in; app gain capped at 0.03')
    parser.add_argument('--timeout', type=bounded_seconds, default=35.0)
    args = parser.parse_args(argv)
    if args.execute and args.runtime_owner != 'root':
        parser.error('--execute requires --runtime-owner root (orchestrator, not OS superuser)')
    if args.audible and not args.execute:
        parser.error('--audible requires --execute --runtime-owner root')
    return args


def marker(path, voice):
    """Four bounded PCM16 mono phase markers, common to both fresh arms."""
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, RATE, FRAMES, 'NONE', 'not compressed'))
        # Low amplitude with unique frequency/phase. No fidelity assertion.
        output.writeframes(b''.join(struct.pack('<h', round(1500 * math.sin(
            2 * math.pi * (200 + voice * 50) * n / RATE + voice * math.pi / 4)))
            for n in range(FRAMES)))


def prepare(output, sdk, mode, audible=False):
    if mode not in MODES:
        raise ValueError('unknown mode')
    output.mkdir(parents=True, exist_ok=False)
    source = output / 'Source'
    source.mkdir()
    session = uuid.uuid4().hex
    bundle_id = 'com.poc.pokemon.audioprobe.' + session
    shutil.copyfile(HELPER, source / 'probe.lua')
    for voice in range(1, 5):
        marker(source / f'voice{voice}.wav', voice)
    inputs = inventory(source)
    tool_paths = ('tools/audio/sdk_probe.py', 'tools/audio/sdk_probe/main.lua',
                  'tools/harness/protocol.py', 'tools/harness/run.py', 'tools/harness/build.py')
    tools = {}
    for name in tool_paths:
        destination = output / 'tool-sources' / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PROJECT / name, destination)
        tools[name] = sha(destination)
    identity = {'schema': 1, 'mode': mode, 'session_id': session,
                'bundle_id': bundle_id, 'source_sha256': digest(inputs),
                'tool_sha256': digest(tools), 'asset_sha256': digest({
                    k: v for k, v in inputs.items() if k.endswith('.wav')}),
                'audible': audible, 'loops': LOOPS}
    identity['probe_id'] = digest(identity)
    # All generated strings are ASCII JSON strings, also valid Lua literals.
    values = '\n'.join(f'    {key} = ' + (
        'true' if value is True else 'false' if value is False else json.dumps(value)) + ','
        for key, value in identity.items())
    (source / 'main.lua').write_text('ProbeIdentity = {\n' + values + '\n}\nimport "probe"\n')
    (source / 'pdxinfo').write_text(
        f'name=AudioProbe-{mode}-{session}\nbundleID={bundle_id}\nversion=1.0\nbuildNumber=1\n')
    metadata = {'identity': identity, 'inputs': inputs, 'tools': tools,
                'base_commit': '27443afcc63c9a103a6663876a36e9c67bd80673',
                'research_commits': ['9a1cf87', '9c5ec44', '8def326'],
                'staged_manifest': inventory(source), 'fixture': {
                    'kind': 'synthetic phase markers', 'rate': RATE, 'frames': FRAMES,
                    'seconds': FRAMES / RATE, 'music_fidelity': False},
                'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip(),
                'git_status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=PROJECT, text=True),
                'sdk': str(sdk), 'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
                'sdk_docs_sha256': sha(sdk / 'Inside Playdate.html'),
                'pdc_sha256': sha(sdk / 'bin/pdc'),
                'bundle': str(output / f'AudioProbe-{session}.pdx'),
                'data_dir': str(sdk / 'Disk/Data' / bundle_id),
                'simulator': str(sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator')}
    atomic_json(output / 'build.json', metadata)
    with (output / 'compile.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), metadata['bundle']],
                       check=True, stdout=log, stderr=subprocess.STDOUT, timeout=60)
    metadata['compiled_manifest'] = inventory(Path(metadata['bundle']))
    metadata['compile_only'] = True
    atomic_json(output / 'build.json', metadata)
    return metadata


def verify_staging(metadata, output):
    if inventory(output / 'Source') != metadata['staged_manifest']:
        raise ProtocolError('staged source changed')
    if inventory(Path(metadata['bundle'])) != metadata['compiled_manifest']:
        raise ProtocolError('compiled bundle changed')


def validate_result(value, identity):
    if not isinstance(value, dict) or value.get('identity') != identity:
        raise ProtocolError('probe result identity mismatch')
    if value.get('quiescent') is not True or value.get('publication') != 'producer-stopped-v1':
        raise ProtocolError('probe producer has not stopped')
    if value.get('status') not in ('complete', 'error', 'cancelled'):
        raise ProtocolError('invalid probe terminal status')
    return value


def read_final(data, identity):
    # done.json is published LAST, after update and callback producers stop.
    done = json.loads((data / 'done.json').read_text())
    validate_result(done, identity)
    snapshot = json.loads((data / 'RuntimeSnapshot.json').read_text())
    validate_result(snapshot, identity)
    if snapshot['status'] != done['status']:
        raise ProtocolError('terminal status mismatch')
    return snapshot


def stop_child(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def execute(metadata, output, timeout, owner):
    """Caller holds the harness global OwnerLock throughout both serial arms."""
    expected_lock = runtime_lock_path(Path(metadata['sdk']))
    if (owner is None or owner.path.resolve() != expected_lock.resolve()
            or owner.stream is None or owner.stream.closed):
        raise ProtocolError('execution requires live harness global OwnerLock')
    verify_staging(metadata, output)
    data = Path(metadata['data_dir'])
    expected = Path(metadata['sdk']) / 'Disk/Data' / metadata['identity']['bundle_id']
    if data != expected or not data.name.startswith('com.poc.pokemon.audioprobe.') or data.is_symlink():
        raise ProtocolError('invalid private Data path')
    # Fail on collision: never clean, reuse or adopt somebody else's Data.
    data.mkdir(exist_ok=False)
    process = None
    try:
        with OwnerLock(data / 'owner.lock'), (output / 'simulator.log').open('w') as log:
            try:
                process = subprocess.Popen([metadata['simulator'], metadata['bundle']],
                                           stdout=log, stderr=subprocess.STDOUT)
                atomic_json(output / 'process.json', {'pid': process.pid, 'identity': metadata['identity'],
                                                     'argv': [metadata['simulator'], metadata['bundle']]})
                deadline = time.monotonic() + timeout
                cancelled = False
                while not (data / 'done.json').exists():
                    if process.poll() is not None:
                        raise ProtocolError('owned Simulator exited before producer barrier')
                    if time.monotonic() >= deadline:
                        if cancelled:
                            raise ProtocolError('probe cancellation barrier timed out')
                        atomic_json(data / 'cancel.json', {'identity': metadata['identity']})
                        cancelled = True
                        deadline = time.monotonic() + 3
                    time.sleep(0.05)
                result = read_final(data, metadata['identity'])
                atomic_json(output / 'RuntimeSnapshot.json', result)
                if cancelled or result['status'] != 'complete':
                    raise ProtocolError('probe did not complete: ' + result['status'])
                return result
            finally:
                # Stop and reap only this exact Popen child; never search by name.
                stop_child(process)
                for name in ('done.json', 'RuntimeSnapshot.json', 'cancel.json'):
                    if (data / name).is_file():
                        shutil.copyfile(data / name, output / ('raw-' + name))
    finally:
        shutil.rmtree(data)  # exclusively the directory created above


def run(args):
    bounded_seconds(args.timeout)
    if args.execute and args.runtime_owner != 'root':
        raise ProtocolError('execution requires root runtime ownership assertion')
    if args.audible and not args.execute:
        raise ProtocolError('audible requires explicit execution')
    sdk = sdk_path(args.sdk)
    if (sdk / 'VERSION.txt').read_text().strip() != '3.1.2':
        raise ProtocolError('this packet requires installed SDK 3.1.2')
    evidence = (Path(os.environ.get('POKEMON_ENV', '~/Developer/Pokemon-PlayDate-env')).expanduser()
                / 'evidence').resolve()
    output = Path(args.output).expanduser().resolve() if args.output else evidence / ('audio-sdk-probe-' + uuid.uuid4().hex)
    if not output.is_relative_to(evidence) or output == evidence:
        raise ProtocolError('output must be a new directory beneath environment evidence/')
    context = OwnerLock(runtime_lock_path(sdk)) if args.execute else nullcontext()
    with context as owner:
        output.mkdir(parents=True, exist_ok=False)
        modes = MODES if args.mode == 'both' else (args.mode,)
        summary = {'execute': args.execute, 'audible': args.audible, 'arms': [],
                   'acceptance': 'compile only' if not args.execute else 'SDK API observations only; inspect snapshots'}
        try:
            for mode in modes:
                arm = output / mode
                metadata = prepare(arm, sdk, mode, args.audible)
                entry = {'mode': mode, 'identity': metadata['identity'], 'compiled': True,
                         'runtime': 'not executed'}
                summary['arms'].append(entry)
                if args.execute:
                    result = execute(metadata, arm, args.timeout, owner)
                    entry['runtime'] = result['status']
        except Exception as error:
            summary['error'] = str(error)
            raise
        finally:
            atomic_json(output / 'summary.json', summary)
            print(output)
    return 0


def main(argv=None):
    try:
        return run(parse_args(argv))
    except (OSError, ValueError, ProtocolError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
