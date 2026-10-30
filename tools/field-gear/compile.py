#!/usr/bin/env python3
"""Compile the gear packet and returned session hook; no Simulator launch."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    subprocess.run([sys.executable, str(ROOT / 'tools/field-travel/compile.py'),
                    '--output', str(output), '--sdk', str(args.sdk)], check=True)
    session = output / 'Source/domain/gameSession.lua'
    session.write_text(session.read_text() + '\n' + (ROOT / 'docs/implementation/field-gear/root-cycling-method.lua').read_text())
    entry = output / 'Source/main.lua'
    text = entry.read_text().replace('import "domain/gameSession"',
                                    'import "domain/fieldCycling"\nimport "domain/fieldFishing"\nimport "domain/gameSession"', 1)
    text = text.replace('import "game/context"', 'import "game/fieldGearRequests"\nimport "game/context"', 1)
    text += '\nimport "dev/fieldGearContracts"\n'
    entry.write_text(text)
    with (output / 'gear-compile.log').open('w') as log:
        subprocess.run([str(args.sdk / 'bin/pdc'), str(output / 'Source'), str(output / 'GearPrepared.pdx')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    print(f'Gear compile-only candidate: {output}')


if __name__ == '__main__':
    main()
