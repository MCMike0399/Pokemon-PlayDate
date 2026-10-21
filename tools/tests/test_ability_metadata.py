"""Offline deterministic metadata/schema tests; full pinned projection is separate."""
import importlib.util,json,tempfile,unittest,hashlib
from pathlib import Path
P=Path(__file__).resolve().parents[1]/'generate_ability_move_metadata.py'
spec=importlib.util.spec_from_file_location('ability_metadata',P);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MetadataTests(unittest.TestCase):
 def test_multiline_flags_are_contact_and_not_category_inference(self):
  text='\tx: {\n\t\tcategory: "Special",\n\t\tflags: {\n\t\t\tcontact: 1, protect: 1,\n\t\t},\n\t},'
  self.assertTrue(m.project([text],{'x'})['x']['contact'])
 def test_primary_chance_bearing_move_is_not_secondary(self):
  text='\tx: {\n\t\tonHit() { chance(30); },\n\t\tflags: {},\n\t},'
  self.assertFalse(m.project([text],{'x'})['x']['secondary'])
 def test_inheritance_replaces_flags_and_secondary_explicit_null(self):
  base='\tx: {\n\t\tflags: {contact: 1},\n\t\tsecondary: {chance: 30},\n\t},'
  override='\tx: {\n\t\tinherit: true,\n\t\tflags: {protect: 1},\n\t\tsecondary: null,\n\t},'
  self.assertEqual(m.project([base,override],{'x'})['x'],{'contact':False,'secondary':False,'ohko':False,'typeImmunity':False})
 def test_ohko_string_and_boolean_are_explicit(self):
  self.assertTrue(m.project(['\tx: {\n\t\tohko: "Ice",\n\t},'],{'x'})['x']['ohko'])
  self.assertFalse(m.project(['\tx: {\n\t\tohko: false,\n\t},'],{'x'})['x']['ohko'])
 def test_explicit_primary_type_immunity_is_not_inferred_from_status_or_type(self):
  text='\tx: {\n\t\tcategory: "Status",\n\t\tignoreImmunity: false,\n\t},'
  self.assertTrue(m.project([text],{'x'})['x']['typeImmunity'])
  self.assertFalse(m.project(['\tx: {\n\t\tcategory: "Status",\n\t},'],{'x'})['x']['typeImmunity'])
 def test_corrupt_cache_fails_without_overwriting(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);p=root/'data_moves.ts';p.write_bytes(b'corrupt');moves=root/'moves.lua';moves.write_text('    x = Move{}')
   with self.assertRaisesRegex(ValueError,'checksum'):m.generate(root,moves)
   self.assertEqual(p.read_bytes(),b'corrupt')
 def test_missing_cache_fails_offline(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(FileNotFoundError):m.generate(Path(d),Path(d)/'moves.lua')
 def test_unknown_move_rejected_against_primary_registry(self):
  old=m.FILES
  try:
   raw=b'\tx: {\n\t\tflags: {},\n\t},'
   m.FILES={'fixture.ts':hashlib.sha256(raw).hexdigest()}
   with tempfile.TemporaryDirectory() as d:
    root=Path(d);(root/'fixture.ts').write_bytes(raw);moves=root/'moves.lua';moves.write_text('    unknown = Move{}')
    with self.assertRaisesRegex(ValueError,'unknown primary move'):m.generate(root,moves)
  finally:m.FILES=old
if __name__=='__main__':unittest.main()
