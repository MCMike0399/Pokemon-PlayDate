#!/usr/bin/env python3
"""Compile Safari API preparation in a private tree; no Simulator execution."""
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
    subprocess.run(['git', 'apply', str(ROOT / 'docs/implementation/safari-services/root-api.patch')], cwd=output, check=True)
    entry = output / 'Source/main.lua'
    text = entry.read_text().replace('import "domain/gameSession"',
                                    'import "domain/safariGame"\nimport "domain/coinWallet"\nimport "domain/safariBattle"\nimport "domain/gameSession"', 1)
    text = text.replace('import "game/npcTradeState"',
                        'import "game/npcTradeState"\nimport "game/midgameServices"\nimport "game/midgameServicesState"', 1)
    text = text.replace('\ngame = GameContext', '\nMidgameServices.install()\ngame = GameContext', 1)
    text = text.replace('machine:register("event", NPCTradeState(game))', 'machine:register("event", MidgameServicesState(game))', 1)
    text += '\nimport "dev/safariServicesContracts"\n'
    entry.write_text(text)
    with (output / 'compile.log').open('w') as log:
        subprocess.run([str(args.sdk / 'bin/pdc'), str(output / 'Source'), str(output / 'SafariPrepared.pdx')],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    print(f'Safari compile-only candidate: {output}')


if __name__ == '__main__':
    main()
