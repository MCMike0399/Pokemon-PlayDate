import importlib.util,json,tempfile,unittest
from pathlib import Path
SPEC=importlib.util.spec_from_file_location('profile_motion',Path(__file__).resolve().parents[1]/'harness/profile_motion.py')
m=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(m)

class MotionProfileTests(unittest.TestCase):
    def write(self,path):
        path.parent.mkdir(parents=True,exist_ok=True)
        rows=[{'tick':tick,'time_ms':time,'snapshot':{'root':'overworld','world_motion':{'paused':False,'live':{'actors':[{'phase':'moving'}]}},'performance':{'heap_kib':100+tick}}}for tick,time in [(1,10),(2,43),(3,76)]]
        path.write_text(''.join(json.dumps(row)+'\n'for row in rows))
    def test_normal_runtime_data_trace_is_used(self):
        with tempfile.TemporaryDirectory()as root:
            root=Path(root);self.write(root/'runtime-data/trace.jsonl');report=m.profile(root)
            self.assertEqual(len(report['traces']),1);self.assertEqual(report['traces'][0]['active_intervals'],2)
            self.assertEqual(report['traces'][0]['interval_ms']['median'],33)
            self.assertEqual(report['traces'][0]['heap_kib'],{'first':101,'last':103,'min':101,'max':103})
    def test_per_process_trace_wins_over_duplicate_runtime_archive(self):
        with tempfile.TemporaryDirectory()as root:
            root=Path(root)
            for path in ['processes/0001/trace.jsonl','processes/0002/trace.jsonl','runtime-data/trace.jsonl','processes/0001/runtime-data/trace.jsonl']:self.write(root/path)
            report=m.profile(root);self.assertEqual(len(report['traces']),2)
            self.assertTrue(all('runtime-data'not in item['trace']for item in report['traces']))
    def test_no_trace_fails_explicitly(self):
        with tempfile.TemporaryDirectory()as root:
            with self.assertRaisesRegex(ValueError,'no completed runtime traces'):m.profile(root)

if __name__=='__main__':unittest.main()
