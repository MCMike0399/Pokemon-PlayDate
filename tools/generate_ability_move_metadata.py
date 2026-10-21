#!/usr/bin/env python3
"""Project pinned Showdown Gen5 contact/secondary/OHKO metadata; no runtime code execution."""
import argparse,hashlib,json,re,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REV='9b136a8c8cdb860a8ab96fa063f906604e352547'
FILES={'data/moves.ts':'61ab107dae9628d79ac61da16c72e8565f6a1211874298e00c77c5c0ac9755a7','data/mods/gen8/moves.ts':'d75a2e25ce019c8619a71bd271ebb3521d8ed54b33540a0961f67320f5231f2e','data/mods/gen7/moves.ts':'d043fc23b4a812ba8734d3520c8f4d7ee629b42b24d005382a447b050db9f8bc','data/mods/gen6/moves.ts':'2253b9dd1ed8cde982cb5e4c5057a75f6fdebba2053af27c7fe61769979b8adb','data/mods/gen5/moves.ts':'b7f2146ad3b81a5f17a05fdb87bc3fb9b19e891ac2a44ec8f7b4ca94252e8010'}
# This is a data-field reader, not a TS evaluator/transpiler. Only exact,
# literal top-level fields used by this projection are accepted.
def entries(text):return dict(re.findall(r'^\t(\w+): \{\n(.*?)^\t\},',text,re.M|re.S))
def project(texts,keys):
 result={k:{} for k in keys}
 for text in texts:
  for ident,body in entries(text).items():
   if ident not in result:continue
   r=result[ident]
   f=re.search(r'^\t\tflags: \{([^}]*)\}',body,re.M)
   if f:r['contact']=bool(re.search(r'\bcontact:\s*1\b',f[1]))
   for field in ['secondary','secondaries']:
    f=re.search(r'^\t\t'+field+r':\s*([^\n]+)',body,re.M)
    if f:r['secondary']=not f[1].startswith(('null','undefined','false'))
   immunity=re.search(r'^\t\tignoreImmunity:\s*(true|false)\b',body,re.M)
   if immunity:r['typeImmunity']=immunity[1]=='false'
   f=re.search(r'^\t\tohko:\s*([^,\n]+)',body,re.M)
   if f:r['ohko']=f[1] not in ['false','null']
 for r in result.values():
  r.setdefault('contact',False);r.setdefault('secondary',False);r.setdefault('ohko',False);r.setdefault('typeImmunity',False)
 return result

def generate(cache,moves,fetch=False):
 texts=[]
 for name,sha in FILES.items():
  p=cache/name.replace('/','_')
  if not p.exists() and fetch:
   raw=urllib.request.urlopen('https://raw.githubusercontent.com/smogon/pokemon-showdown/'+REV+'/'+name,timeout=30).read()
   if hashlib.sha256(raw).hexdigest()!=sha:raise ValueError('source checksum: '+name)
   p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
  raw=p.read_bytes()
  if hashlib.sha256(raw).hexdigest()!=sha:raise ValueError('source checksum: '+name)
  texts.append(raw.decode())
 keys=re.findall(r'^    (\w+) = Move',moves.read_text(),re.M)
 names={k:({'viceGrip':'visegrip'}.get(k) or k.lower()) for k in keys};rows=project(texts,set(names.values()))
 # Every projected ID must exist in the actual primary base registry.
 missing=set(names.values())-set(entries(texts[0]))
 if missing:raise ValueError('unknown primary move IDs: '+','.join(sorted(missing)))
 return {'schema':1,'revision':REV,'source_sha256':FILES,'moves':{k:rows[v] for k,v in names.items()}}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cache',type=Path,required=True);p.add_argument('--moves',type=Path,default=ROOT/'Source/battle/moves.lua');p.add_argument('--output',type=Path,required=True);p.add_argument('--fetch',action='store_true');p.add_argument('--check',action='store_true');a=p.parse_args()
 result=json.dumps(generate(a.cache,a.moves,a.fetch),indent=2)+'\n'
 if a.check:
  if a.output.read_text()!=result:raise ValueError('metadata drift')
 else:a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(result)
if __name__=='__main__':main()
