"""Wholegoal indexing/layer/dependency/current-source checks; no gameplay mock."""
import copy,json,unittest
from pathlib import Path
from tools.check_coverage_matrix import validate
from tools.verify_moves.parse_lua import ROOT
class CurrentMatrixTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.data=json.loads((ROOT/'docs/validation/coverage-current.json').read_text())
 def test_complete_source_indices_without_completion_promotion(self):
  result=validate(self.data,ROOT);self.assertEqual(result['rows'],1512);self.assertEqual(result['map_slots'],248);self.assertEqual(result['moves'],430);self.assertEqual(result['generated_moves'],425);self.assertEqual(result['runtime_moves'],5);self.assertEqual(result['items'],131);self.assertEqual(result['pickup_items'],6);self.assertEqual(result['audio_sources'],375)
  self.assertEqual(self.data['accepted_milestone_rows'],[])
 def test_layer_mutants_and_unknown_evidence_rejected(self):
  for change in('evidence','acceptance','due','unknown'):
   d=copy.deepcopy(self.data);row=next(r for r in d['rows']if r['id']=='system:release')
   if change=='evidence':row['full_mechanics']['evidence']=['invented-proof']
   elif change=='acceptance':row['campaign_path']['verification']='accepted_milestone'
   elif change=='due':row['due_milestone']['campaign_path']='done'
   else:row['complete_everything']=True
   with self.assertRaises(AssertionError):validate(d,ROOT)
 def test_dependency_missing_cycle_and_inventory_deletion_rejected(self):
  for change in('missing','cycle','map','move','runtime_move','pickup_item'):
   d=copy.deepcopy(self.data)
   if change=='missing':d['rows'][0]['dependencies'].append('invented-owner')
   elif change=='cycle':d['rows'][0]['dependencies'].append(d['rows'][0]['id'])
   elif change=='map':d['rows']=[r for r in d['rows']if r['id']!='map:ROUTE_22']
   else:
    removed={'move':'move:mirrorMove','runtime_move':'move:fly','pickup_item':'item:heartScale'}[change]
    d['rows']=[r for r in d['rows']if r['id']!=removed]
   with self.assertRaises(AssertionError):validate(d,ROOT)
 def test_old_false_missing_private_conflation_and_stale_source_rejected(self):
  for change in('protect','private','snapshot'):
   d=copy.deepcopy(self.data)
   if change=='protect':next(r for r in d['rows']if r['id']=='move:protect')['full_mechanics']['implementation']='indexed'
   elif change=='private':d['staged_source_snapshots'][0]['source_sha256']=d['snapshot']['source_sha256']
   else:d['snapshot']['source_sha256']='0'*64
   with self.assertRaises(AssertionError):validate(d,ROOT)
if __name__=='__main__':unittest.main()
