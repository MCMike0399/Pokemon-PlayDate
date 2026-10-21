"""Scripted native-protocol snapshot traces, not a battle/evolution emulator."""
import copy,tempfile,unittest
from tools.harness.brock_journey import BrockJourney
from tools.harness.protocol import ProtocolError

def evolution_trace(policy='accept',wrong_species=False,failed=False,next_visit=False):
 j=BrockJourney(None,'/private/tmp',{'evolution_policy':policy});commands=[];snapshots=[]
 before=[{'species':'squirtle','hp':20},{'species':'squirtle'if next_visit else'pidgey','hp':6}]
 native={'from':'squirtle','species':'wartortle','phase':'announce','frame':0,'result':'none','can_cancel':True,'dialog_ready':True}
 j.state={'root':'evolution','evolution':copy.deepcopy(native),'session':{'party':{'members':copy.deepcopy(before)}}}
 def publish(value,members):j.state={'root':'evolution','evolution':copy.deepcopy(value),'session':{'party':{'members':copy.deepcopy(members)}}}
 members=copy.deepcopy(before)
 def send(command):
  nonlocal native,members
  commands.append(command)
  if command.startswith('shot '):snapshots.append(copy.deepcopy(j.state));return
  if command=='press a'and native['phase']=='announce':native.update(phase='animate',frame=1,dialog_ready=False)
  elif command.startswith('record '):
   if native['phase']!='animate':raise AssertionError('recording outside native animation')
   native['frame']+=int(command.split()[2])
  elif command=='wait 6':native['frame']+=6
  elif command=='press b'and native['phase']=='animate':
   native.update(phase='result',result='cancelled',dialog_ready=False)
   if wrong_species:members[0]['species']='wartortle'
  elif command=='wait 3':native['dialog_ready']=True
  elif command=='press a'and native['phase']=='result':
   if next_visit:
    publish(dict(native,phase='announce',frame=0,result='none',dialog_ready=False),members)
    return
   j.state={'root':'battle','evolution':{'phase':'closed','result':'none'},'session':{'party':{'members':copy.deepcopy(members)}}};return
  else:raise AssertionError('unexpected semantic action '+command)
  if native['phase']=='animate'and native['frame']>=120:
   native.update(phase='result',result='failed'if failed else'complete',dialog_ready=False)
   if not failed:members[0]['species']='charmeleon'if wrong_species else'wartortle'
  publish(native,members)
 j.send=send;j.checkpoint=lambda name:send('shot '+name)
 return j,commands,snapshots

class EvolutionEvidenceTests(unittest.TestCase):
 def test_accept_records96_actual_frames_once_and_retains_complete_before_closed_none(self):
  j,commands,snapshots=evolution_trace();j.evolution();entry=j.summary['evolutions'][0]
  self.assertEqual(entry['result'],'complete');self.assertEqual(j.state['evolution']['result'],'none')
  self.assertEqual(entry['before'][0]['species'],'squirtle');self.assertEqual(entry['after'][0]['species'],'wartortle')
  self.assertEqual([c for c in commands if c.startswith('record ')],['record brock-evolution-001-animate 96'])
  self.assertNotIn('press b',commands);self.assertTrue(entry['animation']['complete'])
  self.assertEqual([s['evolution']['phase']for s in snapshots],['announce','result'])
  self.assertTrue(all(s['evolution']['dialog_ready']for s in snapshots));self.assertEqual(entry['observed_result_snapshot']['result'],'complete')
 def test_cancel_sends_actual_b_early_without_record_and_keeps_species_with_result(self):
  j,commands,snapshots=evolution_trace('cancel');j.evolution();entry=j.summary['evolutions'][0]
  self.assertEqual(entry['result'],'cancelled');self.assertEqual(entry['after'][0]['species'],'squirtle')
  self.assertEqual(commands.count('press b'),1);self.assertFalse(any(c.startswith('record ')for c in commands))
  self.assertIn('shot brock-evolution-001-cancel-before',commands);self.assertIn('shot brock-evolution-001-cancelled',commands)
  self.assertLess(commands.index('shot brock-evolution-001-cancel-before'),commands.index('press b'))
 def test_unready_announce_waits_before_its_actual_capture(self):
  j,commands,snapshots=evolution_trace();j.state['evolution']['dialog_ready']=False;j.evolution()
  self.assertEqual(commands[0],'wait 3');self.assertEqual(commands[1],'shot brock-evolution-001-announce')
  self.assertTrue(all(snapshot['evolution']['dialog_ready']for snapshot in snapshots))
 def test_cancel_result_cannot_hide_an_actual_species_change(self):
  j,_,_=evolution_trace('cancel',wrong_species=True)
  with self.assertRaisesRegex(ProtocolError,'cancelled evolution changed'):j.evolution()
 def test_completed_result_cannot_hide_wrong_actual_target_species(self):
  j,_,_=evolution_trace(wrong_species=True)
  with self.assertRaisesRegex(ProtocolError,'source/target species'):j.evolution()
 def test_non_cancellable_native_evolution_fails_cancel_policy_before_b_or_record(self):
  j,commands,_=evolution_trace('cancel');j.state['evolution']['can_cancel']=False
  # Preserve the observed permission in each scripted subsequent snapshot.
  old=j.send
  def send(command):old(command);j.state.get('evolution',{})['can_cancel']=False
  j.send=send
  with self.assertRaisesRegex(ProtocolError,'not cancellable'):j.evolution()
  self.assertNotIn('press b',commands);self.assertFalse(any(c.startswith('record ')for c in commands))
 def test_failed_native_result_is_captured_and_not_acknowledged_as_success(self):
  j,commands,_=evolution_trace(failed=True)
  with self.assertRaisesRegex(ProtocolError,'actual evolution failed'):j.evolution()
  self.assertEqual(j.summary['evolutions'][0]['result'],'failed');self.assertEqual(commands[-1],'shot brock-evolution-001-failed')
 def test_immediate_next_party_evolution_announce_finishes_only_prior_visit(self):
  j,commands,_=evolution_trace(next_visit=True);j.evolution()
  self.assertEqual(j.state['root'],'evolution');self.assertEqual(j.state['evolution']['phase'],'announce')
  self.assertEqual(len(j.summary['evolutions']),1);self.assertEqual(j.summary['evolutions'][0]['result'],'complete')
 def test_late_animation_or_missing_result_cannot_claim_evidence(self):
  j,commands,_=evolution_trace();j.state['evolution'].update(phase='animate',frame=25)
  with self.assertRaisesRegex(ProtocolError,'too late'):j.evolution()
  self.assertFalse(any(c.startswith('record ')for c in commands))
  j,commands,_=evolution_trace();j.send=lambda command:j.state.update(root='battle')
  with self.assertRaisesRegex(ProtocolError,'actual complete result'):j.evolution()
if __name__=='__main__':unittest.main()
