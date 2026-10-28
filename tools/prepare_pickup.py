#!/usr/bin/env python3
"""Compose the returned bootstrap patch and compile with actual SDK; never launch."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build import compile_production
from tools.harness import build as overlay
from tools.harness.run import fingerprint


def prepare(output, sdk):
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'composed'
    shutil.copytree(ROOT / 'Source', project / 'Source')
    for name in ['tools/harness/dev_imports.lua', 'tools/tests/fixtures/dev-import-gate.json']:
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
    patch = ROOT / 'docs/implementation/approved-pickup/root-bootstrap.patch'
    subprocess.run(['git', 'apply', '--check', str(patch)], cwd=project, check=True)
    subprocess.run(['git', 'apply', str(patch)], cwd=project, check=True)
    production = output / 'production'
    production.mkdir()
    compile_production(project, sdk, output / 'Production.pdx', production)
    harness = output / 'harness'
    shutil.copytree(project / 'Source', harness / 'Source')
    previous = overlay.IMPORTS
    try:
        overlay.IMPORTS = project / 'tools/harness/dev_imports.lua'
        overlay.overlay_imports(harness / 'Source')
    finally:
        overlay.IMPORTS = previous
    with (output / 'sdk-compile.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(harness / 'Source'), str(output / 'Prepared.pdx')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    report = {
        'base': 'e4dd170', 'mode': 'compile-only',
        'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
        'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_sha256': fingerprint(ROOT), 'composed_source_sha256': fingerprint(project),
        'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
        'runtime_executed': False, 'device_executed': False,
        'production': str(production), 'sdk_prepared': str(harness),
    }
    (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    args = p.parse_args()
    prepare(args.output.expanduser().resolve(), args.sdk.expanduser().resolve())
