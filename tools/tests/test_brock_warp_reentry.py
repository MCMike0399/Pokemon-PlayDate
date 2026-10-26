"""Host-driver decisions only; actual native return remains separately required."""
import copy,json,os,unittest
from pathlib import Path
from tools.harness.brock_journey import BrockJourney,load_models,MAPS

class WarpReentryTests(unittest.TestCase):
 def fixture(self,single=False,blocked=False):
  j=BrockJourney(None,'/private/tmp',{'starter':'bulbasaur'});j.models,j.doors,_=load_models(Path(os.environ['PARCEL_BUNDLE_SOURCE']))
  j.state=copy.deepcopy(json.loads((Path(__file__).parent/'fixtures/brock-warp-arrival.json').read_text())['state'])
  self.assertEqual((j.state['zone_id'],j.position()),(MAPS['ViridianForest'],(1,0)))
  if single:
   # Synthetic single-warp model, keeping the declaration/cache coherent.
   j.model().events['warps']=[e for e in j.model().events['warps']if (e['x'],e['y'])==(1,0)]
   j.model().warps={(1,0)}
  if blocked:j.state['npcs']=[{'x':1,'y':1},{'x':2,'y':0}]
  visits=[]
  def navigate(goal,transition=None):
   # Model the host navigation acknowledgement only, never Playdate execution.
   # A zero-length request cannot emit input or claim a map transition.
   model=j.model();route=model.path(j.position(),{goal},j.occupied(),allow_warps={goal}if transition else ())
   visits.append((goal,transition,len(route)))
   if not route:return
   j.state['player'].update(x=goal[0],y=goal[1])
   if transition:
    event=next(e for e in model.events['warps']if (e['x'],e['y'])==goal);zone,arrival=j.warp_projection(event)
    self.assertEqual(zone,transition);j.state['zone_id']=zone;j.state['player'].update(x=arrival[0],y=arrival[1])
  j.navigate=navigate
  j.send=lambda *args:self.fail('unexpected blind directional input '+str(args))
  return j,visits
 def test_actual_recovery_arrival_requires_a_real_step_before_return(self):
  j,visits=self.fixture();j.warp(MAPS['ViridianForestNorthGate'])
  self.assertTrue(any(length>0 for _,_,length in visits))
  self.assertEqual(j.state['zone_id'],MAPS['ViridianForestNorthGate'])
  self.assertEqual(visits,[((2,0),MAPS['ViridianForestNorthGate'],1)])
 def test_single_step_warp_is_left_and_reentered_through_reversible_source_cells(self):
  j,visits=self.fixture(single=True);j.warp(MAPS['ViridianForestNorthGate'])
  self.assertEqual(visits,[((1,1),None,1),((1,0),MAPS['ViridianForestNorthGate'],1)])
 def test_occupied_only_exit_cannot_be_mistaken_for_a_successful_warp(self):
  from tools.harness.protocol import ProtocolError
  j,visits=self.fixture(single=True,blocked=True)
  with self.assertRaisesRegex(ProtocolError,'no reachable source warp'):j.warp(MAPS['ViridianForestNorthGate'])
  self.assertEqual(visits,[])
 def test_occupied_adjacent_warp_uses_real_off_and_back_and_exact_other_arrival(self):
  j,visits=self.fixture();j.state['npcs']=[{'x':2,'y':0}];j.warp(MAPS['ViridianForestNorthGate'])
  self.assertEqual(visits,[((1,1),None,1),((1,0),MAPS['ViridianForestNorthGate'],1)])
  self.assertEqual(j.position(),(5,7))
 def test_current_bottom_edge_mat_keeps_outward_input_without_detour(self):
  j,visits=self.fixture();j.state={'zone_id':MAPS['ViridianForestNorthGate'],'player':{'x':6,'y':7},'npcs':[]};commands=[]
  def send(*values):
   self.assertEqual(values,('press down','wait 15'));commands.extend(values)
   j.state['zone_id']=MAPS['ViridianForest'];j.state['player'].update(x=1,y=0)
  j.send=send;j.drain=lambda:None;j.warp(MAPS['ViridianForest'])
  self.assertEqual(visits,[((6,7),MAPS['ViridianForest'],0)])
  self.assertEqual(commands,['press down','wait 15'])
 def test_nonreversible_off_step_is_rejected_before_input(self):
  from tools.harness.protocol import ProtocolError
  j,visits=self.fixture(single=True);j.state['npcs']=[{'x':2,'y':0}];original=j.model().terrain_step
  j.model().terrain_step=lambda point,direction:None if point==(1,1)and direction=='up'else original(point,direction)
  with self.assertRaisesRegex(ProtocolError,'no reachable source warp'):j.warp(MAPS['ViridianForestNorthGate'])
  self.assertEqual(visits,[])
