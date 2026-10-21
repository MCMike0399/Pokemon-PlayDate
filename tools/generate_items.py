#!/usr/bin/env python3
"""Generate Blue bag catalog, original symbolic mappings and mart stock.

--output is explicit; --check never writes it. Immutable pins are checked before
parsing; unused IDs, badge/floor pseudo-items and mode-only resources are not
accepted bag definitions. This generator does not implement their effects.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/item-sources.json'
EXCLUDED={'SURFBOARD':'unused','SAFARI_BALL':'safari-mode-resource','POKEDEX':'dex-device-not-bag',
 'BOULDERBADGE':'badge-not-bag','CASCADEBADGE':'badge-not-bag','THUNDERBADGE':'badge-not-bag',
 'RAINBOWBADGE':'badge-not-bag','SOULBADGE':'badge-not-bag','MARSHBADGE':'badge-not-bag',
 'VOLCANOBADGE':'badge-not-bag','EARTHBADGE':'badge-not-bag','ITEM_2C':'unused','ITEM_32':'unused-duplicate-pp-up','COIN':'game-corner-resource'}
HEAL={'POTION':20,'SUPER_POTION':50,'HYPER_POTION':200,'FRESH_WATER':50,'SODA_POP':60,'LEMONADE':80}
DISPLAY_NAMES={"POKE_BALL":("POKé BALL","POKE BALL"),"POKE_DOLL":("POKé DOLL","POKE DOLL"),"POKE_FLUTE":("POKé FLUTE","POKE FLUTE")}
CURES={'ANTIDOTE':'poison','BURN_HEAL':'burn','ICE_HEAL':'freeze','AWAKENING':'sleep','PARLYZ_HEAL':'paralyze'}

class GenerationError(ValueError):pass

def load(cache,fetch=False,manifest=None):
    manifest=manifest or json.loads(MANIFEST.read_text());out={}
    for name,spec in manifest['files'].items():
        path=Path(cache)/name
        if path.exists():raw=path.read_bytes()
        elif fetch:
            try:
                with urllib.request.urlopen(spec['url'],timeout=45) as response:raw=response.read()
            except OSError as error:raise GenerationError(f'fetch failed {name}: {error}') from error
        else:raise GenerationError(f'missing pinned input {path}; use --fetch')
        if hashlib.sha256(raw).hexdigest()!=spec['sha256']:raise GenerationError(f'checksum mismatch {name}; cache preserved')
        out[name]=raw.decode('utf-8')
        if not path.exists():path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    return out

def camel(symbol):
    if symbol in {'S_S_TICKET','ELIXER','MAX_ELIXER'}:return {'S_S_TICKET':'ssTicket','ELIXER':'elixir','MAX_ELIXER':'maxElixir'}[symbol]
    head,*rest=symbol.lower().split('_');return head+''.join(word.capitalize() for word in rest)

def medicines(raw):
    # Cross-check Gen V values against a primary implementation's explicit
    # pre-generation7 branch; no modern item rebalance leaks into this catalog.
    settings=raw['001_Settings.rb'];effects=raw['002_Item_Effects.rb']
    if not re.search(r'REBALANCED_HEALING_ITEM_AMOUNTS\s*=\s*\(MECHANICS_GENERATION >= 7\)',settings):
        raise GenerationError('unsupported medicine generation boundary')
    out={}
    for symbol,expected in HEAL.items():
        token=symbol.replace('_','')
        found=re.search(r'UseOnPokemon.add\(:'+token+r',.*?\n\}\)',effects,re.S)
        if not found:raise GenerationError(f'missing Gen V medicine handler {symbol}')
        block=found[0]
        amount=re.search(r'\?\s*\d+\s*:\s*(\d+)',block) or re.search(r'pbHPItem\(pkmn,\s*(\d+)',block)
        if not amount or int(amount[1])!=expected:raise GenerationError(f'Gen V medicine value disagreement {symbol}')
        out[symbol]={'effect':'heal','amount':expected}
    out['MAX_POTION']={'effect':'heal','amount':'all'}
    out['FULL_RESTORE']={'effect':'fullRestore'}
    out['FULL_HEAL']={'effect':'cure','status':'all'}
    for symbol,status in CURES.items():out[symbol]={'effect':'cure','status':status}
    out['REVIVE']={'effect':'revive','amount':'half'};out['MAX_REVIVE']={'effect':'revive','amount':'all'}
    for symbol,all_moves,amount in [('ETHER',False,10),('MAX_ETHER',False,'all'),('ELIXER',True,10),('MAX_ELIXER',True,'all')]:
        out[symbol]={'effect':'pp','allMoves':all_moves,'amount':amount}
    return out

def collect(raw):
    constants=raw['constants/item_constants.asm'];ordinary=constants.split('DEF NUM_ITEMS')[0]
    ids={};n=0
    for symbol in re.findall(r'^\s*const\s+(\w+)',ordinary,re.M):
        if symbol in ids:raise GenerationError('duplicate symbolic ID')
        ids[symbol]=n;n+=1
    if n!=84 or ids.get('MAX_ELIXER')!=83:raise GenerationError('unsupported ordinary item ID layout')
    prices={symbol:int(value) for value,symbol in re.findall(r'^\s*bcd3\s+(\d+)\s*;\s*(\w+)',raw['data/items/prices.asm'],re.M)}
    flags={symbol:value=='TRUE' for value,symbol in re.findall(r'^\s*dbit\s+(TRUE|FALSE)\s*;\s*(\w+)',raw['data/items/key_items.asm'],re.M)}
    names=re.findall(r'^\s*li "([^"]+)"',raw['data/items/names.asm'],re.M)[:83]
    if len(names)!=83 or len(flags)!=83:raise GenerationError('incomplete names/key flags')
    effects=medicines(raw);items={};symbols={}
    for symbol,numeric in ids.items():
        if symbol=='NO_ITEM' or symbol in EXCLUDED:continue
        if symbol not in prices or symbol not in flags:raise GenerationError(f'missing price/flag {symbol}')
        identity=camel(symbol)
        if identity in items:raise GenerationError('duplicate canonical ID')
        entry={'id':identity,'symbol':symbol,'numericId':numeric,'name':names[numeric-1],
               'keyItem':flags[symbol],'price':prices[symbol],'category':'key' if flags[symbol] else 'item','effect':'unsupported'}
        if symbol in DISPLAY_NAMES:
            original,display=DISPLAY_NAMES[symbol]
            if entry['name']!=original:raise GenerationError('original display name changed: '+symbol)
            entry['sourceName']=entry['name'];entry['name']=display
        elif not entry['name'].isascii():raise GenerationError('unreviewed non-ASCII display name: '+symbol)
        if symbol in effects:entry.update(effects[symbol]);entry['category']='medicine'
        if symbol.endswith('_BALL'):entry['category']='ball'
        entry['sellPrice']=entry['price']//2 if not entry['keyItem'] else None
        items[identity]=entry;symbols[symbol]=identity
    tm_prices=[int(x)*1000 for x in re.findall(r'^\s*nybble\s+(\d+)\s*;',raw['data/items/tm_prices.asm'],re.M)]
    machines=[]
    for kind,start in [('hm',196),('tm',201)]:
        tokens=re.findall(r'^\s*add_'+kind+r'\s+(\w+)',constants,re.M)
        if len(tokens)!=(5 if kind=='hm' else 50):raise GenerationError('incomplete TM/HM catalog')
        for index,move in enumerate(tokens,1):
            identity=f'{kind}{index:02}';symbol=f'{kind.upper()}_{move}'
            price=0 if kind=='hm' else tm_prices[index-1]
            items[identity]={'id':identity,'symbol':symbol,'numericId':start+index-1,'name':identity.upper(),
                'keyItem':kind=='hm','price':price,'sellPrice':price//2 if kind=='tm' else None,
                'category':kind,'effect':'unsupported','moveSymbol':move}
            symbols[symbol]=identity;symbols[identity.upper()]=identity;machines.append(identity)
    marts={}
    for label,stock in re.findall(r'^(\w+)::[^\n]*\n\s*script_mart\s+([^\n]+)',raw['data/items/marts.asm'],re.M):
        if label.startswith('Unused'):continue
        # Keep the primary source label as stable key rather than invent a map alias.
        key=label[0].lower()+label[1:]
        tokens=[x.strip() for x in stock.split(',')]
        if any(token not in symbols for token in tokens):raise GenerationError(f'unknown mart item {label}')
        marts[key]=[symbols[token] for token in tokens]
    if len(marts)!=14:raise GenerationError('incomplete referenced Blue mart catalog')
    return items,symbols,marts

def lua(value):
    if isinstance(value,bool):return 'true' if value else 'false'
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if value is None:return 'nil'
    if isinstance(value,int):return str(value)
    if isinstance(value,list):return '{ '+', '.join(lua(x) for x in value)+' }'
    if isinstance(value,dict):return '{ '+', '.join('['+lua(k)+'] = '+lua(v) for k,v in value.items())+' }'
    raise GenerationError('unserializable catalog value')

def render(raw):
    items,symbols,marts=collect(raw)
    lines=['-- Generated by tools/generate_items.py; pinned Blue economy / Gen V medicines.',
           '-- Unsupported effects are explicit; excluded pseudo/unused IDs are not bag definitions.', 'ItemData = {','    definitions = {']
    for key,item in sorted(items.items(),key=lambda kv:kv[1]['numericId']):lines.append('        '+key+' = '+lua(item)+',')
    lines+=['    },','    bySymbol = '+lua(symbols)+',','    marts = {']
    for key,stock in marts.items():lines.append('        '+key+' = '+lua(stock)+',')
    lines+=['    },','    excluded = '+lua(EXCLUDED)+',','}', '']
    return '\n'.join(lines)

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cache',type=Path,required=True);p.add_argument('--fetch',action='store_true');p.add_argument('--output',type=Path,required=True);p.add_argument('--check',action='store_true');args=p.parse_args(argv)
    try:
        result=render(load(args.cache,args.fetch))
        if args.check:
            if not args.output.exists() or args.output.read_text()!=result:raise GenerationError('generated item catalog drift')
        else:args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(result)
        print('Blue item catalog verified/generated');return 0
    except (OSError,ValueError,KeyError,IndexError) as error:print(f'item generation failed: {error}',file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
