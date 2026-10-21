import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image, ImageDraw
from tools.harness import field_item_qualification as q
from tools.harness.protocol import ProtocolError, atomic_json


class FieldProofTests(unittest.TestCase):
    def fixture(self, root):
        output=Path(root)/'output'; output.mkdir()
        source=output/'Source'
        for directory in ('dev','data','world/sprites'):
            (source/directory).mkdir(parents=True)
        (source/q.FEATURE).write_text('feature')
        grid=['#'*16]+['#'+'.'*14+'#']*14+['#'*16]
        town=dict(tiles=[['.'*8]*8],cells=[0]*360,cursor=grid,
                  locations={'VIRIDIAN_FOREST':dict(x=0,y=0),'PALLET_TOWN':dict(x=4,y=0)})
        atomic_json(source/'data/townMap.json',town)
        (source/'world/sprites/red.lua').write_text('down = {'+','.join(json.dumps(r) for r in grid)+'}')
        atomic_json(output/'source-manifest.json',{str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source.rglob('*') if p.is_file()})
        identity=dict(protocol=1,build_id='build',session_id='session')
        atomic_json(output/'build.json',dict(identity,source_sha256='source',compiled_source_sha256='compiled',sdk_version='3.1.2'))
        atomic_json(output/'run.json',dict(simulator_pid=123))
        atomic_json(output/'00001-request.json',dict(identity,id='r1',commands=['contracts']))
        atomic_json(output/'00001-result.json',dict(identity,id='r1',status='ok',results=[dict(op='contracts',contracts=dict(ok=True,suites=[dict(id=q.SUITE,ok=True,artifact_qualifier=q.QUALIFIER)]))]))
        (output/'frames').mkdir()
        for name,(_,selected) in list(q.MAPS.items())[:2]:
            image=Image.new('RGBA',(400,240),'white');draw=ImageDraw.Draw(image)
            # Literal independent sealed-white-body composition, not q.raster.
            points=[(0,0)] if selected=='VIRIDIAN_FOREST' else [(4,0),(0,0)]
            for x,y in points:
                left,top=12+x*8+16,48+y*8+8
                draw.rectangle((left,top,left+15,top+15),fill='black')
                draw.rectangle((left+1,top+1,left+14,top+14),fill='white')
            image.save(output/'frames'/(name+'.png'))
        return output,identity

    def qualify(self, output, identity):
        return q.finalize(output,Path(output)/'unused-runtime-data',output,identity)

    def test_complete_native_identity_exact_opaque_body_and_map(self):
        with tempfile.TemporaryDirectory() as root:
            output,identity=self.fixture(root); report=self.qualify(output,identity)
            self.assertTrue(report['ok']);self.assertEqual(report['process_pid'],123)
            self.assertEqual([m['checked_pixels'] for m in report['maps']],[23040,23040])
            self.assertEqual(len(report['executions']),1)
            self.assertEqual(report['executions'][0]['request_sha256'],hashlib.sha256((output/'00001-request.json').read_bytes()).hexdigest())

    def test_missing_corrupt_dimensions_pixel_alpha_and_white_body_fail(self):
        for fault in ('missing','corrupt','dimensions','pixel','alpha','opaque-body'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory() as root:
                output,identity=self.fixture(root); path=output/'frames/field-town-map-forest.png'
                if fault=='missing':path.unlink()
                elif fault=='corrupt':path.write_bytes(b'no PNG')
                else:
                    with Image.open(path) as src:image=src.copy()
                    if fault=='dimensions':image=image.crop((0,0,399,240))
                    else:image.putpixel((30,58) if fault=='opaque-body' else (12,48),(0,0,0,0 if fault=='alpha' else 255))
                    image.save(path)
                with self.assertRaises(ProtocolError):self.qualify(output,identity)
                self.assertFalse(json.loads((output/'field-map-qualification.json').read_text())['ok'])

    def test_wrong_or_missing_execution_identity_metadata_and_replay_fail(self):
        for fault in ('build','session','id','status','missing-suite','wrong-qualifier','failed-suite','repeat','wrong-process','source-drift'):
            with self.subTest(fault=fault),tempfile.TemporaryDirectory() as root:
                output,identity=self.fixture(root);path=output/'00001-result.json';packet=json.loads(path.read_text())
                suite=packet['results'][0]['contracts']['suites'][0]
                if fault in ('build','session'):packet[fault+'_id']='wrong'
                elif fault=='id':packet['id']='wrong'
                elif fault=='status':packet['status']='error'
                elif fault=='missing-suite':packet['results'][0]['contracts']['suites']=[]
                elif fault=='wrong-qualifier':suite['artifact_qualifier']='wrong'
                elif fault=='failed-suite':suite['ok']=False
                elif fault=='wrong-process':atomic_json(output/'run.json',dict(simulator_pid=None))
                elif fault=='source-drift':(output/'Source/world/sprites/red.lua').write_text('changed')
                elif fault=='repeat':
                    atomic_json(output/'00002-result.json',packet)
                    atomic_json(output/'00002-request.json',json.loads((output/'00001-request.json').read_text()))
                atomic_json(path,packet)
                with self.assertRaises(ProtocolError):self.qualify(output,identity)

    def test_process_local_proof_uses_current_generation_before_archive(self):
        with tempfile.TemporaryDirectory() as root:
            output,identity=self.fixture(root);evidence=output/'processes/0002';evidence.mkdir(parents=True)
            for path in output.glob('00001-*.json'):path.rename(evidence/path.name)
            atomic_json(evidence/'process.json',dict(pid=456,generation=2))
            report=q.finalize(output,output/'unused',evidence,identity)
            self.assertEqual((report['process_pid'],report['process_generation']),(456,2))
            self.assertTrue((evidence/'field-map-qualification.json').is_file())

    def test_functional_commands_without_contracts_need_no_images(self):
        with tempfile.TemporaryDirectory() as root:
            output,identity=self.fixture(root)
            for path in output.glob('00001-*.json'):path.unlink()
            self.assertIsNone(self.qualify(output,identity))

    def test_normal_runner_and_restart_finalize_after_producer_barrier(self):
        import inspect
        from tools.harness import run,restarting
        for module in (run,restarting):
            source=inspect.getsource(module)
            self.assertIn('qualify_field_items(client, data, output)',source)
            self.assertLess(source.index('finalize_captures(client, data, output)'),source.index('qualify_field_items(client, data, output)',source.index('finalize_captures(client, data, output)')))
