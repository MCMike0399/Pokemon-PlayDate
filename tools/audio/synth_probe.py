#!/usr/bin/env python3
"""Compile first audible synth packet. Execution belongs exclusively to root."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.audio.sdk_probe import inventory, digest, sha, execute
from tools.harness.protocol import OwnerLock, atomic_json
from tools.harness.run import runtime_lock_path, sdk_path
ROOT=Path(__file__).resolve().parents[2]


def prepare(output,sdk):
    output.mkdir(parents=True,exist_ok=False)
    source=output/'Source'
    source.mkdir()
    for name in ('audio/scores.lua','audio/engine.lua','game/kantoAudio.lua'):
        target=source/name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/'Source'/name,target)
    shutil.copyfile(ROOT/'tools/audio/synth_probe/main.lua',source/'probe.lua')
    identity={'schema':1,'session_id':uuid.uuid4().hex,'kind':'native-synth-first-packet',
              'source_sha256':digest(inventory(source))}
    identity['bundle_id']='com.poc.pokemon.audioprobe.'+identity['session_id']
    import json
    (source/'main.lua').write_text('ProbeIdentity={'+','.join(
        key+'='+json.dumps(value) for key,value in identity.items())+'}\nimport "probe"\n')
    (source/'pdxinfo').write_text(f'name=Kanto Synth Probe\nbundleID={identity["bundle_id"]}\nversion=1.0\nbuildNumber=1\n')
    metadata={'identity':identity,'sdk':str(sdk),'sdk_version':(sdk/'VERSION.txt').read_text().strip(),
              'sdk_docs_sha256':sha(sdk/'Inside Playdate.html'),'pdc_sha256':sha(sdk/'bin/pdc'),
              'bundle':str(output/'KantoSynth.pdx'),'data_dir':str(sdk/'Disk/Data'/identity['bundle_id']),
              'simulator':str(sdk/'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'),
              'staged_manifest':inventory(source),'compile_only':True}
    with (output/'compile.log').open('w') as log:
        subprocess.run([str(sdk/'bin/pdc'),str(source),metadata['bundle']],check=True,
                       stdout=log,stderr=subprocess.STDOUT,timeout=60)
    metadata['compiled_manifest']=inventory(Path(metadata['bundle']))
    atomic_json(output/'build.json',metadata)
    return metadata


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--sdk')
    p.add_argument('--execute',action='store_true')
    p.add_argument('--runtime-owner',choices=('root',))
    args=p.parse_args()
    if args.execute and args.runtime_owner!='root': p.error('--execute requires --runtime-owner root')
    sdk=sdk_path(args.sdk)
    output=args.output.expanduser().resolve()
    metadata=prepare(output,sdk)
    if args.execute:
        with OwnerLock(runtime_lock_path(sdk)) as owner:
            result=execute(metadata,output,70,owner)
        atomic_json(output/'result.json',result)
        metadata['compile_only']=False
        atomic_json(output/'build.json',metadata)
    print(output/'build.json')
if __name__=='__main__': main()
