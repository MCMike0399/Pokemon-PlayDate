#!/usr/bin/env python3
"""Compile the returned API patch and new modules privately; never run Simulator."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    shutil.copytree(ROOT / 'Source', output / 'Source')
    subprocess.run(['git', 'apply', str(ROOT / 'docs/implementation/field-travel/root-api.patch')],
                   cwd=output, check=True)
    entry = output / 'Source/main.lua'
    text = entry.read_text().replace('import "domain/gameSession"',
                                    'import "domain/fieldTravel"\nimport "domain/gameSession"', 1)
    text = text.replace('import "game/context"',
                        'import "game/fieldTravelWorld"\nimport "game/fieldTravelRequests"\nimport "game/context"', 1)
    text += '\nimport "dev/fieldTravelContracts"\n'
    entry.write_text(text)
    with (output / 'compile.log').open('w') as log:
        subprocess.run([str(args.sdk / 'bin/pdc'), str(output / 'Source'), str(output / 'Prepared.pdx')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    print(f'Compile-only API candidate: {output}')


if __name__ == '__main__':
    main()
