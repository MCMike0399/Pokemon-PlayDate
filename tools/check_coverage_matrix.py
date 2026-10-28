"""Read-only current matrix validation; no count-as-playability shortcut."""
import argparse,hashlib,json,re,sys
from pathlib import Path
sys.dont_write_bytecode=True
FACETS=('campaign_path','regional_fidelity','full_mechanics')
IMPLEMENTATIONS={'indexed','partial','integrated','not_applicable'}
VERIFICATIONS={'unreviewed','unrun','source_only','host','sdk_scoped','native_scoped','accepted_milestone'}

def validate(data,project,check_current=True):
 project=Path(project);sys.path.insert(0,str(project))
 from tools.harness.run import fingerprint
 from tools.verify_moves.parse_lua import read_moves,read_table
 assert data['schema_version']==1
 if check_current:assert fingerprint(project)==data['snapshot']['source_sha256'],'matrix stale: Source fingerprint differs; regenerate/review, never relabel evidence'
 assert data['schedule']['layers_independent']is True and data['schedule']['all_grind_rows_retained']is True
 allowed_row={'id','kind','title','owner','dependencies','due_milestone','source','campaign_path','regional_fidelity','full_mechanics','notes','staged','capabilities'}
 rows=data['rows'];assert all(set(row)<=allowed_row for row in rows),'unknown row field'
 ids={r['id']for r in rows};assert len(ids)==len(rows),'duplicate row id'
 for row in rows:
  assert row['owner']in data['owners'],'unknown owner'
  assert set(row['due_milestone'])==set(FACETS)
  assert all(m in data['milestones']for m in row['due_milestone'].values()),'unknown due milestone'
  assert set(row['dependencies'])<=ids,'missing dependency'
  for key in FACETS:
   f=row[key];assert set(f)=={'implementation','verification','evidence','notes'},'facet shape'
   assert f['implementation']in IMPLEMENTATIONS and f['verification']in VERIFICATIONS,'facet state'
   assert f['evidence']and set(f['evidence'])<=set(data['evidence']),'unknown evidence'
   if f['verification']=='accepted_milestone':
    assert row['id']in data.get('accepted_milestone_rows',[]),'no explicit current milestone acceptance'
    assert all(data['evidence'][e]['kind']not in('historical','private_verified','source','production')for e in f['evidence']),'private/source/history cannot qualify main milestone'
 # Dependencies are acceptance requirements, not bidirectional map connections.
 done=set();active=set();by={r['id']:r for r in rows}
 def visit(id):
  assert id not in active,'dependency cycle'
  if id in done:return
  active.add(id)
  for dep in by[id]['dependencies']:visit(dep)
  active.remove(id);done.add(id)
 for id in ids:visit(id)
 for id,proof in data['evidence'].items():
  path=Path(proof['path']);assert not path.is_absolute()and'..'not in path.parts,'unsafe evidence path'
  actual=project/path;assert actual.is_file(),'missing evidence file: '+id
  assert re.fullmatch(r'[0-9a-f]{64}',proof['sha256']),'invalid evidence hash: '+id
  if 'historical_source_commit' in proof:
   # Frozen declarations describe their old candidate, not each later Source tree.
   assert path.parts[0]=='Source' and proof['kind']in('production','source') and re.fullmatch(r'[0-9a-f]{40}',proof['historical_source_commit']),'invalid historical declaration'
  else:
   assert hashlib.sha256(actual.read_bytes()).hexdigest()==proof['sha256'],'evidence file changed: '+id
 inventory=json.loads((project/'tools/references/kanto-inventory.json').read_text())
 assert {r['source']['constant']for r in rows if r['kind']=='map_slot'}=={m['constant']for m in inventory['maps']},'map inventory differs'
 assert {r['title']for r in rows if r['kind']=='audio_source'}=={m['path']for m in inventory['audio_files']},'audio inventory differs'
 moves=read_moves(project/'Source/battle/moves.lua')
 runtime_moves=set(re.findall(r'^moveData\.(\w+)\s*=\s*Move\{', (project/'Source/data/fieldMoveBattleData.lua').read_text(),re.M))
 assert not set(moves)&runtime_moves,'duplicate runtime move'
 assert {r['source']['canonical_key']for r in rows if r['kind']=='move'}==set(moves)|runtime_moves,'move inventory differs'
 items=set(read_table(project/'Source/data/items.lua','ItemData')['definitions'])
 items.update(re.findall(r'^ItemData\.definitions\.(\w+)\s*=\s*\{',(project/'Source/data/lightBall.lua').read_text(),re.M))
 pickup_items=set(re.findall(r'^ItemData\.definitions\.(\w+)\s*=\s*\{',(project/'Source/data/pickupData.lua').read_text(),re.M))
 assert not set(items)&pickup_items,'duplicate Pickup item'
 assert {r['source']['canonical_key']for r in rows if r['kind']=='item'}==set(items)|pickup_items,'item inventory differs'
 for key in('protect','solarBeam','skullBash','bide'):
  row=by['move:'+key];assert row['full_mechanics']['implementation']=='integrated'and row['full_mechanics']['verification']=='sdk_scoped','stale false-missing handler claim'
 assert by['move:mirrorMove']['full_mechanics']['verification']=='source_only'
 assert data['snapshot']['source_sha256']!=data['staged_source_snapshots'][0]['source_sha256'],'current/historical snapshots conflated'
 return {'ok':True,'rows':len(rows),'map_slots':len(inventory['maps']),'audio_sources':len(inventory['audio_files']),'moves':len(moves)+len(runtime_moves),'generated_moves':len(moves),'runtime_moves':len(runtime_moves),'items':len(items)+len(pickup_items),'pickup_items':len(pickup_items),'no_completion_claim':True}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--project',type=Path,required=True);p.add_argument('--matrix',type=Path,required=True);a=p.parse_args();print(json.dumps(validate(json.loads(a.matrix.read_text()),a.project)))
if __name__=='__main__':main()
