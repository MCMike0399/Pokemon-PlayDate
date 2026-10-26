#!/usr/bin/env python3
"""Compose the unapplied root patch and SDK cases in a private compile-only tree."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.harness.build import overlay_imports


def prepare(output, sdk):
    output.mkdir(parents=True, exist_ok=False)
    source = output / 'Source'
    shutil.copytree(ROOT / 'Source', source)
    patch = ROOT / 'docs/validation/contact-abilities-root.patch'
    subprocess.run(['git', 'apply', '--check', str(patch)], cwd=output, check=True)
    subprocess.run(['git', 'apply', str(patch)], cwd=output, check=True)
    # The normal private harness import overlay first; tracked main/dev imports
    # remain untouched. The extra registration is included in this tree's hash.
    overlay_imports(source)
    with (source / 'main.lua').open('a') as f:
        f.write('\nimport "dev/contactAbilityContracts"\n'
                'Contracts.register("contact-abilities", ContactAbilityContracts.run)\n')
    manifest = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(source.rglob('*')) if p.is_file()}
    metadata = dict(base='30844ee1dc696cadc9febe06c6300f2c697b5711',
                    revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),
                    runtime_executed=False, source=manifest)
    (output / 'composition.json').write_text(json.dumps(metadata, indent=2)+'\n')
    subprocess.run([str(sdk / 'bin/pdc'), str(source), str(output / 'ContactAbilities.pdx')], check=True)
    print('SDK compile only; no Simulator or native acceptance:', output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    args = parser.parse_args()
    prepare(args.output.expanduser().resolve(), args.sdk.expanduser().resolve())
