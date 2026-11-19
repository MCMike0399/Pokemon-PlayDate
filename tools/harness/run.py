#!/usr/bin/env python3
"""Build and run a private identified Playdate Simulator session."""
import argparse
import glob
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
from tools.harness.protocol import Client, OwnerLock, ProtocolError, atomic_json, shared_lock_directory
from tools.harness.build import overlay_imports

PROJECT = Path(__file__).resolve().parents[2]


def device_lock_path():
    return shared_lock_directory() / f'pokemon-playdate-device-{os.getuid()}.lock'


def _usb_text(path):
    try:
        return path.read_text(encoding='utf-8', errors='replace').strip()
    except OSError as error:
        raise ProtocolError('Cannot read Linux USB identity: ' + str(error)) from error


def linux_playdate_serial_ports(sysfs=None, dev=None):
    """ttyACM nodes whose USB parent is a Playdate.

    An empty /dev/cu.usbmodemPD* result is not evidence that Linux has no
    device. Missing sysfs identity or a node this user cannot open fails
    closed instead of being reported as absent.
    """
    sysfs = Path('/sys/class/tty') if sysfs is None else Path(sysfs)
    dev = Path('/dev') if dev is None else Path(dev)
    if not sysfs.is_dir():
        return []
    ports = []
    for node in sorted(sysfs.iterdir(), key=lambda item: item.name):
        if not node.name.startswith('ttyACM'):
            continue
        device_link = node / 'device'
        if not device_link.exists():
            continue
        try:
            current = device_link.resolve()
        except OSError as error:
            raise ProtocolError('Cannot read Linux serial identity for ' + node.name + ': ' + str(error)) from error
        product = ''
        manufacturer = ''
        for _ in range(8):
            product_path = current / 'product'
            manufacturer_path = current / 'manufacturer'
            if not product and product_path.is_file():
                product = _usb_text(product_path)
            if not manufacturer and manufacturer_path.is_file():
                manufacturer = _usb_text(manufacturer_path)
            if current.parent == current:
                break
            current = current.parent
        identity = (manufacturer + ' ' + product).casefold()
        if 'playdate' not in identity and 'panic' not in identity:
            continue
        path = dev / node.name
        if path.is_symlink() or not path.exists():
            raise ProtocolError('Playdate serial node is missing: ' + str(path))
        if not os.access(path, os.R_OK | os.W_OK):
            raise ProtocolError('Playdate serial node is not readable and writable: ' + str(path))
        ports.append(str(path))
    return ports


def playdate_serial_ports():
    ports = set(glob.glob('/dev/cu.usbmodemPD*'))
    ports.update(glob.glob('/dev/tty.usbmodemPD*'))
    if sys.platform != 'darwin':
        ports.update(linux_playdate_serial_ports())
    return sorted(ports)


def playdate_data_volume():
    """Mounted Playdate data disk, or the Darwin path when it is not mounted."""
    if sys.platform == 'darwin':
        return Path('/Volumes/PLAYDATE')
    mounts = Path('/proc/mounts')
    if not mounts.is_file():
        return None
    for line in mounts.read_text(encoding='utf-8', errors='replace').splitlines():
        fields = line.split()
        if len(fields) < 2:
            continue
        target = Path(fields[1].replace('\\040', ' '))
        if target.name == 'PLAYDATE' and (target / 'Games').is_dir():
            return target
    return None


def eject_argv(volume):
    if sys.platform == 'darwin':
        return ['diskutil', 'eject', str(volume)]
    return ['udisksctl', 'unmount', '-p', str(volume)]


