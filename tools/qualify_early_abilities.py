#!/usr/bin/env python3
"""Verify pinned primary metadata, independent literals and exact regeneration."""
import argparse,hashlib,importlib.util,json,re,sys,tempfile,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-root',type=Path,default=ROOT);p.add_argument('--mechanics-cache',type=Path,required=True);p.add_argument('--showdown-cache',type=Path,required=True);p.add_argument('--csv-cache',type=Path,required=True);p.add_argument('--report',type=Path,required=True);p.add_argument('--fetch',action='store_true');a=p.parse_args()
 pins=json.loads((ROOT/'tools/references/early-abilities-sources.json').read_text())['files']
 for name,row in pins.items():
  file=a.mechanics_cache/name
  if not file.exists() and a.fetch:
   raw=urllib.request.urlopen(row['url'],timeout=30).read()
   if hashlib.sha256(raw).hexdigest()!=row['sha256']:raise ValueError('primary checksum '+name)
   file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(raw)
  if hashlib.sha256(file.read_bytes()).hexdigest()!=row['sha256']:raise ValueError('primary checksum '+name+'; cache preserved')
 meta=module('ability_meta' ,ROOT/'tools/generate_ability_move_metadata.py');gen=module('ability_gen',ROOT/'tools/generate_gen5_data.py')
 observed=meta.generate(a.showdown_cache,a.source_root/'Source/battle/moves.lua',a.fetch);declared=json.loads((ROOT/'tools/references/ability-move-metadata.json').read_text());assert observed==declared,'primary metadata projection drift'
 literals={'struggle':(True,False,False),'petalDance':(True,False,False),'earthquake':(False,False,False),'poisonSting':(False,True,False),'thunderWave':(False,False,False),'growl':(False,False,False),'confuseRay':(False,False,False),'rapidSpin':(True,False,False),'ancientPower':(False,True,False),'flameCharge':(True,True,False),'triAttack':(False,True,False),'fissure':(False,False,True),'hornDrill':(True,False,True),'guillotine':(True,False,True),'sheerCold':(False,False,True)}
 for key,expected in literals.items():
  r=declared['moves'][key];assert tuple(r[k] for k in ('contact','secondary','ohko'))==expected,('literal semantic vector',key,r,expected)
 sys.path.insert(0,str(a.source_root));from tools.verify_moves.fetch_pokeapi import PinnedSources
 inputs=PinnedSources(a.csv_cache,a.fetch);data={'moves':inputs.load('moves_pre_sv.csv'),'move_changelog':inputs.load('move_changelog_pre_sv.csv')}
 for name in ('move_meta','move_meta_stat_changes','types'):data[name]=inputs.load(name+'.csv')
 with tempfile.TemporaryDirectory() as directory:
  gen.MOVES_INPUT=str(a.source_root/'Source/battle/moves.lua');gen.MOVES_LUA=str(Path(directory)/'moves.lua');gen.generate_moves(data,True)
  assert Path(gen.MOVES_LUA).read_bytes()==Path(gen.MOVES_INPUT).read_bytes(),'generated move bytes drift'
 report={'ok':True,'move_count':len(declared['moves']),'literal_semantic_vectors':len(literals),'showdown_primary_files':len(meta.FILES),'csv_primary_files':5,'exact_regeneration':True,'mechanics_primary_files':len(pins)}
 a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
