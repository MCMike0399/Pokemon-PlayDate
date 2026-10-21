import hashlib,importlib.util,json,unittest
from pathlib import Path
P=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('native_rewards_reference',P/'rewards_reference.py');reference=importlib.util.module_from_spec(spec);spec.loader.exec_module(reference)
class RewardsReferenceTests(unittest.TestCase):
 def test_all_pinned_primary_bytes_and_blob_ids(self):
  root=P.parent/'references';pin=json.loads((root/'rewards-sources.json').read_text())
  for name,item in pin['files'].items():
   data=(root/'rewards'/name).read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),item['sha256']);self.assertEqual(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),item['git_blob_sha1'])
 def test_unchanged_native_add_evs_and_six_setters_match_seven_literals(self):self.assertEqual(reference.oracle()['vectors'],7)
 def test_source_all_eligible_ev_allocation_precedes_server_xp_application(self):
  # This is source call-chain evidence, not an oracle for runtime equivalence.
  root=P.parent/'references/rewards';sub=(root/'btl_server_flow_sub.c').read_text();give=(root/'btl_server_flow.c').read_text()
  allocation=reference.function(sub,'AddExpAndEVs');application=reference.function(give,'ServerControl_GiveExp')
  self.assertIn('if (entries[i].exp != 0)',allocation);self.assertIn('AddEVs(BattleParty_GetMon(party, i), defeated, &entries[i])',allocation)
  self.assertNotIn(' < 100',allocation);self.assertIn(' < 100',application)
 def test_source_return_and_level_refresh_are_explicit_distinct_native_sites(self):
  text=(P.parent/'references/rewards/btl_pokeparam.c').read_text()
  self.assertIn('PokeParty_RecalcStats(mon->core.src)',reference.function(text,'BattleMon_AddExp'))
  self.assertIn('PokeParty_RecalcStats(src)',reference.function(text,'BattleMon_WriteToSrc'))
if __name__=='__main__':unittest.main()
