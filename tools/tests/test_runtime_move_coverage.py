"""Report claims require meaningful current owner/assertion bytes, not fields."""
import copy,json,shutil,tempfile,unittest
from pathlib import Path
from tools.verify_moves.compare import Oracle,semantics_inventory
from tools.verify_moves.fetch_pokeapi import PinnedSources,SourceError
from tools.verify_moves.parse_lua import ROOT,read_moves
from tools.verify_moves.runtime_coverage import load_runtime_coverage
class RuntimeCoverageTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.moves=read_moves();cls.oracle=Oracle(PinnedSources().all());cls.registry=ROOT/'tools/references/runtime-move-coverage.json'
 def inventory(self,moves=None,context=None):
  moves=moves or self.moves
  if context is None:context=load_runtime_coverage(ROOT,moves)
  return{r['move']:r for r in semantics_inventory(moves,self.oracle,context)}
 def project(self):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);p=Path(tmp.name)
  for directory in('Source','docs'):shutil.copytree(ROOT/directory,p/directory)
  return p
 def test_current_owners_fix_actual_false_missing_with_scope_limits(self):
  inv=self.inventory()
  for key in('protect','solarBeam','skullBash','slash','razorLeaf','stormThrow','bide'):
   self.assertEqual(inv[key]['status'],'implemented-scoped-runtime-evidence',key);self.assertIn('scope_limit',inv[key]);self.assertTrue(inv[key]['runtime_coverage']['evidence']['tests'])
  self.assertEqual(inv['razorWind']['status'],'special-semantics-review-required') # critical proof does not implement charge
  self.assertEqual(inv['helpingHand']['status'],'runtime-evidence-stale') # current hasType query has no direct HelpingHand proof
  self.assertEqual(inv['dig']['status'],'runtime-evidence-stale') # declared source_gap retained; changed unverified owner is not requalified
 def test_field_presence_without_owner_evidence_never_promotes(self):
  rows=copy.deepcopy(self.moves);rows['gyroBall']['powerRule']='gyroBall'
  inv=self.inventory(rows,{});self.assertNotEqual(inv['gyroBall']['status'],'implemented-scoped-runtime-evidence')
  self.assertEqual(inv['solarBeam']['status'],'special-semantics-review-required')
 def test_missing_move_metadata_makes_reviewed_claim_stale_not_missing(self):
  rows=copy.deepcopy(self.moves);del rows['solarBeam']['chargeRule'];self.assertEqual(self.inventory(rows)['solarBeam']['status'],'runtime-evidence-stale')
  rows=copy.deepcopy(self.moves);rows['slash']['critStage']=0;self.assertEqual(self.inventory(rows)['slash']['status'],'runtime-evidence-stale')
 def test_changed_meaningful_owner_is_stale(self):
  p=self.project();f=p/'Source/battle/conditions.lua';s=f.read_text();self.assertIn('function BattleConditions:protect()',s);f.write_text(s.replace('function BattleConditions:protect()','function BattleConditions:protect()\n    error("controlled report mutant")',1))
  context=load_runtime_coverage(p,self.moves,self.registry);self.assertEqual(context['protect']['state'],'stale');self.assertEqual(context['solarBeam']['state'],'verified_subset')
 def test_unrelated_battle_edits_do_not_make_unchanged_owners_missing(self):
  p=self.project();f=p/'Source/battle/battle.lua';f.write_text(f.read_text()+'\n-- unrelated reward-report mutation outside reviewed guard/charge/crit bodies\n')
  context=load_runtime_coverage(p,self.moves,self.registry)
  for key in('protect','solarBeam','skullBash','slash','bide'):self.assertEqual(context[key]['state'],'verified_subset',key)
 def test_changed_assertion_body_is_stale_even_when_test_name_matches(self):
  p=self.project();f=p/'Source/dev/bideContracts.lua';s=f.read_text();needle='eq(b.player.pp.bide,9)';self.assertIn(needle,s);f.write_text(s.replace(needle,'eq(b.player.pp.bide,8)',1))
  self.assertEqual(load_runtime_coverage(p,self.moves,self.registry)['bide']['state'],'stale')
 def test_forged_or_missing_executed_evidence_fails_closed(self):
  data=json.loads(self.registry.read_text())
  for change in('failed','missing'):
   d=copy.deepcopy(data)
   if change=='failed':d['moves']['bide']['tests'][0]['executed']['ok']=False
   else:d['moves']['bide']['tests']=[]
   with tempfile.TemporaryDirectory()as tmp:
    f=Path(tmp)/'bad.json';f.write_text(json.dumps(d))
    with self.assertRaises(SourceError):load_runtime_coverage(ROOT,self.moves,f)
 def test_private_proof_stays_explicitly_private(self):
  d=json.loads((ROOT/'tools/references/runtime-move-coverage-private1059.json').read_text());self.assertEqual(d['acceptance_context'],'private-root-verified-not-main');self.assertEqual(d['accepted_summary']['sdk_passed'],1059);self.assertEqual(set(d['moves']),{'bide'})
if __name__=='__main__':unittest.main()
