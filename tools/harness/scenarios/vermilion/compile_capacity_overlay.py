#!/usr/bin/env python3
"""Compile the two proposed harness overlays in a new evidence tree; never run."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.harness.run import fingerprint, prepare, sdk_path


def compile_overlay(output, sdk):
    output.mkdir(parents=True, exist_ok=False)
    original = output / 'original'
    original.mkdir()
    # The shared prepare function stages and compiles only. This helper never
    # calls the runner entry point, acquires runtime locks or opens Simulator.
    baseline = prepare(ROOT, sdk, original, str(uuid.uuid4()))
    candidate = output / 'candidate'
    candidate.mkdir()
    shutil.copytree(original / 'Source', candidate / 'Source')
    patches = ['root-collection-observations.patch', 'root-aide-capacity-fixture.patch']
    for name in patches:
        subprocess.run(['git', 'apply', str(Path(__file__).parent / name)], cwd=candidate,
                       check=True, capture_output=True, text=True)
    bundle = candidate / 'AideCapacityCompile.pdx'
    with (candidate / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(candidate / 'Source'), str(bundle)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    manifest = {p.relative_to(candidate / 'Source').as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted((candidate / 'Source').rglob('*')) if p.is_file()}
    (candidate / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    metadata = dict(mode='compile-only', runtime_executed=False, sdk_version=baseline['sdk_version'],
                    revision=baseline['revision'], base_source_sha256=baseline['source_sha256'],
                    compiled_source_sha256=fingerprint(candidate, exclude_generated=False),
                    bundle=str(bundle), patches=patches,
                    active_maps=len(json.loads((candidate / 'Source/data/sourceMaps.json').read_text())['maps']),
                    note='Harness overlay syntax only. Recruitment, capacity retries, natural collection and activation remain unrun.')
    (candidate / 'build.json').write_text(json.dumps(metadata, indent=2) + '\n')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk')
    args = parser.parse_args()
    print(json.dumps(compile_overlay(args.output.expanduser().resolve(), sdk_path(args.sdk)), indent=2))


if __name__ == '__main__':
    main()
