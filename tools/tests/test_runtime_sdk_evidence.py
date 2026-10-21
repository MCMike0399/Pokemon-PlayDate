"""Actual SDK evidence mutations; no simulated SDK execution."""
import copy,hashlib,json,shutil,tempfile,unittest
from pathlib import Path
from tools.verify_moves.parse_lua import ROOT,read_moves
from tools.verify_moves.fetch_pokeapi import SourceError
from tools.verify_moves.runtime_coverage import load_runtime_coverage
class RuntimeSDKEvidenceTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.moves=read_moves()
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.p=Path(self.tmp.name)
  (self.p/'Source').symlink_to(ROOT/'Source',target_is_directory=True)
  self.registry=json.loads((ROOT/'tools/references/runtime-move-coverage.json').read_text())
  for name in (self.registry['accepted_summary']['path'],self.registry['sdk_result']['path']):
   dest=self.p/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest)
  self.raw=json.loads((self.p/self.registry['sdk_result']['path']).read_text())
 def load(self):
  f=self.p/'registry.json';f.write_text(json.dumps(self.registry));return load_runtime_coverage(self.p,self.moves,f)
 def repin(self):
  f=self.p/self.registry['sdk_result']['path'];f.write_text(json.dumps(self.raw));digest=hashlib.sha256(f.read_bytes()).hexdigest();self.registry['sdk_result']['sha256']=digest;self.registry['sdk_result_sha256']=digest
 def reject(self):
  with self.assertRaises(SourceError):self.load()
 def test_current_actual_result_binds48_records(self):
  result=self.load();self.assertEqual(len(result),48);self.assertEqual(result['protect']['state'],'verified_subset');self.assertEqual(result['protect']['evidence']['sdk_build_id'],self.raw['build_id'])
 def test_private1059_separate(self):
  result=load_runtime_coverage(ROOT,self.moves,ROOT/'tools/references/runtime-move-coverage-private1059.json');self.assertEqual(set(result),{'bide'});self.assertEqual(result['bide']['evidence']['acceptance_context'],'private-root-verified-not-main')
 def test_unpinned_byte_change(self):
  f=self.p/self.registry['sdk_result']['path'];f.write_bytes(f.read_bytes()+b' ');self.reject()
 def test_fake_embedded_ok_cannot_override_actual_failed_case(self):
  name=self.registry['moves']['protect']['tests'][0]['accepted_name'];next(t for t in self.raw['results'][0]['contracts']['tests']if t['name']==name)['ok']=False;self.repin();self.reject()
 def test_nonexistent_canonical_name(self):
  proof=self.registry['moves']['protect']['tests'][0];proof['accepted_name']='invented: '+proof['name'];proof['executed']={'name':proof['accepted_name'],'ok':True};self.reject()
 def test_wrong_source_even_rehashed_and_build_repin(self):
  self.raw['build_id']=self.raw['build_id'].rsplit(':',1)[0]+':'+'0'*64;self.registry['sdk_result']['build_id']=self.raw['build_id'];self.repin();self.reject()
 def test_wrong_build(self):
  self.raw['build_id']='other:'+self.registry['accepted_summary']['source_sha256'];self.repin();self.reject()
 def test_duplicate_reports(self):
  self.raw['results'].append(copy.deepcopy(self.raw['results'][0]));self.repin();self.reject()
 def test_missing_report(self):
  self.raw['results']=[];self.repin();self.reject()
 def test_incomplete_tests_or_suites(self):
  for field in ('tests','suites'):
   with self.subTest(field=field):
    original=copy.deepcopy(self.raw);self.raw['results'][0]['contracts'][field].pop();self.repin();self.reject();self.raw=original
 def test_duplicate_actual_name(self):
  tests=self.raw['results'][0]['contracts']['tests'];tests[1]['name']=tests[0]['name'];self.repin();self.reject()
 def test_result_returned_failure(self):
  self.raw['results'][0]['status']='error';self.repin();self.reject()
 def test_embedded_false_even_actual_passed(self):
  self.registry['moves']['protect']['tests'][0]['executed']['ok']=False;self.reject()
 def test_unsafe_paths(self):
  original=self.registry['sdk_result']['path']
  for path in ('../outside.json','/tmp/outside.json'):
   self.registry['sdk_result']['path']=path;self.reject()
  (self.p/'outside').symlink_to(ROOT,target_is_directory=True);self.registry['sdk_result']['path']='outside/'+original;self.reject()
if __name__=='__main__':unittest.main()
