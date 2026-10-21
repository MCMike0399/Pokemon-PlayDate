#!/usr/bin/env python3
"""Generate original R/B encyclopedia records and ASCII default names, staged only."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/pokedex.json'
class DataError(ValueError):pass

def sha(raw):return hashlib.sha256(raw).hexdigest()
def read_pins(root,manifest):
    root=Path(root).resolve();out={}
    for entry in manifest['inputs']:
        path=(root/entry['path']).resolve()
        if not path.is_relative_to(root):raise DataError('source path escape')
        raw=path.read_bytes()
        if sha(raw)!=entry['sha256']:raise DataError('source checksum mismatch: '+entry['path'])
        out[entry['path']]=raw.decode()
    return out

def ascii_name(name):
    name=name.replace('♀',' F').replace('♂',' M')
    if name=='MR.MIME':name='MR. MIME'
    if not 1<=len(name)<=10 or any(not 32<=ord(c)<=126 for c in name):raise DataError('invalid ASCII species name '+name)
    return name

def parse(raw,species):
    prefix='data/pokemon/'
    numbers={name:int(n) for name,n in re.findall(r'^\s*const (DEX_\w+)\s*; (\d+)',raw['constants/pokedex_constants.asm'],re.M)}
    order=re.findall(r'^\s*db (DEX_\w+|0)\b',raw[prefix+'dex_order.asm'],re.M)
    names=re.findall(r'^\s*dname "([^"]+)"',raw[prefix+'names.asm'],re.M)
    pointers=re.findall(r'^\s*dw (\w+DexEntry)',raw[prefix+'dex_entries.asm'],re.M)
    if not len(order)==len(names)==len(pointers)==190:raise DataError('internal roster table lengths must be190')
    entries={}
    pattern=r'^(\w+DexEntry):\n\s*db "([^"@]+)@"\n\s*db (\d+),\s*(\d+)\n\s*dw (\d+)\n\s*text_far (_\w+)'
    details={label:(category,int(feet),int(inches),int(weight),text) for label,category,feet,inches,weight,text in re.findall(pattern,raw[prefix+'dex_entries.asm'],re.M)}
    texts={}
    for label,body in re.findall(r'^(_\w+DexEntry)::\n(.*?)(?=^_\w+DexEntry::|\Z)',raw[prefix+'dex_text.asm'],re.M|re.S):
        lines=[]
        for command,text in re.findall(r'^\s*(text|next|page) "([^"]*)"',body,re.M):
            if command=='page':lines.append('')
            lines.append(text.replace('#','POKE'))
        if not lines or not re.search(r'^\s*dex\s*$',body,re.M):raise DataError('missing terminated flavor '+label)
        if any(any(not 32<=ord(c)<=126 for c in line) for line in lines):raise DataError('unhandled text encoding '+label)
        texts[label]=lines
    for internal,(key,name,label) in enumerate(zip(order,names,pointers),1):
        if key=='0':continue
        dex=numbers.get(key)
        if dex not in species or dex in entries:raise DataError('unknown/duplicate dex '+str(dex))
        if label not in details:raise DataError('missing entry '+label)
        category,feet,inches,weight,text=details[label]
        if text not in texts or not 0<=inches<12 or weight<=0:raise DataError('bad entry metadata '+label)
        entries[dex]={'dex':dex,'species':species[dex],'name':ascii_name(name),'sourceName':name,'category':category,'heightFeet':feet,'heightInches':inches,'weightTenthsLb':weight,'lines':texts[text],'sourceInternalId':internal,'sourceEntry':label}
    if set(entries)!=set(range(1,152)):raise DataError('expected all151 original species')
    return [entries[n] for n in range(1,152)]

def projection(text):
    pairs=re.findall(r'^    (\w+) = \{\n        name = "[^"]+", dex = (\d+),',text,re.M)
    out={int(dex):key for key,dex in pairs}
    if len(pairs)!=151 or set(out)!=set(range(1,152)):raise DataError('invalid production species projection')
    return out

def lua(value):
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,int):return str(value)
    if isinstance(value,list):return '{'+', '.join(lua(v) for v in value)+'}'
    return '{'+', '.join(k+' = '+lua(v) for k,v in value.items())+'}'

def outputs(entries):
    data='-- Generated pinned original R/B entries; tools/references/pokedex.json.\nPokedexData = {\n'+''.join('    '+lua(e)+',\n' for e in entries)+'}\n'
    names='-- Generated ASCII defaults; existing saved nicknames are never migrated.\nPokemonNames = {\n'+''.join('    '+e['species']+' = '+lua(e['name'])+',\n' for e in entries)+'}\n'
    return {'data/pokedexData.lua':data,'data/pokemonNames.lua':names}

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-root',type=Path,required=True);p.add_argument('--pokemon-source',type=Path,default=ROOT/'Source/data/pokemon.lua');p.add_argument('--output-root',type=Path,required=True);p.add_argument('--check',action='store_true');args=p.parse_args(argv)
    try:
        manifest=json.loads(MANIFEST.read_text());assert manifest['schema']==1,'unsupported manifest'
        out=args.output_root.resolve()
        if not args.check and (out==ROOT or out.is_relative_to(ROOT/'Source')):raise DataError('explicit staged output required')
        species=projection(args.pokemon_source.read_text())
        if [species[n] for n in range(1,152)]!=manifest['species']:raise DataError('species mapping drift')
        entries=parse(read_pins(args.reference_root,manifest),species)
        for path,text in outputs(entries).items():
            destination=out/'Source'/path
            if args.check:
                if destination.read_text()!=text:raise DataError('generated data drift: '+path)
            else:destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(text)
        print('151 original entries and ASCII default names verified');return 0
    except (OSError,ValueError,KeyError,AssertionError) as error:print('pokedex generation failed: '+str(error),file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
