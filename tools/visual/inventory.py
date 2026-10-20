#!/usr/bin/env python3
"""Independent expected inventory for the four explicit pinned slice maps/NPCs."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.visual.paths import contained, image_directory
from PIL import Image

REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
NAMES = ('Route1','ViridianCity','ViridianMart','ViridianPokecenter')
RUNTIME_NPCS = dict(youngster='kantoYoungster',gambler='kantoGambler',girl='kantoGirl',
    gambler_asleep='kantoGamblerAsleep',fisher='kantoFisher',clerk='kantoClerk',
    cooltrainer_m='kantoCooltrainerM',nurse='kantoNurse',gentleman='kantoGentleman',link_receptionist='kantoLinkReceptionist')


def stable_name(key):
    if not isinstance(key,str) or not 1 <= len(key.encode()) <= 100:
        raise ValueError('stable content key requires 1..100 UTF8 bytes')
    return key.encode().hex()


def expected_slice(source):
    source=Path(source);directory=source/'data/viridianSlice'
    paths=set();tile_keys=set();inputs={};frames=facings=0
    def load(name):
        path=directory/name;inputs[str(path.relative_to(source))]=hashlib.sha256(path.read_bytes()).hexdigest()
        value=json.loads(path.read_text())
        if value.get('schema')!=1 or value.get('source_revision')!=REVISION:
            raise ValueError('unverified slice source: '+name)
        return value
    def asset(prefix,backgrounds=False):
        paths.update((prefix+'.png',prefix+'__mask.png'))
        if backgrounds:paths.update(prefix+'__'+bg+'.png' for bg in ('white','black','texture'))
    for name in NAMES:
        definition=load(name+'.json')
        for entry in definition['grids']:tile_keys.add(entry['stable_id'])
        if definition['dimensions']['cells'][0]<13:tile_keys.add('adapter:viridian-slice:void')
        prefix='map_imported_'+stable_name(definition['id'])
        paths.update(prefix+suffix+'.png' for suffix in ('','__viewport','__collision','__events'))
    for key in tile_keys:asset('tile_imported_'+stable_name(key))
    sprites=load('sprites.json')['sprites']
    if set(sprites)!=set(RUNTIME_NPCS):raise ValueError('slice NPC roster changed; update independent inventory deliberately')
    for name,entry in sprites.items():
        for frame in entry['frames']:
            if not re.fullmatch(r'0|[1-9][0-9]?',frame):raise ValueError('invalid source frame index')
            asset('npc_source_'+stable_name(name)+'_frame_'+frame,True);frames+=1
        standing=set(entry['standing'])
        if 'left' in standing:standing.add('right')
        for facing in standing:
            if facing not in ('down','up','left','right'):raise ValueError('unknown facing')
            asset('npc_'+RUNTIME_NPCS[name]+'_'+facing,True);facings+=1
    return dict(schema=1,source_revision=REVISION,inputs=inputs,expected=sorted(paths),
                counts=dict(images=len(paths),imported_tiles=len(tile_keys),source_npc_frames=frames,runtime_npc_facings=facings,maps=len(NAMES)))


def inspect_catalog(catalog, expected):
    catalog=Path(catalog);manifest=json.loads((catalog/'catalog.json').read_text());root=image_directory(catalog,manifest)
    entries=manifest['images'];paths=[item['path'] for item in entries]
    if not paths or len(paths)!=len(set(paths)):raise ValueError('empty or duplicate catalog inventory')
    for path in paths:contained(root,path)
    missing=sorted(set(expected['expected'])-set(paths));invalid=[]
    for path in sorted(set(expected['expected']) & set(paths)):
        try:
            with Image.open(contained(root,path)) as image:
                if image.format!='PNG':raise ValueError('PNG required')
                image.verify()
        except (OSError,ValueError) as error:invalid.append(dict(path=path,error=str(error)))
    return dict(ok=not missing and not invalid,expected_additions=len(expected['expected']),missing_expected=missing,invalid=invalid,
                review_status='inventory coverage only; every addition remains unreviewed')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=Path(__file__).resolve().parents[2]/'Source')
    parser.add_argument('--catalog',type=Path);parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    try:
        report=expected_slice(args.source)
        if args.catalog:report['coverage']=inspect_catalog(args.catalog,report)
        ok=report.get('coverage',{}).get('ok',True)
    except (OSError,ValueError,KeyError) as error:report={'ok':False,'error':str(error)};ok=False
    rendered=json.dumps(report,indent=2)
    if args.report:args.report.write_text(rendered+'\n')
    print(rendered);return 0 if ok else 1


if __name__=='__main__':raise SystemExit(main())