def simulator_usb_preflight():
    ports = playdate_serial_ports()
    if not ports:
        return
    try:
        result = subprocess.run(['lsof', '-Fpcn', '--', *ports],
                                capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ProtocolError('Cannot verify Playdate USB serial ownership: ' + str(error)) from error
    if result.stdout.strip():
        raise ProtocolError('Playdate USB serial port is occupied; close its reader before starting the Simulator. '
                            'lsof ownership: ' + result.stdout.strip().replace('\n', '; '))
    if result.returncode not in (0, 1) or result.stderr.strip():
        raise ProtocolError('Cannot verify Playdate USB serial ownership: ' + result.stderr.strip())


def sdk_path(explicit=None):
    sdk = Path(explicit or os.environ.get('PLAYDATE_SDK_PATH', '~/Developer/PlaydateSDK')).expanduser().resolve()
    if not (sdk / 'bin/pdc').is_file():
        raise ProtocolError(f'Playdate SDK not found: {sdk}; set PLAYDATE_SDK_PATH or --sdk')
    return sdk


def simulator_executable(sdk):
    """Return the official Simulator binary for this SDK install.

    macOS builds ship an app bundle. Linux SDK 3.1.2 ships bin/PlaydateSimulator.
    A missing binary keeps the historical macOS path so compile-only metadata
    stays stable; launch still fails instead of substituting another program.
    """
    mac = sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'
    linux = sdk / 'bin/PlaydateSimulator'
    if mac.is_file():
        return mac
    if linux.is_file():
        return linux
    return mac


def simulator_settings_file():
    """Path of the ini the running platform's Simulator actually writes.

    Darwin keeps ~/Library/Preferences. Linux SDK 3.1.2 writes
    ~/.config/Playdate Simulator/Playdate Simulator.ini, including
    MallocPoolSize=16645684 after Playdate > Malloc Pool > 16 MB.
    """
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Preferences/com.panic.Playdate Simulator.ini'
    return Path.home() / '.config/Playdate Simulator/Playdate Simulator.ini'


def simulator_preflight():
    simulator_usb_preflight()
    settings = simulator_settings_file()
    # SDK 3.1.2 wrote this usable pool size when the user selected 16MB.
    values = dict(line.split('=', 1) for line in settings.read_text().splitlines() if '=' in line)
    if values.get('MallocPoolSize') != '16645684':
        raise ProtocolError('Select Playdate > Malloc Pool > 16MB in the Simulator before runtime checks.')


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


def prepare(project, sdk, output, session, recent_interval=1, journey=False, history=False):
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
                'generated_overlays': ['Source/main.lua', 'Source/dev/harness_build.lua', 'Source/pdxinfo']}
    (output / 'frames').mkdir()
    # JSON strings are Lua-compatible quoted strings for these machine-generated values.
    lua_values = []
    if history and not journey:
        raise ProtocolError('history clearing requires the journey profile')
    if history:
        metadata['history_identity'] = 'JOURNEY'
        metadata['history_clear'] = True
        metadata['history_startup_version'] = 1
        # Freeze check is private staging only; production entry stays byte-exact.
        text = (source / 'main.lua').read_text()
        marker = 'if harness and harness.isQuiescent then return end'
        if text.count(marker) != 1:
            raise ProtocolError('missing unique harness freeze seam')
        startup_marker = '        BootTrace.mark("title.visible")'
        if text.count(startup_marker) != 1:
            raise ProtocolError('missing unique title artwork seam')
        text = text.replace(startup_marker, startup_marker + '\n        Harness.pauseStartup(game)')
        metadata['history_startup_hook_sha256'] = hashlib.sha256(b'Harness.pauseStartup(game)').hexdigest()
        (source / 'main.lua').write_text(text.replace(marker,
            marker + '\n            if harness and harness.historyWaiting and harness.historyWaiting() then return end'))
    if journey:
        metadata['journey_profile'] = True
    if recent_interval > 1:
        metadata['recent_interval'] = recent_interval
        metadata['generated_overlays'].append('Source/dev/capture_policy.lua')
        if 'Source/main.lua' not in metadata['generated_overlays']:
            metadata['generated_overlays'].append('Source/main.lua')
        overlay = Path(__file__).with_name('capture_policy.lua').read_bytes()
        target = source / 'dev/capture_policy.lua'
        if target.exists():
            raise ProtocolError('capture policy overlay would overwrite staged Source')
        target.write_bytes(overlay)
        (source / 'main.lua').write_bytes((source / 'main.lua').read_bytes() + b'\nimport "dev/capture_policy"\n')
    for key in ('protocol', 'session_id', 'build_id', 'output_dir', 'bundle_id', 'sdk_version', 'enabled', 'data_dir', 'recent_interval', 'journey_profile', 'history_clear', 'history_startup_version'):
        if key not in metadata:
            continue
        value = metadata[key]
        encoded = 'true' if value is True else json.dumps(value, ensure_ascii=False)
        lua_values.append(f'    {key} = {encoded},')
    (source / 'dev/harness_build.lua').write_text('HarnessBuild = {\n' + '\n'.join(lua_values) + '\n}\n')
    if journey:
        metadata['harness_profile'] = 'journey'
        overlay_imports(source, journey=True)
        keep = {'harness_build.lua', 'harness_capture.lua', 'diagnostics.lua',
                'fixtures.lua', 'autopilot.lua', 'harness.lua',
                'ceruleanJourney.json', 'vermilionJourney.json',
                'daycareContracts.lua'}
        if recent_interval > 1:
            keep.add('capture_policy.lua')
        removed = []
        for path in sorted((source / 'dev').rglob('*')):
            if path.is_file() and path.relative_to(source / 'dev').as_posix() not in keep:
                removed.append(path.relative_to(source).as_posix())
                path.unlink()
        metadata['excluded_development_files'] = removed
    else:
        overlay_imports(source)
    pdxinfo = source / 'pdxinfo'
    lines = pdxinfo.read_text().splitlines()
    pdxinfo.write_text('\n'.join('bundleID=' + metadata['bundle_id'] if line.startswith('bundleID=') else line for line in lines) + '\n')
    metadata['compiled_source_sha256'] = fingerprint(output, exclude_generated=False)
    bundle = output / 'Harness.pdx'
    with (output / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), str(bundle)], stdout=log, stderr=subprocess.STDOUT, check=True)
    metadata['bundle'] = str(bundle)
    metadata['simulator'] = str(simulator_executable(sdk))
    metadata['data_dir'] = str(sdk / 'Disk/Data' / metadata['bundle_id'])
    if history:
        metadata['pdx_files'] = {path.relative_to(bundle).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in sorted(bundle.rglob('*')) if path.is_file()
                                 and path.name != '.DS_Store' and not path.name.startswith('._')}
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
        images = catalog.get('images', [])
        # The simulator keeps the manifest in chunks of at most 4096 rows.
        # One Lua array cannot grow past 8192 slots in the shipping pool.
        if images and isinstance(images[0], list):
            flat = []
            for chunk in images:
                if not isinstance(chunk, list):
                    raise ProtocolError('catalog image chunk is not a list')
                flat.extend(chunk)
            catalog['images'] = flat
            images = flat
        for image in images:
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
    history = restarting.history_options(args, scenario)
    if not args.build_only and any(group.get('journey', {}).get('name') == 'npc-motion-continue' for group in scenario.get('processes', [scenario])):
        from tools.harness.motion_journey import visual_preflight
        visual_preflight(scenario)
    if not args.build_only:
        from tools.harness.brock_capture import visual_preflight as brock_visual_preflight
        brock_visual_preflight(scenario)
    try:
        interval = validate_recent_interval(getattr(args, 'recent_interval', 1))
        groups = scenario.get('processes', [scenario])
        journey_only = bool(groups) and all(group.get('journey') for group in groups)
        if journey_only:
            metadata = prepare(PROJECT, sdk, output, session,
                               recent_interval=interval, journey=True, **({'history': True} if history else {}))
        else:
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
    owner = OwnerLock(data / 'owner.lock', history=history)
    owner.__enter__()
    if 'processes' in scenario:
        confirmed_exit = True
        try:
            from tools.harness.evidence_mirror import mirrored_evidence_reads
            with mirrored_evidence_reads():
                restarting.import_chain_save(scenario, PROJECT, data, output)
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
            simulator_preflight()
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
    # Shared across repositories, SDK installations and UUID bundle IDs.
    # Ownership precedes staging/building a runtime job.
    return shared_lock_directory() / f'pokemon-playdate-simulator-{os.getuid()}.lock'


def run(args):
    sdk = sdk_path(args.sdk)
    if args.build_only:
        return _run(args)
    from tools.harness.restarting import history_options
    history = history_options(args)
    with OwnerLock(runtime_lock_path(sdk), history=history), OwnerLock(device_lock_path(), history=history):
        simulator_preflight()
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
    parser.add_argument('--history-helper', type=Path, help='opt in to pinned JOURNEY history clearing')
    parser.add_argument('--history-helper-sha256', help='exact private helper binary SHA256')
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
