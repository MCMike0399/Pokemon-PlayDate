"""Evidence refresh changes provenance, never invents mechanic qualification."""
import hashlib,json,unittest
from tools.verify_moves.parse_lua import ROOT
class Current1091RefreshTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.current=json.loads((ROOT/'tools/references/runtime-move-coverage-current1091.json').read_text())
  cls.old=json.loads((ROOT/'tools/references/runtime-move-coverage-main950.json').read_text())
 def test_all48_scopes_definitions_assertions_and_declared_states_retained(self):
  self.assertEqual(len(self.current['moves']),48);self.assertEqual(set(self.current['moves']),set(self.old['moves']))
  for key,old in self.old['moves'].items():
   for field in ('scope','state','capabilities','definition_sha256','tests'):
    self.assertEqual(self.current['moves'][key][field],old[field],(key,field))
 def test_only_two_actually_supported_owner_records_refreshed(self):
  changes={k for k in self.old['moves']if self.current['moves'][k]['owners']!=self.old['moves'][k]['owners']}
  self.assertEqual(changes,{'bide','sweetScent'})
  private=json.loads((ROOT/'tools/references/runtime-move-coverage-private1059.json').read_text())
  self.assertEqual(self.current['moves']['bide']['owners'],private['moves']['bide']['owners'])
 def test_original1091_registry_bytes_preserved(self):
  self.assertEqual(hashlib.sha256((ROOT/'tools/references/runtime-move-coverage-current1091.json').read_bytes()).hexdigest(),'b7784032fcf26f93d5e6abfb85385daf9b66c3c32c71125781474e7ecb5fb62e')
 def test_historical_unverified_declarations_are_preserved(self):
  # Static history: current Source drift is checked by test_candidate1250_refresh.
  gaps={'dig','earthquake','explosion','furyCutter','gyroBall','heavySlam','magnitude','selfDestruct','smackDown'}
  for key in gaps:self.assertEqual(self.current['moves'][key]['state'],'source_gap')
  self.assertEqual(self.current['moves']['helpingHand']['state'],'source_only')
 def test_exact1091_identity_and_historical950_1059_preserved(self):
  self.assertEqual(self.current['accepted_summary']['source_sha256'],'44bd25bac9b1968cc8691eedc05ecd104faf708796602a492f997dccd1ae9ddc')
  self.assertEqual(self.current['sdk_result']['passed'],1091);self.assertEqual(self.current['sdk_result']['failed'],0)
  self.assertEqual(self.current['acceptance_context'],'integrated-root-candidate1091-not-yet-main')
  self.assertEqual(self.old['sdk_result']['passed'],950)
  private=json.loads((ROOT/'tools/references/runtime-move-coverage-private1059.json').read_text());self.assertEqual(private['sdk_result']['passed'],1059)
 def test_matrix_candidate_sdk_not_campaign_or_future_content_acceptance(self):
  d=json.loads((ROOT/'docs/validation/coverage-current.json').read_text());rows={r['id']:r for r in d['rows']}
  self.assertEqual(d['snapshot']['acceptance_context'],'private-foundation-candidate-not-main-or-milestone');self.assertEqual(d['accepted_milestone_rows'],[])
  for key in ('system:current-reward-correctness','system:safe-newgame-recovery'):
   self.assertEqual(rows[key]['campaign_path']['implementation'],'integrated');self.assertEqual(rows[key]['campaign_path']['verification'],'sdk_scoped')
  for key in ('system:natural-all3-freeze','map:ROUTE_22','move:mirrorMove'):
   self.assertNotEqual(rows[key]['campaign_path']['verification'],'accepted_milestone')
if __name__=='__main__':unittest.main()
