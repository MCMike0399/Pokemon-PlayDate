"""Retain historical scope integrity without pinning later work to old candidates.

Current snapshot and evidence integrity belong to test_coverage_matrix. Historical
1091 byte hashes, owner deltas and private acceptance context were one-time audits.
"""
import json,unittest
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
if __name__=='__main__':unittest.main()
