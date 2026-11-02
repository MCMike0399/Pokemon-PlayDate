#!/usr/bin/env python3
"""Host/compile only; read exact B, copy earned bytes, overlay private DS1."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import sys

PACKET = Path(__file__).resolve().parent
B = Path('/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160')
REVISION = '565bfdfb4c0f2b37c921fa79e143067fe45b7637'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_inputs():
    pins = json.loads((PACKET / 'inputs.json').read_text())
    if subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=B, text=True).strip() != REVISION:
        raise ValueError('B checkout revision changed; do not substitute main108')
    dirty = subprocess.check_output(
        ['git', 'status', '--porcelain', '--untracked-files=all', '--', 'Source', 'tools'],
        cwd=B, text=True).strip()
    if dirty:
        raise ValueError('B Source/tooling changed outside the pinned commit: ' + dirty)
    for name, expected in pins['b_files'].items():
        if digest(B / name) != expected:
            raise ValueError('B input changed: ' + name)
    seed = Path(pins['seed_directory'])
    for row in pins['seed_files']:
        if digest(seed / row['file']) != row['sha256']:
            raise ValueError('earned seed/provenance changed')
    return pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    args = parser.parse_args()
    pins = check_inputs()
    sys.path.insert(0, str(B))
    from tools.device import build_smoke
    from tools.device_cycle import inventory, tree_hash
    from tools.harness.run import fingerprint
    from tools.device.simulator_smoke import verify
    output = args.output.expanduser().resolve()
    sdk = args.sdk.expanduser().resolve()
    build = build_smoke.prepare(B, sdk, output)
    (output / 'base-build.json').write_text(json.dumps(build, indent=2) + '\n')
    source = output / 'Source'
    path = source / 'dev/deviceSmoke.lua'
    original = path.read_text()
    # Only extend the read snapshot. Preserve parser, timing, error, transport.
    before = '    return result\nend\n\nfunction DeviceSmoke.drawError()'
    after = ('    result.long_traversal = DeviceSmoke.longTraversalStatus and '
             'DeviceSmoke.longTraversalStatus()\n'
             '    result.resources = DeviceSmoke.longTraversalResources(runtimeGame)\n' + before)
    module = build_smoke.replace_once(original, before, after)
    module += '\n' + (PACKET / 'diagnostic.lua').read_text()
    path.write_text(module)
    with (output / 'diagnostic-overlay.patch').open('w') as patch:
        patch.write(''.join(difflib.unified_diff(original.splitlines(True), module.splitlines(True),
                    fromfile='a/Source/dev/deviceSmoke.lua', tofile='b/Source/dev/deviceSmoke.lua')))
    with (source / 'main.lua').open('a') as main_file:
        main_file.write('\nDeviceSmoke.installLongTraversal()\n')
    with (output / 'long-traversal-build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), build['bundle']],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    build['compiled_source_manifest'] = build_smoke.manifest(source)
    build['compiled_source_sha256'] = tree_hash(build['compiled_source_manifest'])
    build['source_sha256'] = fingerprint(output, exclude_generated=False)
    build['pdx_files'] = inventory(Path(build['bundle']))
    build['pdx_sha256'] = tree_hash(build['pdx_files'])
    build['diagnostic_only'] = True
    build['long_traversal'] = {'schema': 1, 'b_revision': REVISION,
        'inputs_sha256': digest(PACKET / 'inputs.json'),
        'packet_files': {p.name: digest(p) for p in sorted(PACKET.iterdir()) if p.is_file()},
        'hardware_save_prohibited': True, 'automatic_navigation': False}
    (output / 'build.json').write_text(json.dumps(build, indent=2) + '\n')
    # Copies, never edits, canonical files. Existing device owner backs up Data
    # again before import. The private copy remains an immutable seed, not Data.
    seed = Path(pins['seed_directory'])
    target = output / 'immutable-seed'
    target.mkdir()
    for row in pins['seed_files']:
        (target / row['file']).write_bytes((seed / row['file']).read_bytes())
        assert digest(target / row['file']) == row['sha256']
    earned = {'directory': str(target), 'files': pins['seed_files'][:2],
              'provenance': pins['seed_files'][2], 'original_directory': str(seed)}
    (output / 'earned-save.json').write_text(json.dumps(earned, indent=2) + '\n')
    check_inputs()
    verify(output)
    print(json.dumps({'build_id': build['build_id'], 'pdx_sha256': build['pdx_sha256'],
                      'production_source_sha256': build['production_source_sha256']}, indent=2))


if __name__ == '__main__':
    main()
