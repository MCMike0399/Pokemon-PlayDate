#!/usr/bin/env python3
"""Pinned B2W2 sex thresholds and one explicitly enabled ordinary held item."""
import argparse,csv,hashlib,io,json,re,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent
MANIFEST=HERE/'references/traits-sources.json'
def load(cache):
 out={}
 for name,pin in json.loads(MANIFEST.read_text())['files'].items():
  raw=(cache/name).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=pin['sha256']:raise ValueError('source checksum '+name)
  out[name]=raw
 return out
def rows(raw):return list(csv.DictReader(io.StringIO(raw.decode())))
def collect(raw,project):
 personal=raw['personal_b2w2'];schema=raw['PersonalInfo5B2W2.cs']
 if len(personal)%76 or len(personal)<152*76 or b'Data[0x12]'not in schema:raise ValueError('personal schema')
 species={s:int(d)for s,d in re.findall(r'^    (\w+) = \{\n        name = "[^\"]+", dex = (\d+)',(project/'Source/data/pokemon.lua').read_text(),re.M)}
 if len(species)!=151 or set(species.values())!=set(range(1,152)):raise ValueError('original151 inventory')
 genders={int(r['id']):int(r['gender_rate'])for r in rows(raw['pokemon_species.csv'])};expected={0:0,1:31,2:63,4:127,6:191,8:254,-1:255}
 result={}
 for key,dex in species.items():
  ratio=personal[dex*76+18]
  if ratio!=expected[genders[dex]]:raise ValueError('independent ratio mismatch '+key)
  result[key]={'dex':dex,'ratio':ratio,'held':list(struct.unpack_from('<HHH',personal,dex*76+12))}
 cross=[int(r['item_id'])for r in rows(raw['item_game_indices.csv'])if r['generation_id']=='5'and r['game_index']=='236']
 if cross!=[213]or not any(r['id']=='213'and r['identifier']=='light-ball'for r in rows(raw['items.csv'])):raise ValueError('Light Ball native/PokeAPI crosswalk')
 if result['pikachu']['held']!=[0,236,0]:raise ValueError('Pikachu ordinary held fields')
 source=raw['src_ov036_enc_pokeset.c'].decode()
 if not re.search(r'HELD_ITEM_RATES\[4\]\[3\].*?50\s*,\s*5\s*,\s*0',source,re.S):raise ValueError('ordinary rates')
 if not re.search(r'HELD_ITEM_RATES\[4\]\[3\].*?60\s*,\s*20\s*,\s*0',source,re.S):raise ValueError('Compound Eyes rates')
 return result
def render(data):
 out=['-- Generated pinned B2W2 data; no PID/history reconstruction.','SpecimenTraits={version=1,ratios={']
 for key,row in sorted(data.items(),key=lambda x:x[1]['dex']):out.append('    '+key+'='+str(row['ratio'])+',')
 out+=['},lightBall={gen5Id=236,pokeApiId=213,common=0,rare=236,third=0,ordinaryLow=50,ordinaryHigh=54,compoundLow=60,compoundHigh=79}}','-- Explicit extension; the protected original Blue49 whitelist stays intact.','assert(SpecimenData.holdable.lightBall==nil,"duplicate-Light-Ball-held-definition")','SpecimenData.holdable.lightBall=236','']
 return '\n'.join(out)
def item():return '''-- Explicit GenV acquisition extension; no Blue ID, price, shop or guessed resale.
assert(ItemData.definitions.lightBall==nil and ItemData.bySymbol.LIGHT_BALL==nil,"duplicate-Light-Ball-item-definition")
ItemData.definitions.lightBall={name="LIGHT BALL",sourceName="Light Ball",symbol="LIGHT_BALL",
    gen5Id=236,pokeApiId=213,keyItem=false,category="held",effect="unsupported"}
ItemData.bySymbol.LIGHT_BALL="lightBall"
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--project',type=Path,required=True);p.add_argument('--cache',type=Path,default=HERE/'references/traits');p.add_argument('--output',type=Path,required=True);p.add_argument('--check',action='store_true');a=p.parse_args();data=collect(load(a.cache),a.project)
 for name,text in [('specimenTraits.lua',render(data)),('lightBall.lua',item())]:
  path=a.output/'Source/data'/name
  if a.check:
   if path.read_text()!=text:raise ValueError('generated trait drift '+name)
  else:path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
 print('151 sex thresholds independently qualified; Light Ball native236/PokeAPI213; Pikachu ordinary5% / Compound Eyes20%')
if __name__=='__main__':main()
