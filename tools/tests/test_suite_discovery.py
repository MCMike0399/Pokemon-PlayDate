import contextlib,io,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools.harness import suite
from tools.harness.protocol import ProtocolError

BROCK_CASES={'brock--'+name for name in ('brock-natural','brock-restart','source-trainer-1','source-trainer-2','source-trainer-3','source-trainer-4','source-trainer-5','tm-full-retry','blackout','failed-sight')}

class DiscoveryTests(unittest.TestCase):
    def test_all_ten_actual_brock_cases_are_listed_selected_and_identified(self):
        jobs=suite.available_jobs();names=[j['name']for j in jobs]
        self.assertTrue(BROCK_CASES<=set(names));self.assertEqual(len(names),len(set(names)))
        selected=suite.select_jobs([','.join(sorted(BROCK_CASES,reverse=True))])
        self.assertEqual([j['name']for j in selected],sorted(BROCK_CASES,reverse=True))
        self.assertTrue(all(j['scenario'].parent==suite.PROJECT/'tools/harness/scenarios/brock'for j in selected))
        with patch.object(sys,'argv',['suite.py','--list']),contextlib.redirect_stdout(io.StringIO())as output:self.assertEqual(suite.main(),0)
        listed=output.getvalue().splitlines();self.assertEqual(listed,names);self.assertTrue(BROCK_CASES<=set(listed))
    def test_recursive_qualified_names_are_deterministic_and_basename_duplicates_distinct(self):
        with tempfile.TemporaryDirectory()as folder:
            root=Path(folder);cases=root/'tools/harness/scenarios'
            for name in ['z.json','other/a.json','a/z.json','a/a.json']:
                path=cases/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('{}')
            with patch.object(suite,'PROJECT',root):
                expected=['smoke','contracts-catalog','qualification','a--a','a--z','other--a','z']
                self.assertEqual([j['name']for j in suite.available_jobs()],expected)
                self.assertEqual([j['name']for j in suite.available_jobs()],expected)
    def test_flattening_builtin_and_optional_mutation_collisions_fail_closed(self):
        for files,mutations in [(['a--b.json','a/b.json'],False),(['qualification.json'],False),(['mutations.json'],True)]:
            with self.subTest(files=files),tempfile.TemporaryDirectory()as folder:
                root=Path(folder)
                for name in files:
                    path=root/'tools/harness/scenarios'/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('{}')
                with patch.object(suite,'PROJECT',root),self.assertRaisesRegex(ProtocolError,'duplicate suite case name'):
                    suite.select_jobs(mutations=mutations)
    def test_plan_copies_each_required_nested_case_to_flat_immutable_input_without_launch(self):
        with tempfile.TemporaryDirectory()as folder:
            import argparse
            args=argparse.Namespace(output=str(Path(folder)/'plan'),only=sorted(BROCK_CASES),mutations=False,plan_only=True,continue_on_failure=False,job_timeout=1,sdk=None)
            def forbidden(*args):self.fail('discovery plan launched a process')
            self.assertEqual(suite.execute_suite(args,launch=forbidden),0)
            report=json.loads((Path(args.output)/'suite.json').read_text())
            self.assertEqual(report['requested'],sorted(BROCK_CASES));self.assertFalse(report['ok']);self.assertFalse(report['complete'])
            self.assertEqual({p.stem for p in (Path(args.output)/'inputs').glob('*.json')},BROCK_CASES)

if __name__=='__main__':unittest.main()
