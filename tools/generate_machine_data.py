#!/usr/bin/env python3
"""Pinned Blue TM/HM identities and all151 flags; no ROM/network/runtime writes."""
import argparse,hashlib,json,re
from pathlib import Path
REVISION='af519899719f0754965776faac0e836a3b906e6d'
PIN=Path(__file__).resolve().parent/'references/teaching-source-pin.json'
KEYS='megaPunch razorWind swordsDance whirlwind megaKick toxic hornDrill bodySlam takeDown doubleEdge bubbleBeam waterGun iceBeam blizzard hyperBeam payDay submission counter seismicToss rage megaDrain solarBeam dragonRage thunderbolt thunder earthquake fissure dig psychic teleport mimic doubleTeam reflect bide metronome selfDestruct eggBomb fireBlast swift skullBash softBoiled dreamEater skyAttack rest thunderWave psywave explosion rockSlide triAttack substitute cut fly surf strength flash'.split()

def generate(reference,pin=PIN):
    reference=Path(reference);pins=json.loads(Path(pin).read_text());consumed={}
    def read(relative):
        raw=(reference/relative).read_bytes();actual=hashlib.sha256(raw).hexdigest()
        if pins['files'].get(relative)!=actual:raise ValueError('source checksum drift: '+relative)
        consumed[relative]=actual;return raw.decode()
    item=read('constants/item_constants.asm');tm=re.findall(r'^\s*add_tm\s+([A-Z_]+)\s*;',item,re.M);hm=re.findall(r'^\s*add_hm\s+([A-Z_]+)\s*;',item,re.M)
    if len(tm)!=50 or len(hm)!=5 or len(set(tm+hm))!=55:raise ValueError('malformed machine identity inventory')
    symbols=tm+hm;move_symbols=re.findall(r'^\s*const\s+([A-Z0-9_]+)',read('constants/move_constants.asm'),re.M)
    dex=re.findall(r'^\s*const\s+(DEX_[A-Z0-9_]+)',read('constants/pokedex_constants.asm'),re.M)
    if len(dex)!=151:raise ValueError('malformed national dex inventory')
    machines=[{'id':('tm'if i<50 else'hm')+f'{i+1 if i<50 else i-49:02d}', 'number':i+1 if i<50 else i-49,'kind':'tm'if i<50 else'hm','source_symbol':symbol,'move_id':move_symbols.index(symbol),'move_key':KEYS[i],'item_id':201+i if i<50 else 196+i-50,'compatibility_bit':i,'consume_on_success':i<50}for i,symbol in enumerate(symbols)]
    includes=re.findall(r'^INCLUDE "(data/pokemon/base_stats/[^\"]+)"',read('data/pokemon/base_stats.asm'),re.M)
    mew=read('data/pokemon/mew.asm')
    if len(includes)!=150 or 'INCLUDE "data/pokemon/base_stats/mew.asm"'not in mew:raise ValueError('Mew separate-table seam changed')
    includes.append('data/pokemon/base_stats/mew.asm');read('macros/data.asm');read('data/moves/tmhm_moves.asm')
    rows=[]
    for path in includes:
        text=read(path);symbol=re.search(r'^\s*db\s+(DEX_[A-Z0-9_]+)',text,re.M).group(1);national=dex.index(symbol)+1
        section=text.split('; tm/hm learnset',1)[1].split('; end',1)[0]
        words=re.sub(r';[^\n]*','',section).replace('\\','').strip()
        if not words.startswith('tmhm'):raise ValueError('missing compatibility macro: '+path)
        tokens=[word.strip()for word in words[4:].split(',')if word.strip()]
        if len(tokens)!=len(set(tokens))or any(token not in symbols+['UNUSED']for token in tokens):raise ValueError('invalid compatibility symbol: '+path)
        bits=sum(1<<(55 if token=='UNUSED'else symbols.index(token))for token in tokens)
        species=Path(path).stem;species={'nidoranf':'nidoranF','nidoranm':'nidoranM','mrmime':'mr'}.get(species,species)
        rows.append({'dex':national,'species':species,'dex_symbol':symbol,'source':path,'bitmap_hex':bits.to_bytes(7,'little').hex(),'unused_bit_55':bool(bits>>55),'machines':[m['id']for i,m in enumerate(machines)if bits>>i&1]})
    if sorted(r['dex']for r in rows)!=list(range(1,152)):raise ValueError('missing or duplicate original species')
    return {'schema':1,'source_revision':REVISION,'policy':'Blue machine identity/compatibility/consumption; GenV move execution and broader level-ups','machines':machines,'species':sorted(rows,key=lambda r:r['dex']),'consumed_inputs':consumed}

def render(data):
    lines=['-- Blue machine identity/compatibility from pokered '+data['source_revision']+'.','-- Generated from pinned original source; GenV move execution remains separate.','MachineData={','    definitions={']
    for row in data['machines']:
        lines.append('        '+row['id']+'={move="'+row['move_key']+'",consume='+str(row['consume_on_success']).lower()+'},')
    lines+=['    },','    compatibility={']
    for row in data['species']:
        lines.append('        '+row['species']+'={'+','.join(key+'=true'for key in row['machines'])+'},')
    return '\n'.join(lines+['    },','}'])+'\n'

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args(argv)
    try:
        generated=render(generate(args.reference))
        if args.check:
            if args.output.read_text()!=generated:raise ValueError('generated machine data drift')
        else:
            project=Path(__file__).resolve().parents[1]
            if args.output.resolve().is_relative_to(project/'Source'):raise ValueError('write an explicit temporary candidate outside project Source')
            args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(generated)
    except Exception as error:
        import sys
        print(str(error),file=sys.stderr);return 1
    return 0
if __name__=='__main__':raise SystemExit(main())
