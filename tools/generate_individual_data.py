#!/usr/bin/env python3
"""Pinned B2W2 EV yields only. No writes without explicit output; no downloads."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ORDER=('hp','atk','def','spa','spd','spe')
def load(reference):
 pin=json.loads((reference/'individuals-sources.json').read_text());files={}
 for name,entry in pin['files'].items():
  data=(reference/'individuals'/name).read_bytes()
  if hashlib.sha256(data).hexdigest()!=entry['sha256']:raise ValueError('source checksum: '+name)
  files[name]=data
 raw=files['personal_b2w2'];assert len(raw)%76==0 and len(raw)>=152*76,'malformed personal dimensions'
 rows=[]
 for dex in range(1,152):
  record=raw[dex*76:(dex+1)*76];packed=int.from_bytes(record[10:12],'little')
  row=[(packed>>shift)&3 for shift in (0,2,4,8,10,6)]
  assert 1<=sum(row)<=3,'invalid six-stat yield'
  rows.append(row)
 return rows

def render(rows):
 assert len(rows)==151
 return '-- GENERATED pinned B2W2 EV yields. Order hp,atk,def,spa,spd,spe. No acquisition producer.\nIndividualData={version=1,yields={\n'+''.join('    ['+str(i)+']={'+','.join(map(str,row))+'},\n'for i,row in enumerate(rows,1))+'}}\n'
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference',type=Path,default=ROOT/'tools/references');p.add_argument('--output',type=Path);p.add_argument('--check',type=Path);a=p.parse_args()
 if bool(a.output)==bool(a.check):p.error('provide exactly one --output or --check')
 text=render(load(a.reference))
 if a.check:
  if a.check.read_text()!=text:raise SystemExit('individual data drift')
 else:a.output.write_text(text)
if __name__=='__main__':main()
