import json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from tools.harness import brock_journey as m
class ForcedSwitchTests(unittest.TestCase):
 def fixture(self,stuck=False,defeat=False):
  j=m.BrockJourney(None,'/private/tmp',{'starter':'bulbasaur'});members=[{'species':'bulbasaur','hp':0},{'species':'pidgey','hp':6}]
  battle={'phase':'forcedSwitch','trainerName':None,'introPhase':'ready','player':members[0],'enemy':{'species':'pidgey','hp':9},'legal_moves':[]}
  j.state={'root':'battle','battle':battle,'session':{'party':{'active':1}}};j.party=lambda:members;j.inventory=lambda:{'money':1000};j.await_value=lambda *a,**k:None;j.checkpoint=lambda name:None
  commands=[];selected=[]
  def select(path,index):selected.append((path,index))
  def send(command):
   commands.append(command)
   if command=='wait 2':
    if not stuck:j.state['root']='party'
   elif command=='press a'and j.state['root']=='party':
    self.assertEqual(selected[-1],('party_ui.selected',2));j.state['session']['party']['active']=2;j.state['root']='battle';battle.update(phase='ended',outcome='defeat'if defeat else'victory',player={'species':'pidgey','hp':0 if defeat else 6},enemy={'species':'pidgey','hp':9 if defeat else 0})
   elif command=='press a'and battle['phase']=='ended':
    j.state.update(root='overworld',last_battle_outcome={'kind':'defeat'if defeat else'victory','won':not defeat,'blackout':defeat,'payout':0,'money_delta':-500 if defeat else 0})
   else:self.fail('unexpected semantic input '+command)
  j.select=select;j.send=send;return j,commands,selected
 def test_transient_forced_phase_waits_for_real_party_then_selects_conscious_reserve(self):
  j,commands,selected=self.fixture();self.assertEqual(j.battle('preparation-10',expected='win'),(True,False))
  self.assertEqual(commands,['wait 2','press a','press a']);self.assertEqual(selected,[('party_ui.selected',2)])
  self.assertEqual(j.state['session']['party']['active'],2);self.assertEqual(j.summary['battles'][-1]['outcome']['kind'],'victory')
 def test_stuck_forced_phase_remains_bounded_and_never_invents_terminal_outcome(self):
  j,commands,_=self.fixture(stuck=True)
  with self.assertRaisesRegex(m.ProtocolError,'exceeded1200'):j.battle('stuck',expected='win')
  self.assertEqual(len(commands),1200);self.assertEqual(j.summary['battles'],[])
 def test_actual_replacement_defeat_still_fails_expected_victory(self):
  j,_,_=self.fixture(defeat=True)
  with self.assertRaises(m.NaturalBlackout):j.battle('replacement',expected='win')
  self.assertEqual(j.summary['battles'][-1]['outcome']['kind'],'defeat')
 def test_interrupted_training_does_not_steal_prior_battle_victory(self):
  j=m.BrockJourney(None,'/private/tmp',{});j.training_mode='train';j.party=lambda:[]
  old={'name':'previous','outcome':{'kind':'victory'}};j.summary['battles']=[old];j.state={'root':'party','last_battle_outcome':old['outcome']}
  def fail(*a,**kw):raise m.ProtocolError('replacement interrupted')
  j.battle=fail
  with self.assertRaisesRegex(m.ProtocolError,'replacement interrupted'):j.training_battle()
  entry=j.summary['training'][0];self.assertIsNone(entry['outcome']);self.assertFalse(entry['completed']);self.assertTrue(entry['interrupted']);self.assertEqual(entry['error'],'replacement interrupted');self.assertIs(j.summary['battles'][0],old)
 def test_completed_actual_blackout_record_survives_recovery_exception(self):
  j=m.BrockJourney(None,'/private/tmp',{});j.training_mode='train';j.party=lambda:[];j.state={}
  def fail(name,**kw):j.summary['battles'].append({'name':name,'outcome':{'kind':'defeat','blackout':True}});raise m.NaturalBlackout('actual defeat')
  j.battle=fail
  with self.assertRaises(m.NaturalBlackout):j.training_battle()
  entry=j.summary['training'][0];self.assertTrue(entry['completed']);self.assertFalse(entry['interrupted']);self.assertEqual(entry['outcome']['kind'],'defeat')
 def test_real_center_observation_schedules_actual_next_battle_party_switch(self):
  j=m.BrockJourney(None,'/private/tmp',{'starter':'bulbasaur'});members=[{'species':'bulbasaur','hp':0},{'species':'pidgey','hp':6}]
  j.state={'root':'overworld','zone_id':m.MAPS['Route2'],'session':{'party':{'active':2}}};j.party=lambda:members
  j.navigate=lambda p:None;j.cross=lambda direction,zone,p:j.state.update(zone_id=zone)
  def center(city):members[0]['hp']=26
  j.center=center;j.reach_training_zone=lambda zone:j.state.update(zone_id=zone)
  j.training_center();self.assertTrue(j.switch_back);self.assertEqual(j.state['session']['party']['active'],2)
  selected=[];commands=[];j.state['root']='battle'
  j.select=lambda path,index:selected.append((path,index))
  def send(command):
   commands.append(command)
   if j.state['root']=='battle':j.state['root']='party'
   else:j.state['root']='battle';j.state['session']['party']['active']=1
  j.send=send
  self.assertTrue(j.battle_preparation_action({'trainerName':'TRAINER'},['FIGHT','POKEMON','BAG','RUN']))
  self.assertEqual(commands,['press a','press a']);self.assertEqual(selected,[('battle.menu.selected',2),('party_ui.selected',1)])
  self.assertFalse(j.switch_back);self.assertEqual(j.state['session']['party']['active'],1)
 def test_intro_loss_and_failed_or_completed_campaign_have_distinct_summary_fields(self):
  for fail in [True,False]:
   with tempfile.TemporaryDirectory()as folder:
    def natural(j):
     j.summary['outcome']='loss'
     if fail:raise m.ProtocolError('actual nonterminal replacement')
    with patch.object(m.BrockJourney,'natural',natural):
     if fail:
      with self.assertRaises(m.ProtocolError):m.run(None,{'journey':{'name':'brock-natural'}},folder)
     else:m.run(None,{'journey':{'name':'brock-natural'}},folder)
    d=json.loads((Path(folder)/'journey-summary.json').read_text());self.assertEqual(d['outcome'],'loss');self.assertEqual(d['intro_outcome'],'loss');self.assertEqual(d['journey_outcome'],'failed'if fail else'complete');self.assertEqual(d['ok'],not fail)
if __name__=='__main__':unittest.main(verbosity=2)
