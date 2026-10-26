#!/usr/bin/env python3
"""Compile a production bundle from a private source tree without dev modules."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.harness.run import sdk_path, fingerprint

PROJECT = Path(__file__).resolve().parents[1]


def stage_production(project, stage):
    source = stage / 'Source'
    shutil.copytree(project / 'Source', source,
                    ignore=lambda directory, names: ['dev'] if Path(directory) == project / 'Source' else [])
    return source


def compile_production(project, sdk, output, stage):
    if output.suffix != '.pdx':
        raise ValueError('production output must have .pdx suffix')
    source = stage_production(project, stage)
    bundle = stage / 'Production.pdx'
    with (stage / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), str(bundle)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    if (bundle / 'dev').exists():
        raise ValueError('production bundle contains dev modules')
    # Publish a fresh bundle: pdc does not remove files from previous builds.
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(bundle, output)
    (stage / 'build.json').write_text(json.dumps({
        'mode': 'production', 'source_sha256': fingerprint(stage, exclude_generated=False),
        'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
        'bundle': str(output), 'excluded': ['Source/dev'],
    }, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk')
    parser.add_argument('--output', default='PokemonPoC.pdx')
    parser.add_argument('--stage', help='retain source and build log in this new directory')
    args = parser.parse_args()
    sdk = sdk_path(args.sdk)
    output = Path(args.output).expanduser().resolve()
    if args.stage:
        stage = Path(args.stage).expanduser().resolve()
        stage.mkdir(parents=True, exist_ok=False)
        compile_production(PROJECT, sdk, output, stage)
    else:
        with tempfile.TemporaryDirectory(prefix='pokemon-production-') as temporary:
            compile_production(PROJECT, sdk, output, Path(temporary))


if __name__ == '__main__':
    main()
