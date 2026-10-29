#!/usr/bin/env python3
"""Compile only: production staging plus one private serial input module."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.build import stage_production
from tools.device_cycle import inventory, tree_hash
from tools.harness.run import fingerprint

PROJECT = Path(__file__).resolve().parents[2]
FRAME_ANCHOR = '        else\n            updateGame()\n        end\n'
FRAME_HOOK = '''        elseif DEVICE_TEST_BUILD == true then
            DeviceSmoke.runFrame(game, updateGame)
        else
            updateGame()
        end
'''


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError(f'missing or duplicate device hook anchor: {before!r}')
    return text.replace(before, after, 1)


def manifest(source):
    if source.is_symlink() or any(path.is_symlink() for path in source.rglob('*')):
        raise ValueError('symlink refused in retained source')
    return {path.relative_to(source).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(source.rglob('*')) if path.is_file()}


def diff(before, after):
    return ''.join(difflib.unified_diff(
        before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile='a/Source/main.lua', tofile='b/Source/main.lua'))


def prepare(project, sdk, output):
    # A new directory and random bundle ID isolate artifacts and device saves.
    output.mkdir(parents=True, exist_ok=False)
    source = stage_production(project, output)
    original_manifest = manifest(source)
    original = (source / 'main.lua').read_text()
    if 'dev/deviceSmoke' in original or 'DEVICE_TEST_BUILD = ' in original:
        raise ValueError('private device import/flag must not be in the project entry point')
    if 'GameBootstrap.runFrame(updateGame, game)' in original:
        root_hook = original
    elif original.count(FRAME_HOOK) == 1:
        root_hook = original
    else:
        root_hook = replace_once(original, FRAME_ANCHOR, FRAME_HOOK)
    (output / 'root-hooks.patch').write_text(diff(original, root_hook))
    private = replace_once(root_hook, 'import "CoreLibs/graphics"\n',
                           'import "CoreLibs/graphics"\nimport "dev/deviceSmoke"\n')
    identity = uuid.uuid4().hex
    private = f'DEVICE_TEST_BUILD = true\nDEVICE_TEST_ID = "{identity}"\n' + private
    module = (project / 'Source/dev/deviceSmoke.lua').read_bytes()
    simulator_transport = b'DeviceSmoke.simulatorTransportVersion = 1' in module
    if simulator_transport:
        private += '\nDeviceSmoke.installSimulatorObserver()\n'
    (source / 'main.lua').write_text(private)
    (output / 'private-main.patch').write_text(diff(original, private))
    (source / 'dev').mkdir()
    (source / 'dev/deviceSmoke.lua').write_bytes(module)
    info_path = source / 'pdxinfo'
    info = info_path.read_text()
    bundle_id = f'com.poc.pokemon.device-test.{identity}'
    lines = [f'bundleID={bundle_id}' if line.startswith('bundleID=') else line
             for line in info.splitlines()]
    if sum(line.startswith('bundleID=') for line in lines) != 1:
        raise ValueError('exactly one bundleID required')
    info_path.write_text('\n'.join(lines) + '\n')
    staged_manifest = manifest(source)
    changed = {name for name in original_manifest
               if original_manifest[name] != staged_manifest.get(name)}
    added = set(staged_manifest) - set(original_manifest)
    if changed != {'main.lua', 'pdxinfo'} or added != {'dev/deviceSmoke.lua'}:
        raise ValueError('private staging exceeded allowed overlay')
    bundle = output / 'DeviceSmoke.pdx'
    with (output / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), str(bundle)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    metadata = {
        'mode': 'device-test-compile-only', 'protocol': 'DS1', 'build_id': identity,
        'bundle_id': bundle_id, 'bundle': str(bundle),
        'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
        'project_source_sha256': fingerprint(project, exclude_generated=False),
        'source_sha256': fingerprint(output, exclude_generated=False),
        'production_source_sha256': tree_hash(original_manifest),
        'compiled_source_sha256': tree_hash(staged_manifest),
        'pdx_files': inventory(bundle),
        'pdx_sha256': tree_hash(inventory(bundle)),
        'compiler_sha256': hashlib.sha256((sdk / 'bin/pdc').read_bytes()).hexdigest(),
        'simulator_transport_version': 1 if simulator_transport else None,
        'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
        'production_source_manifest': original_manifest, 'compiled_source_manifest': staged_manifest,
        'limitations': ['No runtime, serial, device, or Simulator execution.',
                        'Root must connect guarded bootstrap errors to DeviceSmoke.fail.',
                        'Hard watchdog stalls and out-of-memory cannot be caught by pcall.'],
    }
    (output / 'build.json').write_text(json.dumps(metadata, indent=2) + '\n')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=PROJECT)
    parser.add_argument('--sdk', type=Path, default=Path('~/Developer/PlaydateSDK'))
    parser.add_argument('--output', type=Path, required=True, help='new private evidence directory')
    args = parser.parse_args()
    result = prepare(args.project.expanduser().resolve(), args.sdk.expanduser().resolve(),
                     args.output.expanduser().resolve())
    print(json.dumps({key: result[key] for key in ('mode', 'build_id', 'bundle')}, indent=2))


if __name__ == '__main__':
    main()
