#!/usr/bin/env python3
"""Pinned actual Gen5 evolution graph, restricted to original151 endpoints."""
import argparse,csv,hashlib,io,json,re,struct,sys,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/evolution.json'
class DataError(ValueError):pass
def digest(raw):return hashlib.sha256(raw).hexdigest()
def sources(cache,manifest,fetch=False):
    cache=Path(cache);out={}
    for name,entry in manifest['inputs'].items():
        path=cache/name
        if not path.exists() and fetch:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(urllib.request.urlopen(entry['url'],timeout=30).read())
        raw=path.read_bytes()
        if digest(raw)!=entry['sha256']:raise DataError('source checksum mismatch: '+name)
        out[name]=raw
    return out

def unpack(data):
    if len(data)<8 or data[:2]!=b'g5':raise DataError('invalid Gen5 container')
    count=struct.unpack_from('<H',data,2)[0]
    if count!=650 or len(data)<4+2*(count+1):raise DataError('invalid Gen5 container count')
    offsets=struct.unpack_from('<'+'H'*(count+1),data,4)
    if offsets[0]!=4+2*(count+1) or offsets[-1]!=len(data) or any(a>b for a,b in zip(offsets,offsets[1:])):raise DataError('invalid container offsets')
    graph={}
    for species,(start,end) in enumerate(zip(offsets,offsets[1:])):
        if (end-start)%8:raise DataError('invalid evolution record size')
        graph[species]=[]
        for offset in range(start,end,8):
            method,padding,arg,target,form,level=struct.unpack_from('<BBHHBB',data,offset)
            if padding!=0 or not 1<=target<=649:raise DataError('invalid Gen5 method target')
            graph[species].append((method,arg,target,form,level))
    return graph

def collect(raw,manifest):
    species={i+1:key for i,key in enumerate(manifest['species'])}
    if len(species)!=151 or len(set(species.values()))!=151:raise DataError('invalid original species mapping')
    items={int(row['id']):row['identifier'] for row in csv.DictReader(io.StringIO(raw['items.csv'].decode()))}
    expected={81:'moon-stone',82:'fire-stone',83:'thunder-stone',84:'water-stone',85:'leaf-stone'}
    if any(items.get(i)!=name for i,name in expected.items()):raise DataError('Gen5 stone ID mapping drift')
    stones={i:re.sub(r'-([a-z])',lambda m:m[1].upper(),name) for i,name in expected.items()}
    graph=unpack(raw['evos_g5.pkl']);result={};excluded=[];counts={4:0,5:0,8:0}
    for dex in range(1,152):
        rules=[]
        for method,arg,target,form,level in graph[dex]:
            if target>151:excluded.append({'from':dex,'to':target,'method':method});continue
            if form!=255 or method not in (4,5,8):raise DataError('unexpected original graph dependency')
            rule={'to':species[target],'targetDex':target,'method':method}
            if method==4:
                if not 1<=arg<=100 or arg!=level:raise DataError('invalid level method')
                rule.update(trigger='level',minimum=arg)
            elif method==8:
                if arg not in stones or level!=0:raise DataError('unsupported stone method')
                rule.update(trigger='stone',item=stones[arg])
            else:
                if arg!=0 or level!=0:raise DataError('unsupported trade dependency')
                rule.update(trigger='trade')
            rules.append(rule);counts[method]+=1
        result[species[dex]]=rules
    if counts!={4:52,5:4,8:16}:raise DataError('original graph count drift: '+str(counts))
    return result,excluded

def lua(value):
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,int):return str(value)
    if isinstance(value,list):return '{'+', '.join(lua(v) for v in value)+'}'
    return '{'+', '.join(key+' = '+lua(v) for key,v in value.items())+'}'
def render(rules):
    lines=['-- Generated actual Gen5 graph, original151 endpoints; tools/references/evolution.json.','EvolutionData = {schema=1, rules={']
    lines += ['    '+species+' = '+lua(values)+',' for species,values in rules.items()]
    return '\n'.join(lines+['}}',''])
def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cache',type=Path,required=True);p.add_argument('--fetch',action='store_true');p.add_argument('--output',type=Path,required=True);p.add_argument('--check',action='store_true');args=p.parse_args(argv)
    try:
        m=json.loads(MANIFEST.read_text())
        if m['schema']!=1:raise DataError('unsupported manifest')
        rules,_=collect(sources(args.cache,m,args.fetch),m);text=render(rules)
        if args.check:
            if args.output.read_text()!=text:raise DataError('generated evolution drift')
        else:
            if args.output.resolve().is_relative_to(ROOT/'Source'):raise DataError('generation requires staged output outside project Source')
            args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(text)
        print('72 Gen5 evolution edges verified:52level/16stone/4trade;151 species');return 0
    except (OSError,ValueError,KeyError) as error:print('evolution generation failed: '+str(error),file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
