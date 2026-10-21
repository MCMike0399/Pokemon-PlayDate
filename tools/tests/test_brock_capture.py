import json,tempfile,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from PIL import Image
from tools.harness.brock_capture import qualify,identify,visual_preflight
from tools.harness.protocol import ProtocolError
class CaptureTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.p=Path(self.tmp.name);self.png=self.p/'proof.png'
  image=Image.new('RGBA',(400,240),'white');image.putpixel((100,100),(0,0,0,255));image.save(self.png)
 def state(self):return {'frame':{'phase':'completed','tick':42},'root':'overworld','overworld':'explore','player':{'settled':True}}
 def test_black_or_white_semantically_successful_world_is_rejected(self):
  for color in ['black','white']:
   Image.new('RGBA',(400,240),color).save(self.png)
   with self.assertRaisesRegex(ProtocolError,'blank'):qualify(self.p,self.png,self.state(),'world')
 def test_wrong_dimensions_corrupt_and_transparency_fail(self):
  Image.new('RGBA',(399,240),'white').save(self.png)
  with self.assertRaises(ProtocolError):qualify(self.p,self.png,self.state(),'world')
  self.png.write_bytes(b'partial PNG')
  with self.assertRaises(Exception):qualify(self.p,self.png,self.state(),'world')
  image=Image.new('RGBA',(400,240),(0,0,0,0));image.save(self.png)
  with self.assertRaisesRegex(ProtocolError,'opaque'):qualify(self.p,self.png,self.state(),'world')
 def test_world_must_be_settled_and_have_actual_source_foreground(self):
  s=self.state();s['player']['moving']=True
  with self.assertRaisesRegex(ProtocolError,'settled'):qualify(self.p,self.png,s,'world')
  s['player']['moving']=False
  with patch('tools.harness.motion_journey.verify_rendered_poses',return_value={'actors':[{'opaque_pixels_checked':0}]}):
   with self.assertRaisesRegex(ProtocolError,'visible source actors'):qualify(self.p,self.png,s,'world')
  with patch('tools.harness.motion_journey.verify_rendered_poses',return_value={'method':'exact-source-opaque-RGBA','actors':[{'opaque_pixels_checked':704}]})as oracle:
   proof=qualify(self.p,self.png,s,'world');self.assertEqual(proof['method'],'exact-source-opaque-RGBA');oracle.assert_called_once_with(self.p,self.png,s)
 def test_source_drift_is_never_hidden_by_nonblank_frame(self):
  with patch('tools.harness.motion_journey.verify_rendered_poses',side_effect=ProtocolError('source pose mismatch')):
   with self.assertRaisesRegex(ProtocolError,'source pose mismatch'):qualify(self.p,self.png,self.state(),'world')
 def test_title_must_really_offer_and_select_continue(self):
  s=self.state();s.update(root='title',title={'phase':'menu','selected':2,'menu':{'options':['NEW GAME','CONTINUE']}})
  self.assertEqual(qualify(self.p,self.png,s,'title')['kind'],'title');s['title']['selected']=1
  with self.assertRaisesRegex(ProtocolError,'selected real CONTINUE'):qualify(self.p,self.png,s,'title')
 def test_saved_dialog_must_be_ready_and_save_successful(self):
  s=self.state();s.update(root='dialog',dialog={'ready':False},pause={'lastSave':{'ok':True}})
  with self.assertRaises(ProtocolError):qualify(self.p,self.png,s,'saved-dialog')
  s['dialog']['ready']=True;self.assertEqual(qualify(self.p,self.png,s,'saved-dialog')['kind'],'saved-dialog');s['pause']['lastSave']['ok']=False
  with self.assertRaises(ProtocolError):qualify(self.p,self.png,s,'saved-dialog')
 def test_exact_shot_request_result_identity_hashes_and_stale_rejection(self):
  client=SimpleNamespace(evidence=self.p,sequence=7,identity={'build_id':'b','session_id':'s'});s=self.state()
  q={'build_id':'b','session_id':'s','id':'007-i','commands':['shot proof']};r=dict(q,status='ok',snapshot=s)
  def write():
   (self.p/'00007-request.json').write_text(json.dumps(q));(self.p/'00007-result.json').write_text(json.dumps(r))
  write();proof=identify(client,s,'proof');self.assertEqual(len(proof['request_sha256']),64);self.assertEqual(len(proof['result_sha256']),64)
  r['session_id']='stale';write()
  with self.assertRaisesRegex(ProtocolError,'another session_id'):identify(client,s,'proof')
  r['session_id']='s';q['commands']=['snapshot'];write()
  with self.assertRaisesRegex(ProtocolError,'identified shot'):identify(client,s,'proof')
 def test_dependency_preflight_only_targets_natural_and_continue(self):
  visual_preflight({'processes':[{'journey':{'name':'brock-natural'}},{'journey':{'name':'brock-continue'}}]})
  visual_preflight({'commands':['snapshot']})
if __name__=='__main__':unittest.main()

class SaveSequenceTests(unittest.TestCase):
 def test_parcel_and_final_brock_save_use_distinct_dialog_labels_and_final_source_world(self):
  from tools.harness.brock_journey import BrockJourney
  for defeated,expected in [(False,[('parcel-save-dialog','saved-dialog')]),(True,[('brock-save-dialog','saved-dialog'),('brock-game-saved','world')])]:
   j=object.__new__(BrockJourney);j.send=lambda *args:None;j.require=lambda **args:None;j.pause_option=lambda *args:None;j.await_value=lambda *args,**kwargs:None;j.dialog=lambda:None
   j.defeated=lambda id:defeated;captures=[];j.capture_presentation=lambda *args:captures.append(args);checkpoints=[];j.checkpoint=lambda label:checkpoints.append(label)
   j.save();self.assertEqual(captures,expected);self.assertEqual(checkpoints,[]if defeated else['parcel-game-saved'])
