"""Compile the Day Care candidate and prepared SDK witnesses; never run them.

Shared Source files are patched only in a new evidence directory. The existing
harness compiler supplies SDK configuration and records its original build;
this tool records a separate identity for the composed compile-only candidate.
"""
import argparse
import hashlib
import json
import io
import tarfile
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.harness.run import fingerprint, prepare, sdk_path
from tools.harness import build as harness_build

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Day Care staging seam changed: ' + old)
    return text.replace(old, new)


def compose(output, sdk):
    output.mkdir(parents=True, exist_ok=False)
    original = output / 'original'
    original.mkdir()
    prepare(ROOT, sdk, original, str(uuid.uuid4()))
    candidate = output / 'candidate'
    candidate.mkdir()
    # Read the exact root schema2 tree; never merge it into the worker checkout.
    root_base = '2a207be'
    archive = subprocess.check_output(['git', 'archive', root_base, 'Source',
                                       'tools/harness/dev_imports.lua'], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as contents:
        contents.extractall(candidate, filter='data')
    owned = ['game/daycare.lua', 'game/daycareState.lua', 'dev/daycareContracts.lua',
             'data/daycare/policy.json']
    for name in owned:
        target = candidate / 'Source' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'Source' / name, target)
    shutil.copyfile(original / 'Source/dev/harness_build.lua', candidate / 'Source/dev/harness_build.lua')
    # git apply works outside a repository; --unsafe-paths is unnecessary.
    subprocess.run(['git', 'apply', str(ROOT / 'tools/integration/daycare-api.patch')],
                   cwd=candidate, check=True)
    main = candidate / 'Source/main.lua'
    text = main.read_text()
    text = replace_once(text, 'import "game/kantoServices"',
                        'import "game/kantoServices"\nimport "game/vermilionGifts"\nimport "game/daycare"\nimport "game/daycareState"')
    text = replace_once(text, 'KantoServices.install()', 'KantoServices.install()\nVermilionGifts.install()\nDaycare.install()')
    text = replace_once(text, 'KantoServicesState(game)', 'DaycareState(game)')
    main.write_text(text)
    previous_imports = harness_build.IMPORTS
    try:
        harness_build.IMPORTS = candidate / 'tools/harness/dev_imports.lua'
        harness_build.overlay_imports(candidate / 'Source')
    finally:
        harness_build.IMPORTS = previous_imports
    with main.open('a') as entry:
        entry.write('\nimport "dev/daycareContracts"\nContracts.register("daycare", DaycareContracts.run)\n')
    bundle = candidate / 'DaycareWitness.pdx'
    with (candidate / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(candidate / 'Source'), str(bundle)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    manifest = {str(path.relative_to(candidate / 'Source')): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in sorted((candidate / 'Source').rglob('*')) if path.is_file()}
    (candidate / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    metadata = dict(mode='compile-only', runtime_executed=False, root_base=root_base, sdk_version=(sdk / 'VERSION.txt').read_text().strip(),
                    source_sha256=fingerprint(candidate, exclude_generated=False), bundle=str(bundle),
                    revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    patches=['tools/integration/daycare-api.patch'],
                    wiring='Imports/installs gifts + daycare; one DaycareState event controller; Daycare SDK suite registered.',
                    note='Daycare map activation, native execution and process restart remain root-owned.')
    (candidate / 'build.json').write_text(json.dumps(metadata, indent=2) + '\n')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--sdk')
    args = parser.parse_args()
    metadata = compose(args.output.expanduser().resolve(), sdk_path(args.sdk))
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
