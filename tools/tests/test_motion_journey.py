import copy
import hashlib
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
import unittest
import tools.harness
# Test the staged modules while reusing the repository protocol/runner owners.
tools.harness.__path__.insert(0, str(Path(__file__).resolve().parents[1]/'harness'))
from tools.harness.motion_journey import MotionJourney, boundary, validate_config, validate_first_world_update
from tools.harness import restarting
from tools.harness.protocol import ProtocolError


def state():
    actor={'id':'source:actor','phase':'moving','tick':3,'x':5,'y':4,'facing':'down'}
    return {'frame':{'tick':10},'zone':'kanto_pewter_mart','zone_id':'pokered:PEWTER_MART',
        'root':'pause','overworld':'explore','player':{'x':5,'y':6,'facing':'up'},
        'npcs':[{'source_event_id':'source:actor','x':5,'y':4,'pixel_x':160,'pixel_y':100,
                 'facing':'down','motion':copy.deepcopy(actor)}],
        'world_motion':{'paused':True,'live':{'actors':[actor]},'rng':{'state':'42','rolls':'2'}},
        'rng':{'seed':42,'state':42,'rolls':0},'session':{'flags':{'quest':[],'trainers':[]}}}


class Probe(MotionJourney):
    def __init__(self, folder, changed=False):
        client=type('Client',(),{'identity':{'build_id':'build','session_id':'session'}})()
        super().__init__(client, folder, {'name':'npc-motion','location':'pewter-mart'})
        self.commands=[];self.changed=changed
    def send(self,*commands):
        self.commands.append(commands);self.state=state()
        self.state['npcs'][0]['source_event_id']='pokered:PEWTER_MART:objects:2'
        self.state['npcs'].insert(0,{'source_event_id':'pokered:PEWTER_MART:objects:1','x':2,'y':5,'pixel_x':64,'pixel_y':152,'facing':'down','motion':{'phase':'static'}})
        if isinstance(commands[0],dict) and commands[0].get('op')=='fixture':self.state['root']='overworld'
        elif commands[0]=='record motion-initial 48':self.state['root']='overworld'
        elif commands[0]=='record motion-paused 48' and self.changed:self.state['world_motion']['rng']['rolls']='3'
        return self.state


