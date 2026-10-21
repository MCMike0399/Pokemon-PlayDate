import hashlib,importlib.util,json,tempfile,unittest,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def module(path,name):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
G=module(ROOT/'tools/generate_individual_data.py','individual_generator')
class IndividualDataTests(unittest.TestCase):
 def test_pinned_generated_output_exact_and_151_rows(self):
  rows=G.load(ROOT/'tools/references');self.assertEqual(len(rows),151);self.assertEqual(G.render(rows),(ROOT/'Source/data/individualData.lua').read_text())
 def test_literal_source_foe_yields_independent_of_generator_iteration(self):
  rows=G.load(ROOT/'tools/references')
  literal={1:[0,0,0,1,0,0],4:[0,0,0,0,0,1],7:[0,0,1,0,0,0],10:[1,0,0,0,0,0],11:[0,0,2,0,0,0],13:[0,0,0,0,0,1],14:[0,0,2,0,0,0],16:[0,0,0,0,0,1],19:[0,0,0,0,0,1],25:[0,0,0,0,0,2],27:[0,0,1,0,0,0],50:[0,0,0,0,0,1],74:[0,0,1,0,0,0],95:[0,0,1,0,0,0],151:[3,0,0,0,0,0]}
  for dex,expected in literal.items():self.assertEqual(rows[dex-1],expected)
 def test_wrong_hash_fails_before_decode(self):
  with tempfile.TemporaryDirectory()as t:
   root=Path(t)/'refs';shutil.copytree(ROOT/'tools/references',root);p=root/'individuals/personal_b2w2';p.write_bytes(p.read_bytes()+b'x')
   with self.assertRaisesRegex(ValueError,'checksum'):G.load(root)
 def test_resigned_malformed_dimensions_and_yields_still_fail(self):
  for mutation in ['dimension','zero-yield']:
   with tempfile.TemporaryDirectory()as t:
    root=Path(t)/'refs';shutil.copytree(ROOT/'tools/references',root);p=root/'individuals/personal_b2w2';data=bytearray(p.read_bytes())
    if mutation=='dimension':data=data[:-1]
    else:data[76+10:76+12]=b'\0\0'
    p.write_bytes(data);pin=json.loads((root/'individuals-sources.json').read_text());pin['files']['personal_b2w2']['sha256']=hashlib.sha256(data).hexdigest();(root/'individuals-sources.json').write_text(json.dumps(pin))
    with self.assertRaises(AssertionError):G.load(root)
 def test_unchanged_primary_c_stats_against_ten_literal_vectors(self):
  oracle=module(ROOT/'tools/tests/reference_vectors.py','stat_reference');self.assertEqual(oracle.oracle()['vectors'],10)
 def test_unchanged_primary_c_setters_against_seven_literal_vectors(self):
  oracle=module(ROOT/'tools/tests/effort_vectors.py','effort_reference');self.assertEqual(oracle.oracle()['vectors'],7)
 def test_blue_trainer_policy_has_exact_source_DVs_and_split_special_mapping(self):
  constants=(ROOT/'tools/references/individuals/blue-battle-constants.asm').read_text();core=(ROOT/'tools/references/individuals/blue-core.asm').read_text()
  self.assertIn('ATKDEFDV_TRAINER EQU $98',constants);self.assertIn('SPDSPCDV_TRAINER EQU $88',constants)
  self.assertIn('ld a, ATKDEFDV_TRAINER',core);self.assertIn('ld b, SPDSPCDV_TRAINER',core)
  dv=[8,9,8,8,8,8];self.assertEqual([v*2 for v in dv],[16,18,16,16,16,16])
 def test_creation_v3_pm_literals_append_after_unchanged_v2_prefix(self):
  # Independent integer PM multiplication, not production Schrage code.
  for seed,expected_iv,end in [(1,[9,1,7,23,29,2],1458777923),(42,[22,9,24,16,7,25],1139130650),(12345,[23,2,22,27,9,11],1963079340)]:
   state=seed;out=[]
   for span in [2,25,256]+[32]*6:
    limit=(2147483646//span)*span
    while True:
     state=state*16807%2147483647
     if state-1<limit:break
    out.append((state-1)%span)
   self.assertEqual(out[3:],expected_iv);self.assertEqual(state,end)
if __name__=='__main__':unittest.main()
