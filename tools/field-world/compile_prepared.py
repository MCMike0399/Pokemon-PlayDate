#!/usr/bin/env python3
"""Compile production and returned field-world integration; never run a bundle."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.build import compile_production
from tools.harness.build import overlay_imports
from tools.harness.run import fingerprint, sdk_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New durable directory')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    sdk = sdk_path(os.environ.get('PLAYDATE_SDK_PATH'))
    production = output / 'production'
    production.mkdir()
    compile_production(ROOT, sdk, output / 'Production.pdx', production)
    prepared = output / 'sdk-prepared'
    prepared.mkdir()
    shutil.copytree(ROOT / 'Source', prepared / 'Source')
    for name in ('field-cut-flash/root-api.patch', 'field-world-owner/root-integration.patch'):
        subprocess.run(['git', 'apply', str(ROOT / 'docs/implementation' / name)], cwd=prepared, check=True)
    overlay_imports(prepared / 'Source')
    with (prepared / 'Source/main.lua').open('a') as entry:
        entry.write('\n' + (ROOT / 'tools/field-world/sdk_imports.lua').read_text())
    with (prepared / 'compile.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(prepared / 'Source'), str(prepared / 'Prepared.pdx')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    report = {
        'base': '6a137379a7e8b85a7bc8a65eec7c563f58bed756',
        'mode': 'compile-only', 'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
        'source_sha256': fingerprint(ROOT), 'composed_source_sha256': fingerprint(prepared),
        'production_stage': str(production), 'sdk_stage': str(prepared),
        'sdk_cases_prepared': (ROOT / 'Source/dev/fieldWorldContracts.lua').read_text().count('test("field-world:'),
        'runtime_executed': False, 'device_executed': False,
    }
    (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
