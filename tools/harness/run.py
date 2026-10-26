#!/usr/bin/env python3
"""Build and run a private identified Playdate Simulator session."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import sys
import time
import uuid

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness.protocol import Client, OwnerLock, ProtocolError, atomic_json

PROJECT = Path(__file__).resolve().parents[2]


def sdk_path(explicit=None):
    sdk = Path(explicit or os.environ.get('PLAYDATE_SDK_PATH', '~/Developer/PlaydateSDK')).expanduser().resolve()
    if not (sdk / 'bin/pdc').is_file():
        raise ProtocolError(f'Playdate SDK not found: {sdk}; set PLAYDATE_SDK_PATH or --sdk')
    return sdk


def fingerprint(project, exclude_generated=True):
    digest = hashlib.sha256()
    for path in sorted((project / 'Source').rglob('*')):
        if path.is_file():
            if exclude_generated and path.relative_to(project).as_posix() == 'Source/dev/harness_build.lua':
                continue
            digest.update(str(path.relative_to(project)).encode())
            digest.update(b'\0')
            digest.update(path.read_bytes())
    return digest.hexdigest()


def verify_png(path, width=None, height=None):
    path = Path(path)
    try:
        data = path.read_bytes()
        header = data[:24]
    except OSError as error:
        raise ProtocolError(f'missing output: {path}') from error
    if len(data) < 45 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR' or data[-8:] != b'IEND\xaeB`\x82':
        raise ProtocolError(f'invalid PNG output: {path}')
    actual_width, actual_height = struct.unpack('>II', header[16:24])
    if width is not None and (actual_width, actual_height) != (width, height):
        raise ProtocolError(f'wrong PNG dimensions: {path}: {actual_width}x{actual_height}')


def finalize_captures(client, data, output):
    # The producer acknowledgement is a barrier, not a best-effort delay.
    acknowledgement = client.quiesce()
    if acknowledgement.get('quiescent') is not True:
        raise ProtocolError('runtime did not confirm producer quiescence')
    manifest = client.read('captures-final.json')
    if not manifest or manifest.get('quiescent') is not True:
        raise ProtocolError('missing stable final capture manifest')
    for collection in ('captures', 'recent_frames'):
        captures = manifest.get(collection)
        # SDK JSON cannot distinguish an empty Lua list from an empty object.
        if captures == {}:
            captures = []
            manifest[collection] = captures
        if not isinstance(captures, list):
            raise ProtocolError('invalid final capture inventory')
        count_key = 'capture_count' if collection == 'captures' else 'recent_count'
        if manifest.get(count_key) != len(captures):
            raise ProtocolError('incomplete final capture inventory')
        if collection == 'recent_frames' and len(captures) > 8:
            raise ProtocolError('recent frame ring exceeded bound')
        for capture in captures:
            for field in ('raw', 'presentation'):
                path = Path(capture[field])
                if path.is_absolute() or '..' in path.parts:
                    raise ProtocolError('invalid capture path')
                source = data / path if capture.get('storage') == 'runtime-data' else output / 'frames' / path
                verify_png(source, 400, 240)
                if capture.get('storage') == 'runtime-data':
                    destination = output / 'frames' / path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, destination)
    atomic_json(output / 'captures.json', manifest)
    return manifest


def qualify_catalog(client, data, output):
    # Called only after successful producer/capture finalization. Keep host
    # qualification failure distinct from an unconfirmed producer barrier.
    from tools.harness import catalog_qualification
    return catalog_qualification.finalize(output, data, getattr(client, 'evidence', output), getattr(client, 'identity', {}))


def qualify_field_items(client, data, output):
    from tools.harness import field_item_qualification
    return field_item_qualification.finalize(output, data, getattr(client, 'evidence', output), getattr(client, 'identity', {}))


def validate_recent_interval(value):
    """Bound both CLI values and programmatic callers to an exact Lua integer."""
    if isinstance(value, str):
        try:
            value = int(value)
        except ValueError:
            raise argparse.ArgumentTypeError('recent interval must be an integer') from None
    if type(value) is not int or not 1 <= value <= 2147483647:
        raise argparse.ArgumentTypeError('recent interval must be in 1..2147483647')
    return value


def prepare(project, sdk, output, session, recent_interval=1):
    recent_interval = validate_recent_interval(recent_interval)
    source = output / 'Source'
    shutil.copytree(project / 'Source', source)
    # Workers may edit live Source during copy. Identify only the immutable
    # staged bytes that this invocation actually compiles.
    source_hash = fingerprint(output)
    source_manifest = {str(path.relative_to(source)): hashlib.sha256(path.read_bytes()).hexdigest()
                       for path in sorted(source.rglob('*')) if path.is_file()}
    atomic_json(output / 'source-manifest.json', source_manifest)
    original_pdxinfo = (source / 'pdxinfo').read_text()
    original_main = (source / 'main.lua').read_bytes()
    (output / 'original-main.lua').write_bytes(original_main)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip()
    dirty = subprocess.check_output(['git', 'status', '--porcelain'], cwd=project, text=True)
    metadata = {'protocol': 1, 'session_id': session, 'build_id': revision + ':' + source_hash,
                'revision': revision, 'source_sha256': source_hash, 'git_status': dirty,
                'sdk': str(sdk), 'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
                'project': str(project), 'output_dir': str(output / 'frames') + '/',
                'bundle_id': 'com.poc.pokemon.harness.' + session, 'enabled': True,
                'data_dir': str(sdk / 'Disk/Data' / ('com.poc.pokemon.harness.' + session)),
                'original_pdxinfo': original_pdxinfo,
                'original_main_file': 'original-main.lua',
                'capture_policy': {'recent_interval': recent_interval, 'recent_limit': 8,
                                   'final_completed_sample': recent_interval > 1},
                'source_hash_excludes': ['Source/dev/harness_build.lua'],
                'generated_overlays': ['Source/dev/harness_build.lua', 'Source/pdxinfo']}
    (output / 'frames').mkdir()
    # JSON strings are Lua-compatible quoted strings for these machine-generated values.
    lua_values = []
    if recent_interval > 1:
        metadata['recent_interval'] = recent_interval
        metadata['generated_overlays'] += ['Source/dev/capture_policy.lua', 'Source/main.lua']
        overlay = Path(__file__).with_name('capture_policy.lua').read_bytes()
        target = source / 'dev/capture_policy.lua'
        if target.exists():
            raise ProtocolError('capture policy overlay would overwrite staged Source')
        target.write_bytes(overlay)
        (source / 'main.lua').write_bytes(original_main + b'\nimport "dev/capture_policy"\n')
    for key in ('protocol', 'session_id', 'build_id', 'output_dir', 'bundle_id', 'sdk_version', 'enabled', 'data_dir', 'recent_interval'):
        if key not in metadata:
            continue
        value = metadata[key]
        encoded = 'true' if value is True else json.dumps(value, ensure_ascii=False)
        lua_values.append(f'    {key} = {encoded},')
    (source / 'dev/harness_build.lua').write_text('HarnessBuild = {\n' + '\n'.join(lua_values) + '\n}\n')
    pdxinfo = source / 'pdxinfo'
    lines = pdxinfo.read_text().splitlines()
    pdxinfo.write_text('\n'.join('bundleID=' + metadata['bundle_id'] if line.startswith('bundleID=') else line for line in lines) + '\n')
    metadata['compiled_source_sha256'] = fingerprint(output, exclude_generated=False)
    bundle = output / 'Harness.pdx'
    with (output / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), str(bundle)], stdout=log, stderr=subprocess.STDOUT, check=True)
    metadata['bundle'] = str(bundle)
    metadata['simulator'] = str(sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator')
    metadata['data_dir'] = str(sdk / 'Disk/Data' / metadata['bundle_id'])
    atomic_json(output / 'build.json', metadata)
    return metadata


def verify_request_outputs(commands, result, output):
    for command in commands:
        if isinstance(command, str):
            parts = command.split()
            op, values = parts[0], parts[1:]
        else:
            op, values = command.get('op'), command.get('args', [])
        expected = []
        if op in ('shot', 'dumpimg'):
            expected = [str(values[0]) + '.png']
        elif op == 'record':
            expected = [f'{values[0]}-{number:02d}.png' for number in range(1, int(values[1]) + 1)]
        for name in expected:
            verify_png(output / 'frames' / name, 400 if op in ('shot', 'record') else None, 240)
    if result.get('catalog'):
        catalog = dict(result['catalog'], image_root='frames')
        for image in catalog.get('images', []):
            image_path = Path(image['path'])
            if image_path.is_absolute() or '..' in image_path.parts or not (output / 'frames' / image_path).is_file():
                raise ProtocolError(f'missing/invalid catalog output: {image_path}')
            verify_png(output / 'frames' / image_path, image.get('width'), image.get('height'))
        atomic_json(output / 'catalog.json', catalog)


def _run(args):
    sdk = sdk_path(args.sdk)
    session = uuid.uuid4().hex
    output = Path(args.output).expanduser().resolve() if args.output else PROJECT / 'tools/shots/runs' / session
    output.mkdir(parents=True, exist_ok=False)
    scenario = json.loads(Path(args.scenario).read_text()) if args.scenario else {'commands': args.commands or ['gamestate', 'shot smoke']}
    atomic_json(output / 'scenario.json', scenario)
    if not isinstance(scenario, dict):
        raise ProtocolError('scenario must be a JSON object')
    from tools.harness import restarting
    restarting.validate(scenario, getattr(args, 'qualification', False))
    if not args.build_only and any(group.get('journey', {}).get('name') == 'npc-motion-continue' for group in scenario.get('processes', [scenario])):
        from tools.harness.motion_journey import visual_preflight
        visual_preflight(scenario)
    if not args.build_only:
        from tools.harness.brock_capture import visual_preflight as brock_visual_preflight
        brock_visual_preflight(scenario)
    try:
        interval = validate_recent_interval(getattr(args, 'recent_interval', 1))
        metadata = (prepare(PROJECT, sdk, output, session, recent_interval=interval)
                    if interval > 1 else prepare(PROJECT, sdk, output, session))
        from tools.harness import catalog_qualification
        catalog_qualification.prepare(output, scenario, launching=not args.build_only)
        from tools.harness import field_item_qualification
        field_item_qualification.prepare(output, scenario, launching=not args.build_only)
    except BaseException as error:
        atomic_json(output / 'outcome.json', {'ok': False, 'error': str(error), 'session_id': session})
        raise
    if args.build_only:
        print(output)
        return 0
    process = None
    client = None
    captures_finalized = False
    data = Path(metadata['data_dir'])
    data.mkdir(parents=True, exist_ok=False)
    owner = OwnerLock(data / 'owner.lock')
    owner.__enter__()
    if 'processes' in scenario:
        confirmed_exit = True
        try:
            return restarting.run(args, scenario, metadata, output, data, owner, sys.modules[__name__])
        except restarting.UnconfirmedExit:
            confirmed_exit = False
            raise
        finally:
            try:
                if confirmed_exit and data.is_dir():
                    shutil.copytree(data, output / 'runtime-data')
                    shutil.rmtree(data)
            finally:
                owner.__exit__()
    try:
        with (output / 'simulator.log').open('w') as log:
            process = subprocess.Popen([metadata['simulator'], metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
            metadata['simulator_pid'] = process.pid
            atomic_json(output / 'run.json', metadata)
            client = Client(data, metadata['build_id'], session, output, owner=owner)
            client.ready(args.ready_timeout)
            if getattr(args, 'qualification', False):
                from tools.harness.qualification import run as qualify
                summary = qualify(client, output, sdk)
                atomic_json(output / 'qualification.json', summary)
                if not summary.get('ok'):
                    raise ProtocolError('protocol qualification failed')
            if scenario.get('journey'):
                from tools.harness.journeys import run as run_journey
                summary = run_journey(client, scenario, output)
                atomic_json(output / 'journey-summary.json', summary)
                if summary.get('ok') is False:
                    raise ProtocolError('journey failed')
            for commands in ([] if scenario.get('journey') or getattr(args, 'qualification', False) else scenario.get('requests', [scenario.get('commands', [])])):
                result = client.send(commands, args.timeout, args.max_frames)
                verify_request_outputs(commands, result, output)
            # Ensure runtime-produced images exist before reporting success.
            for path in scenario.get('outputs', []):
                path = Path(path)
                if path.is_absolute() or '..' in path.parts:
                    raise ProtocolError(f'invalid scenario output path: {path}')
                verify_png(output / 'frames' / path)
            finalize_captures(client, data, output)
            captures_finalized = True
            qualify_catalog(client, data, output)
            qualify_field_items(client, data, output)
            atomic_json(output / 'outcome.json', {'ok': True, 'session_id': session})
            print(output)
            return 0
    except BaseException as error:
        if client is not None and not captures_finalized:
            try:
                if client._pending_id is not None:
                    client.recover(timeout=2)
                finalize_captures(client, data, output)
                captures_finalized = True
            except BaseException as capture_error:
                atomic_json(output / 'artifact-finalization.json', {'quiescent': False, 'error': str(capture_error)})
        atomic_json(output / 'outcome.json', {'ok': False, 'error': str(error), 'session_id': session,
                                            'captures_finalized': captures_finalized})
        print(f'{error}\nEvidence: {output}', file=sys.stderr)
        return 1
    finally:
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
        owner.__exit__()
        # Archive mailbox diagnostics before removing ONLY our UUID bundle Data.
        if data.is_dir():
            shutil.copytree(data, output / 'runtime-data')
            shutil.rmtree(data)


def runtime_lock_path(sdk):
    # Shared across repositories, SDK installations and UUID bundle IDs for
    # this macOS user. Ownership precedes staging/building a runtime job.
    return Path('/private/tmp') / f'pokemon-playdate-simulator-{os.getuid()}.lock'


def run(args):
    sdk = sdk_path(args.sdk)
    if args.build_only:
        return _run(args)
    with OwnerLock(runtime_lock_path(sdk)):
        return _run(args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('commands', nargs='*')
    parser.add_argument('--scenario')
    parser.add_argument('--sdk')
    parser.add_argument('--output')
    parser.add_argument('--timeout', type=float, default=60)
    parser.add_argument('--ready-timeout', type=float, default=20)
    parser.add_argument('--max-frames', type=int, default=1800)
    parser.add_argument('--recent-interval', type=validate_recent_interval, default=1,
                        help='diagnostic recent-frame sampling interval; default 1 keeps the original runtime path')
    parser.add_argument('--build-only', action='store_true')
    parser.add_argument('--qualification', action='store_true', help='exercise real-runtime protocol faults, cancellation and ownership')
    args = parser.parse_args()
    try:
        return run(args)
    except (OSError, ValueError, subprocess.CalledProcessError, ProtocolError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
