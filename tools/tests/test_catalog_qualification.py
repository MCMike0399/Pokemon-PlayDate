import importlib
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import tools.harness
STAGE=Path(__file__).resolve().parents[2]
tools.harness.__path__.insert(0,str(STAGE/'tools/harness'))
from tools.harness import catalog_qualification as q
from tools.harness.protocol import ProtocolError,atomic_json


class CatalogTests(unittest.TestCase):
    def fixture(self, root):
        from PIL import Image
        output=Path(root)/'output';output.mkdir();data=Path(root)/'data';data.mkdir()
        identity={'protocol':1,'build_id':'build','session_id':'session'}
        (output/'Source/dev').mkdir(parents=True);(output/'Source'/q.FEATURE).write_text('feature marker')
        atomic_json(output/'build.json',dict(identity,source_sha256='source',compiled_source_sha256='compiled',sdk_version='3.1.2'))
        atomic_json(output/'run.json',dict(identity,simulator_pid=1234))
        atomic_json(output/'00001-request.json',dict(identity,id='00001-request',commands=['contracts']))
        atomic_json(output/'00001-result.json',dict(identity,id='00001-request',results=[{'op':'contracts','command':1,'contracts':{'ok':True,'suites':[{'id':q.SUITE,'ok':True,'passed':7,'failed':0,'artifact_qualifier':q.QUALIFIER}]}}]))
        expected={name:dict(path=name,width=2,height=2,category='test',mask=name=='mask.png')for name in ('image.png','mask.png')}
        for phase in q.PHASES:
            folder=output/'frames'/('catalog-invariance-'+phase);folder.mkdir(parents=True)
            for name in expected:Image.new('RGBA',(2,2),(255,255,255,255)).save(folder/name)
            atomic_json(data/('catalog-invariance-'+phase+'.json'),{'schema':1,'images':list(expected.values()),'missing':[],'image_root':'.','metadata':{'source':'pin'}})
        return output,data,identity,expected
    def qualify(self,output,data,identity,expected):
        with patch.object(q,'COUNT',2),patch.object(q,'expected_inventory',return_value=expected):
            return q.finalize(output,data,output,identity)
    def test_complete_proof_publishes_identity_and_native_archives(self):
        with tempfile.TemporaryDirectory()as root:
            output,data,identity,expected=self.fixture(root);report=self.qualify(output,data,identity,expected)
            self.assertTrue(report['ok']);self.assertEqual(report['actual_pngs'],4);self.assertEqual(report['checked_pairs'],2)
            self.assertEqual(report['process_pid'],1234);self.assertEqual(report['executions'][0]['request_id'],'00001-request')
            self.assertTrue((output/'catalog-invariance-native/catalog-invariance-before.json').is_file())
    def test_qualified_execution_records_exact_request_and_result_hashes(self):
        with tempfile.TemporaryDirectory()as root:
            output,data,identity,expected=self.fixture(root)
            request=output/'00001-request.json';result=output/'00001-result.json'
            expected_request=hashlib.sha256(request.read_bytes()).hexdigest()
            expected_result=hashlib.sha256(result.read_bytes()).hexdigest()
            report=self.qualify(output,data,identity,expected);execution=report['executions'][0]
            self.assertEqual(execution['request_sha256'],expected_request)
            self.assertEqual(execution['result_sha256'],expected_result)
            self.assertNotEqual(execution['request_sha256'],execution['result_sha256'])
            request.write_text(request.read_text()+'\n')
            self.assertNotEqual(execution['request_sha256'],hashlib.sha256(request.read_bytes()).hexdigest())

    def test_missing_manifest_png_and_corrupt_png_fail(self):
        for fault in ('manifest','png','corrupt'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory()as root:
                output,data,identity,expected=self.fixture(root)
                if fault=='manifest':(data/'catalog-invariance-after.json').unlink()
                elif fault=='png':(output/'frames/catalog-invariance-after/image.png').unlink()
                else:(output/'frames/catalog-invariance-after/image.png').write_bytes(b'not PNG')
                with self.assertRaises(ProtocolError):self.qualify(output,data,identity,expected)
                self.assertFalse(json.loads((output/'catalog-invariance-qualification.json').read_text())['ok'])
    def test_hidden_rgb_and_alpha_drift_fail_exactly(self):
        from PIL import Image
        for fault in ('rgb','hidden-rgb','alpha'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory()as root:
                output,data,identity,expected=self.fixture(root)
                before=Image.new('RGBA',(2,2),(255,255,255,0 if fault=='hidden-rgb'else 255))
                after=before.copy();after.putpixel((0,0),(0,0,0,0 if fault in ('hidden-rgb','alpha')else 255))
                before.save(output/'frames/catalog-invariance-before/image.png');after.save(output/'frames/catalog-invariance-after/image.png')
                with self.assertRaisesRegex(ProtocolError,'pixel drift'):self.qualify(output,data,identity,expected)
    def test_manifest_duplicate_dimensions_mask_metadata_unknown_and_missing_reject(self):
        for fault in ('duplicate','dimensions','mask','unknown','missing'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory()as root:
                output,data,identity,expected=self.fixture(root);path=data/'catalog-invariance-after.json';packet=json.loads(path.read_text())
                if fault=='duplicate':packet['images'][1]=packet['images'][0]
                elif fault=='dimensions':packet['images'][0]['width']=3
                elif fault=='mask':packet['images'][0]['mask']=True
                elif fault=='unknown':packet['images'][0]['path']='../escape.png'
                else:packet['images'].pop()
                atomic_json(path,packet)
                with self.assertRaises(ProtocolError):self.qualify(output,data,identity,expected)
    def test_wrong_png_size_and_invalid_standalone_mask_reject(self):
        from PIL import Image
        for fault in ('dimensions','mask'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory()as root:
                output,data,identity,expected=self.fixture(root)
                target=output/'frames/catalog-invariance-after'/('image.png'if fault=='dimensions'else'mask.png')
                Image.new('RGBA',(3,2)if fault=='dimensions'else(2,2),(127,127,127,255)).save(target)
                with self.assertRaises(ProtocolError):self.qualify(output,data,identity,expected)
    def test_stale_archives_do_not_count_and_numbered_repeat_fails(self):
        with tempfile.TemporaryDirectory()as root:
            output,data,identity,expected=self.fixture(root)
            shutil.copyfile(output/'00001-result.json',output/'stale-result.json')
            self.assertTrue(self.qualify(output,data,identity,expected)['ok'])
            shutil.copyfile(output/'00001-result.json',output/'00002-result.json');shutil.copyfile(output/'00001-request.json',output/'00002-request.json')
            with self.assertRaisesRegex(ProtocolError,'exactly one'):self.qualify(output,data,identity,expected)
    def test_missing_suite_metadata_failed_suite_wrong_identity_fail(self):
        for fault in ('metadata','failed','wrong-build','wrong-request','wrong-qualifier','missing-suite'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory()as root:
                output,data,identity,expected=self.fixture(root);path=output/'00001-result.json';packet=json.loads(path.read_text());report=packet['results'][0]['contracts']
                if fault=='metadata':del report['suites']
                elif fault=='failed':report['suites'][0]['ok']=False
                elif fault=='wrong-build':packet['build_id']='wrong'
                elif fault=='wrong-request':packet['id']='wrong'
                elif fault=='wrong-qualifier':report['suites'][0]['artifact_qualifier']='wrong'
                else:report['suites']=[]
                atomic_json(path,packet)
                with self.assertRaises(ProtocolError):self.qualify(output,data,identity,expected)
    def test_nonvisual_old_build_and_functional_jobs_never_import_pillow(self):
        with tempfile.TemporaryDirectory()as root,patch.object(q,'image_dependencies',side_effect=AssertionError('unexpected image import')):
            root=Path(root);self.assertIsNone(q.finalize(root,root,root,{}));q.prepare(root,{'commands':['contracts']},launching=True)
            (root/'Source/dev').mkdir(parents=True);(root/'Source'/q.FEATURE).write_text('feature')
            q.prepare(root,{'commands':['snapshot']},launching=True)
            self.assertIsNone(q.finalize(root,root,root,{'build_id':'build','session_id':'session'}))
    def test_noncontract_fault_archive_does_not_request_visual_qualification(self):
        with tempfile.TemporaryDirectory()as root,patch.object(q,'image_dependencies',side_effect=AssertionError('unexpected image import')):
            root=Path(root);(root/'Source/dev').mkdir(parents=True);(root/'Source'/q.FEATURE).write_text('feature')
            atomic_json(root/'00001-request.json',{'commands':['snapshot']})
            atomic_json(root/'00001-result.json',{'build_id':'deliberate-protocol-fault'})
            self.assertIsNone(q.finalize(root,root,root,{'build_id':'build','session_id':'session'}))

    def test_process_archive_preserves_pair_evidence_and_clears_only_owned_manifests(self):
        from tools.harness import restarting
        from tools.harness.protocol import OwnerLock
        with tempfile.TemporaryDirectory()as root:
            output,data,identity,expected=self.fixture(root);evidence=output/'processes/0001';evidence.mkdir(parents=True)
            self.qualify(output,data,identity,expected)
            # Exercise actual owner archival helpers, without a runtime process.
            (data/'save.json').write_text('durable save')
            with OwnerLock(data/'owner.lock')as owner:
                restarting.archive_generation(data,output,evidence,0)
                self.assertTrue((evidence/'frames/catalog-invariance-before/image.png').is_file())
                restarting.clear_handshake(data,owner)
                self.assertEqual((data/'save.json').read_text(),'durable save')
                self.assertFalse((data/'catalog-invariance-before.json').exists())
                q.prepare(output)
                self.assertEqual(list((output/'frames/catalog-invariance-before').iterdir()),[])

    def test_preflight_visual_dependencies_and_stale_artifacts(self):
        with tempfile.TemporaryDirectory()as root:
            root=Path(root);(root/'Source/dev').mkdir(parents=True);(root/'Source'/q.FEATURE).write_text('feature')
            with patch.object(q,'image_dependencies',side_effect=ProtocolError('Pillow missing')):
                with self.assertRaisesRegex(ProtocolError,'Pillow'):q.prepare(root,{'processes':[{'requests':[['contracts']]}]},launching=True)
                q.prepare(root,{'commands':['snapshot']},launching=True)
            (root/'frames/catalog-invariance-before/old.png').write_bytes(b'stale')
            with self.assertRaisesRegex(ProtocolError,'stale'):q.prepare(root)
    def test_source_inventory_is_independently_859_exact_paths(self):
        project=Path.cwd();source=Path(os.environ.get('CATALOG_FEATURE_SOURCE',project/'Source'))
        protected=source/'dev/catalogProtected.json'
        if not protected.is_file():self.skipTest('set CATALOG_FEATURE_SOURCE to reviewed staged feature Source')
        with tempfile.TemporaryDirectory()as root:
            root=Path(root);(root/'dev').mkdir();(root/'dev/catalogProtected.json').write_bytes(protected.read_bytes())
            (root/'data').mkdir();shutil.copytree(project/'Source/data/pewterSlice',root/'data/pewterSlice')
            expected=q.expected_inventory(root)
            self.assertEqual(len(expected),859)
            self.assertEqual((expected['pewter-Route2-terrain.png']['width'],expected['pewter-Route2-terrain.png']['height']),(640,2304))
            self.assertEqual(len([name for name in expected if name.startswith('pewter-pose-')]),600)
            self.assertEqual(len([name for name in expected if name.startswith('pewter-sprite-')]),64)

if __name__=='__main__':unittest.main()
