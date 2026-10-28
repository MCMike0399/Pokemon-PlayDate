#!/usr/bin/env python3
"""Compile Celadon modules plus unapplied owner hooks privately; never launch SDK."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--sdk',type=Path,default=Path.home()/'Developer/PlaydateSDK')
    args = parser.parse_args()
    out = args.output.expanduser().resolve()
    out.mkdir(parents=True,exist_ok=False)
    shutil.copytree(ROOT/'Source',out/'Source')
    subprocess.run(['git','apply',str(ROOT/'tools/celadon-services/root-api.patch')],cwd=out,check=True)
    main = out/'Source/main.lua'
    text = main.read_text()
    text = text.replace('\ngame = GameContext', '\nimport "game/celadonServices"\nimport "game/celadonServicesController"\n\ngame = GameContext',1)
    text += '\nimport "dev/celadonServicesContracts"\n'
    main.write_text(text)
    with (out/'compile.log').open('w') as log:
        subprocess.run([str(args.sdk/'bin/pdc'),str(out/'Source'),str(out/'CeladonPrepared.pdx')],
                       stdout=log,stderr=subprocess.STDOUT,check=True)
    (out/'preparation.json').write_text(json.dumps(dict(mode='compile-only',simulator_executed=False,
        owner_hook='tools/celadon-services/root-api.patch',coin_wallet_schema='existing private version 4',
        contract_module='Source/dev/celadonServicesContracts.lua'),indent=2)+'\n')
    print('Celadon compile-only candidate: '+str(out))


if __name__=='__main__':
    main()
