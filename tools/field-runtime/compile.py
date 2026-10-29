#!/usr/bin/env python3
"""Compile the runtime field integration, tiny returned owner hooks and contracts."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    shutil.copytree(ROOT / 'Source', output / 'Source')
    subprocess.run(['git', 'apply', str(ROOT / 'docs/implementation/field-runtime/view-handoff.patch')], cwd=output, check=True)
    session = output / 'Source/domain/gameSession.lua'
    text = session.read_text().replace('thunder="BADGE_THUNDER"}', 'thunder="BADGE_THUNDER",rainbow="BADGE_RAINBOW",soul="BADGE_SOUL"}')
    session.write_text(text)
    entry = output / 'Source/main.lua'
    text = entry.read_text().replace('import "game/context"', 'import "game/fieldTravelRuntime"\nimport "game/context"', 1)
    text = text.replace('import "game/fieldMoveState"', 'import "game/fieldTravelState"\nimport "game/fieldMoveState"', 1)
    text = text.replace('machine:register("fieldMove", FieldMoveState(game))',
                        'machine:register("fieldMove", FieldMoveState(game))\nmachine:register("fieldTravel", FieldTravelState(game))', 1)
    text += '\nimport "dev/fieldTravelContracts"\n'
    entry.write_text(text)
    with (output / 'compile.log').open('w') as log:
        subprocess.run([str(args.sdk / 'bin/pdc'), str(output / 'Source'), str(output / 'Prepared.pdx')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    print(f'Runtime compile-only candidate: {output}')


if __name__ == '__main__':
    main()
