import argparse,hashlib,json,re
from pathlib import Path
args=argparse.ArgumentParser(description="Audit connected Pallet-Brock both-normal ability scope")
args.add_argument('--source-root',type=Path,required=True);args.add_argument('--mechanics-cache',type=Path,required=True);args.add_argument('--output',type=Path,required=True);config=args.parse_args()
ROOT=config.source_root;OUT=config.output.parent
personal=(config.mechanics_cache/'personal_b2w2').read_bytes()
assert hashlib.sha256(personal).hexdigest()=='6df24e7f00dab32322d9d8f8b3209d30de1c89b0de88277081fe53434211830f','primary personal checksum'
pins={}
def read(rel):
 p=ROOT/rel;b=p.read_bytes();pins[rel]=hashlib.sha256(b).hexdigest();return b.decode()
pokemon=read('Source/data/pokemon.lua')
rows=[{'dex':int(d),'species':s,'normal_ability_ids':list(personal[int(d)*76+24:int(d)*76+26])} for s,d in re.findall(r'^    (\w+) = \{\n        name = "[^\"]+", dex = (\d+)',pokemon,re.M)]
assert len(rows)==151
names=dict((int(i),n) for i,n in re.findall(r'\[(\d+)\] = "([^\"]+)"',read('Source/data/specimenData.lua')))
for r in rows:r['ability_names']=[names[i] for i in r['normal_ability_ids']]
by={r['species']:r for r in rows}
seeds={s:['starter-choice'] for s in ['bulbasaur','charmander','squirtle']}
for rel in ['Source/data/viridianSlice/Route1.json','Source/data/pewterSlice/Route2.json','Source/data/pewterSlice/ViridianForest.json']:
 d=json.loads(read(rel))
 for s in d['encounters']['grass']['slots']:seeds.setdefault(s['species'],[]).append(rel)
for t in json.loads(read('Source/data/pewterSlice/trainers.json'))['trainers']:
 for s in t['party']:seeds.setdefault(s['species'],[]).append(t['id'])
# Explicitly scoped authored Pallet block; debug test_zone excluded.
pallet=read('Source/data/maps.lua').split('registerZone("pallet_town"',1)[1].split('registerZone(',1)[0]
for s in re.findall(r'\{\s*species\s*=\s*"([^"]+)"',pallet):seeds.setdefault(s,[]).append('authored:pallet_town')
evo=read('Source/data/evolutionData.lua');graph={}
for line in evo.splitlines():
 m=re.match(r'\s+(\w+) = (.*)',line)
 if m:graph[m[1]]=[{'to':a,'trigger':b} for a,b in re.findall(r'to = "(\w+)".*?trigger = "(\w+)"',m[2])]
closure=set(seeds);edges=[]
for species in list(seeds):
 queue=[species]
 while queue:
  s=queue.pop()
  for e in graph.get(s,[]):
   if e['to'] not in closure:closure.add(e['to']);queue.append(e['to'])
   entry={'from':s,**e}
   if entry not in edges:edges.append(entry)
selected=[];abilities={}
for s in sorted(closure,key=lambda s:by[s]['dex']):
 r=by[s]; selected.append({'dex':r['dex'],'species':s,'normal_slots':r['normal_ability_ids'],'direct_sources':sorted(set(seeds.get(s,[])))})
 for i,n in zip(r['normal_ability_ids'],r['ability_names']):abilities.setdefault(i,{'id':i,'name':n,'species':[]})['species'].append(s)
for a in abilities.values():a['species']=list(dict.fromkeys(a['species']))
read('Source/data/specimenData.lua')
d={'schema':1,'purpose':'proposal scope, not implementation acceptance','direct_species':len(seeds),'closure_species':len(closure),'normal_abilities':len(abilities),'all151_union':111,'remaining_union_outside_slice':111-len(abilities),'species':selected,'evolution_edges':edges,'abilities':sorted(abilities.values(),key=lambda a:a['id']),'source_sha256':pins,'availability_notes':['Raichu stone dependency is not a pre-Brock Thunder Stone availability claim.','Golem trade-hook dependency is not trading availability.','Enemy-only Geodude/Onix/Diglett/Sandshrew are not capture availability claims.','No hidden-slot acquisition or debug test_zone included.']}
assert (len(seeds),len(closure),len(abilities))==(14,30,16),(len(seeds),len(closure),len(abilities))
config.output.parent.mkdir(parents=True,exist_ok=True)
config.output.write_text(json.dumps(d,indent=2)+'\n')
print(json.dumps({'direct':len(seeds),'closure':len(closure),'abilities':[(a['id'],a['name']) for a in d['abilities']]}))