class MotionTests(unittest.TestCase):
    def test_atomic_observed_step_then_b_before_paused_recording(self):
        with tempfile.TemporaryDirectory() as folder:
            j=Probe(folder);j.freeze_step()
            self.assertEqual(j.commands[2],({'op':'await','path':'npcs.2.motion.tick','equals':1,'frames':900},'press b'))
            self.assertEqual(j.commands[3],('record motion-paused 48','wait 48'))
    def test_paused_rng_change_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ProtocolError,'paused native'):Probe(folder,True).freeze_step()
    def test_boundary_defensive_and_exact_native_pixels(self):
        s=state();saved=boundary(s);s['npcs'][0]['pixel_y']+=1
        self.assertNotEqual(saved,boundary(s));self.assertEqual(saved['native_npcs'][0]['pixel_y'],100)
    def test_unrendered_blocker_does_not_shift_actor_identity_or_receipt(self):
        s=state();expected=boundary(s);s['npcs'].insert(0,{'name':'unresolved warp','x':0,'y':0})
        self.assertEqual(boundary(s),expected)

    def test_missing_native_diagnostics_fail(self):
        s=state();del s['npcs'][0]['pixel_y']
        with self.assertRaisesRegex(ProtocolError,'pixel/facing'):boundary(s)
    def test_configs_fail_closed(self):
        for config in [{'name':'npc-motion','seed':True},{'name':'npc-motion','seed':1.5},
                       {'name':'npc-motion','location':'unknown'},{'name':'npc-motion-continue','seed':42},
                       {'name':'npc-motion','extra':1}]:
            with self.subTest(config=config),self.assertRaises(ProtocolError):validate_config(config)
    def test_config_signed_seed_bounds(self):
        for seed in [-2147483648,2147483647]:validate_config({'name':'npc-motion','seed':seed})
    def test_motion_restart_approved_pair(self):
        restarting.validate({'processes':[{'journey':{'name':'npc-motion-save','location':'pewter-mart'}},
            {'restart':True,'journey':{'name':'npc-motion-continue'}}]})
    def test_restart_cross_kind_and_conflicting_fields_reject(self):
        for first,second in [('brock-natural','npc-motion-continue'),('npc-motion-save','brock-continue')]:
            with self.assertRaises(ProtocolError):restarting.validate({'processes':[{'journey':{'name':first}}, {'restart':True,'journey':{'name':second}}]})
        with self.assertRaises(ProtocolError):restarting.validate({'processes':[{'journey':{'name':'npc-motion-save'},'requests':[['snapshot']]},{'restart':True,'journey':{'name':'npc-motion-continue'}}]})
    def test_restart_unknown_location_and_continue_override_reject(self):
        for first,second in [({'name':'npc-motion-save','location':'unknown'},{'name':'npc-motion-continue'}),
                             ({'name':'npc-motion-save'},{'name':'npc-motion-continue','location':'pewter-mart'})]:
            with self.assertRaises(ProtocolError):restarting.validate({'processes':[{'journey':first},{'restart':True,'journey':second}]})
    def test_motion_receipt_identity_hash_and_missing_pose_guard(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'receipt.json';packet={'schema':1,'kind':'npc-motion-saved','build_id':'build','session_id':'session','state':boundary(state())}
            def publish():
                path.write_text(json.dumps(packet));return {'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
            ref=publish();self.assertEqual(restarting.read_receipt(ref,packet),packet)
            with self.assertRaises(ProtocolError):restarting.read_receipt(ref,dict(packet,build_id='wrong'))
            packet['state']['native_npcs']=[]
            with self.assertRaises(ProtocolError):restarting.read_receipt(publish(),packet)
            path.write_text('changed')
            with self.assertRaises(ProtocolError):restarting.read_receipt(ref,packet)
    def test_continue_compares_press_result_before_later_resume(self):
        saved=boundary(state())
        class Continued(Probe):
            def send(self,*commands):
                self.commands.append(commands);self.state=state()
                if commands[0]=='snapshot':self.state.update(root='title',title={'phase':'menu','menu':{'options':['CONTINUE','NEW GAME'],'selected':1}})
                else:self.state.update(root='overworld',overworld='explore')
                if commands[0]=='record motion-continued-resume 96':self.state['world_motion']['live']['actors'][0]['tick']=6
                return self.state
            def continue_frames(self):
                self.commands.append(('record motion-continue-boundary 3','press a','snapshot'))
                installed=state();installed.update(root='overworld');rendered=copy.deepcopy(installed)
                rendered['frame']['tick']=11;rendered['world_motion']['paused']=False
                rendered['world_motion']['live']['actors'][0]['tick']=4
                return installed,rendered
            def write_receipt(self):self.written=boundary(self.state)
        with tempfile.TemporaryDirectory() as folder:
            j=Continued(folder)
            with patch('tools.harness.motion_journey.verify_rendered_poses',return_value={'exact':True}) as proof:
                j.continue_midstep({'schema':1,'kind':'npc-motion-saved','build_id':'build','session_id':'session','state':saved})
            self.assertEqual(j.written,saved)
            self.assertEqual(j.commands[1],('record motion-continue-boundary 3','press a','snapshot'))
            self.assertEqual(proof.call_count,2)
            self.assertEqual([call.args[1].name for call in proof.call_args_list],
                             ['motion-continue-boundary-02.png','motion-continue-boundary-03.png'])
            self.assertEqual(boundary(proof.call_args_list[0].args[2]),saved)
            self.assertEqual(j.summary['first_rendered_world']['png'],'motion-continue-boundary-02.png')
            self.assertEqual(j.summary['first_updated_world']['png'],'motion-continue-boundary-03.png')
            self.assertNotEqual(boundary(j.state),saved)
    def test_save_keeps_saved_message_overlay_and_captured_midstep(self):
        class Saving(Probe):
            def freeze_step(self):self.state=state();return boundary(self.state)
            def select_pause(self,option):self.commands.append(('select',option))
            def send(self,*commands):
                self.commands.append(commands);self.state=state()
                if self.commands.count(('press a',))==1:self.state.update(pause={'phase':'save'})
                else:
                    self.state.update(root='dialog',pause={'lastSave':{'ok':True}})
                    self.state['world_motion']['captured']=copy.deepcopy(self.state['world_motion']['live'])
                return self.state
            def write_receipt(self):self.written=boundary(self.state)
        with tempfile.TemporaryDirectory() as folder:
            j=Saving(folder);j.save_midstep()
            self.assertEqual(j.state['root'],'dialog')
            self.assertEqual(j.commands[-1],('record motion-saved 48','wait 48'))
            self.assertEqual(j.written,boundary(state()))

    def test_first_world_snapshot_must_advance_exactly_one_frame_and_step(self):
        installed=state();installed['root']='overworld';rendered=copy.deepcopy(installed)
        rendered['world_motion']['paused']=False;rendered['frame']['tick']=11
        rendered['world_motion']['live']['actors'][0]['tick']=4
        validate_first_world_update(installed,rendered)
        rendered['frame']['tick']=12
        with self.assertRaisesRegex(ProtocolError,'exactly one'):validate_first_world_update(installed,rendered)
        rendered['frame']['tick']=11;rendered['world_motion']['live']['actors'][0]['tick']=3
        with self.assertRaisesRegex(ProtocolError,'tick advance'):validate_first_world_update(installed,rendered)

    def test_continue_wrong_pose_fails_without_resume(self):
        class Bad(Probe):
            def send(self,*commands):
                self.commands.append(commands);self.state=state()
                self.state.update(root='title',title={'phase':'menu','menu':{'options':['CONTINUE'],'selected':1}})
                return self.state
            def continue_frames(self):
                self.commands.append(('boundary',));installed=state();installed.update(root='overworld');installed['npcs'][0]['pixel_y']+=1
                return installed,copy.deepcopy(installed)
        with tempfile.TemporaryDirectory() as folder:
            j=Bad(folder)
            with self.assertRaisesRegex(ProtocolError,'install boundary'):j.continue_midstep({'schema':1,'kind':'npc-motion-saved','build_id':'build','session_id':'session','state':boundary(state())})
            self.assertEqual(len(j.commands),2)

if __name__=='__main__':unittest.main()
