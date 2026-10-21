import json
from pathlib import Path
import tempfile,threading,time,unittest
from tools.harness.protocol import Client,atomic_json
from tools.harness.qualification import unicode_error_roundtrip

class UnicodeErrorQualificationTests(unittest.TestCase):
    def test_controlled_unicode_error_then_real_client_recovery_and_following_request(self):
        with tempfile.TemporaryDirectory()as directory:
            root=Path(directory);data=root/'mailbox';errors=[]
            with Client(data,'unicode-build','unicode-session',root/'evidence')as client:
                def peer():
                    try:
                        seen=set();deadline=time.monotonic()+3
                        while len(seen)<3:
                            if time.monotonic()>deadline:raise AssertionError('three request barriers did not complete')
                            path=data/'request.json'
                            if not path.exists():time.sleep(.005);continue
                            request=json.loads(path.read_text(encoding='utf-8'))
                            if request['id']in seen:time.sleep(.005);continue
                            seen.add(request['id']);commands=request['commands']
                            if len(seen)==1:
                                self.assertEqual(commands,[{'op':'assert','path':'story.stage','equals':'é'}]);self.assertIn(b'\xc3\xa9',path.read_bytes())
                                response=client.envelope(id=request['id'],status='error',error='assertion story.stage expected é got pre_oak',results=[],snapshot={})
                            else:
                                if len(seen)==2:self.assertEqual(commands[0]['op'],'fixture')
                                else:self.assertEqual(commands,['gamestate'])
                                response=client.envelope(id=request['id'],status='ok',results=[{'command':1,'status':'ok'}],snapshot={})
                            atomic_json(data/'result.json',response)
                    except BaseException as error:errors.append(error)
                thread=threading.Thread(target=peer);thread.start()
                try:report=unicode_error_roundtrip(client)
                finally:thread.join(4)
                self.assertEqual(errors,[]);self.assertEqual(report['expected'],'é');self.assertEqual(report['encoding'],'strict UTF8')
                self.assertEqual(len({report['failed_id'],report['recovery_id'],report['following_id']}),3)
if __name__=='__main__':unittest.main()
