"""Host protocol traces; native learning screenshots remain separate evidence."""
import copy,unittest
from unittest.mock import patch
from tools.harness.brock_journey import BrockJourney
from tools.harness.protocol import ProtocolError

class LearningEvidenceTests(unittest.TestCase):
 def test_release_gate_is_observed_before_decline_menu_navigation(self):
  journey = BrockJourney(None, '/private/tmp', {})
  journey.state = {'root': 'learning', 'learning': {
   'phase': 'ask', 'input_blocked': True, 'selected': 1,
   'move_info': {}, 'known_moves': [], 'dialog_ready': True,
  }}
  commands = []
  captures = []
  def send(command):
   commands.append(command)
   learning = journey.state.get('learning', {})
   if command == 'wait 2':
    learning['input_blocked'] = False
   elif command == 'press down':
    if learning['input_blocked']:
     learning['input_blocked'] = False
    else:
     learning['selected'] = 2
   elif command == 'press a':
    if learning['phase'] == 'ask':
     self.assertEqual(learning['selected'], 2)
     learning.update(phase='stop', selected=1)
    elif learning['phase'] == 'stop':
     learning['phase'] = 'message'
    else:
     journey.state = {'root': 'battle'}
   else:
    self.fail('unexpected input ' + command)
  journey.send = send
  journey.checkpoint = lambda name: captures.append(copy.deepcopy(journey.state['learning']))
  with patch('tools.harness.brock_journey.learn_decision', return_value=None):
   journey.learning()
  self.assertEqual(commands[:2], ['wait 2', 'press down'])
  self.assertEqual(captures[0]['selected'], 2)
  self.assertEqual(commands.count('press a'), 3)

 def trace(self,replacement=True,decline=False,failed_capture=False):
  j=BrockJourney(None,'/private/tmp',{});commands=[];captures=[];selections=[]
  phases=['message','ask','stop'if decline else'replace']+([]if decline else['confirm'])+['message','message'] if replacement else ['message']
  index=0
  def publish():
   phase=phases[index]
   j.state={'root':'learning','learning':{'phase':phase,'dialog_ready':phase!='message','move_info':{},'known_moves':[],'selected':1,'move':'vineWhip','pokemon':'bulbasaur','choice_id':1}}
  publish()
  def send(command):
   nonlocal index
   commands.append(command)
   if command=='wait 3':j.state['learning']['dialog_ready']=True
   elif command.startswith('shot '):
    if failed_capture:raise ProtocolError('actual capture failed')
    self.assertTrue(j.state['learning']['phase']!='message'or j.state['learning']['dialog_ready'])
    captures.append(copy.deepcopy(j.state['learning']))
   elif command=='press a':
    index+=1
    if index==len(phases):j.state={'root':'battle'}
    else:publish()
   else:self.fail('unexpected semantic command '+command)
  def select(path,value):
   selections.append((path,value));j.state['learning']['selected']=value
  j.send=send;j.select=select;j.checkpoint=lambda name:send('shot '+name)
  return j,commands,captures,selections
 def test_free_slot_waits_for_readable_message_and_captures_before_acknowledgement(self):
  j,commands,captures,_=self.trace(False);j.learning()
  self.assertEqual(commands,['wait 3','shot brock-learning-001-message','press a'])
  self.assertEqual(len(captures),1);self.assertTrue(captures[0]['dialog_ready']);self.assertEqual(len(j.summary['learning_captures']),1)
 def test_replacement_captures_actual_selected_menus_and_both_ready_message_lines(self):
  j,commands,captures,selections=self.trace()
  with patch('tools.harness.brock_journey.learn_decision',return_value=2):j.learning()
  self.assertEqual([x['phase']for x in captures],['message','ask','replace','confirm','message','message'])
  self.assertEqual([x['selected']for x in captures],[1,1,2,1,1,1])
  self.assertEqual(selections,[('learning.selected',1),('learning.selected',2),('learning.selected',1)])
  self.assertEqual(commands.count('press a'),6);self.assertEqual(commands.count('wait 3'),3)
 def test_decline_captures_keep_and_stop_choices_without_changing_decision(self):
  j,_,captures,selections=self.trace(decline=True)
  with patch('tools.harness.brock_journey.learn_decision',return_value=None):j.learning()
  self.assertEqual([x['phase']for x in captures],['message','ask','stop','message','message'])
  self.assertEqual(selections,[('learning.selected',2),('learning.selected',1)])
 def test_failed_capture_is_not_recorded_or_acknowledged_as_completed_learning(self):
  j,commands,_,_=self.trace(False,failed_capture=True)
  with self.assertRaisesRegex(ProtocolError,'capture failed'):j.learning()
  self.assertNotIn('press a',commands);self.assertEqual(j.summary['learning_captures'],[])
