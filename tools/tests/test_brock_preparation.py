"""Host policy/schema regressions; none of these asserts a native journey pass."""
import json, tempfile, unittest
from pathlib import Path
from tools.harness.brock_journey import BrockJourney, FAMILIES, NaturalBlackout, choose_move, move_score, learn_decision, training_lane
from tools.harness.parcel_journey import Geometry
from tools.harness.protocol import ProtocolError
from tools.harness import restarting, suite


def move(key='tackle', **values):
    result=dict(key=key,index=1,pp=10,power=50,accuracy=100,effective_accuracy=100,category='physical',effectiveness=1,stab=1,attack=20,defense=20)
    result.update(values);return result

class PreparationTests(unittest.TestCase):
    def journey(self,**config):return BrockJourney(None,'/private/tmp',config)
    def test_all_three_original_starters_and_all_native_integer_budget_boundaries(self):
        for starter in FAMILIES:
            self.assertEqual(self.journey(starter=starter).starter,starter)
        for count in [1,254,255,256]:self.journey(max_training_battles=count)
        for config in [dict(starter='pikachu'),dict(max_training_battles=True),dict(max_training_battles=257),dict(training_level=15),dict(max_blackouts=3),dict(evolution_policy='force')]:
            with self.subTest(config=config),self.assertRaises(ProtocolError):self.journey(**config)
    def test_fixed_dragon_rage_uses_actual_accuracy_pp_and_dragon_immunity(self):
        fixed=move('dragonRage',power=0,category='special',effective_accuracy=50)
        self.assertEqual(move_score(fixed,16),20)
        self.assertEqual(move_score(dict(fixed,effectiveness=0),16),0)
        self.assertEqual(move_score(dict(fixed,pp=0),16),0)
        del fixed['effective_accuracy']
        with self.assertRaisesRegex(ProtocolError,'effective_accuracy'):move_score(fixed)
    def test_legal_choice_uses_stage_adjusted_accuracy_and_actual_effective_stats(self):
        reliable=move(index=1,power=40)
        strong=move('waterGun',index=2,power=100,effective_accuracy=10)
        self.assertEqual(choose_move([reliable,strong],16)['index'],1)
        strong.update(effective_accuracy=100,attack=60)
        self.assertEqual(choose_move([reliable,strong],16)['index'],2)
        self.assertEqual(move_score(move('fissure',power=0,ohko=True),16),0)
    def test_learning_keeps_fixed_damage_over_status_and_does_not_invent_move(self):
        self.assertEqual(learn_decision(move('dragonRage',power=0),[move('growl',power=0,category='status'),move()]),1)
        self.assertIsNone(learn_decision(move('growl',power=0,category='status'),[move()]))
    def test_default_evolution_accepts_real_animation_explicit_cancel_is_separate(self):
        from tools.tests.test_brock_evolution_evidence import evolution_trace
        for policy in ['accept','cancel']:
            journey,commands,_=evolution_trace(policy);journey.evolution()
            self.assertEqual(journey.summary['evolutions'][0]['policy'],policy)
            self.assertEqual(journey.summary['evolutions'][0]['result'],'complete'if policy=='accept'else'cancelled')
            self.assertEqual(commands.count('press b'),int(policy=='cancel'))
            self.assertEqual(sum(command.startswith('record ')for command in commands),int(policy=='accept'))
    def test_training_budget_254_and_256_are_actual_calls_and_fail_without_new_battle(self):
        journey=self.journey(max_training_battles=256);journey.party=lambda:[];journey.state={};journey.training_mode='train'
        journey.summary['training']=[{}for _ in range(254)];calls=[]
        def battle(name,expected):calls.append(name);journey.state={'last_battle_outcome':{'kind':'victory'}}
        journey.battle=battle;journey.training_battle();journey.training_battle()
        with self.assertRaisesRegex(ProtocolError,'256/256'):journey.training_battle()
        self.assertEqual(calls,['preparation-255','preparation-256'])
    def test_real_training_loss_keeps_failure_evidence(self):
        journey=self.journey();journey.party=lambda:[];journey.training_mode='train';journey.state={}
        def battle(*args,**kwargs):
            outcome={'kind':'defeat','blackout':True};journey.state={'last_battle_outcome':outcome}
            journey.summary['battles'].append({'name':'preparation-1','outcome':outcome});raise NaturalBlackout('actual defeat')
        journey.battle=battle
        with self.assertRaises(NaturalBlackout):journey.training_battle()
        self.assertEqual(journey.summary['training'][0]['outcome']['kind'],'defeat')
    def test_blocked_switch_falls_through_to_attack_without_party_menu_retry_loop(self):
        journey=self.journey();journey.state={'session':{'party':{'active':2}}};journey.starter_index=lambda:1;journey.switch_back=True
        journey.battle_switch=lambda *args:False;journey.party=lambda:[{'hp':24},{'hp':5}]
        self.assertFalse(journey.battle_preparation_action({'trainerName':'JR'},['FIGHT','POKEMON']))
        self.assertTrue(journey.switch_back)
    def test_grass_lane_requires_reciprocal_legal_cells_and_excludes_occupancy(self):
        model=Geometry('route',[[0]*4,[0]*4],grass=[[True]*4,[False]*4])
        self.assertEqual(training_lane(model,(0,0),{(1,0)}),((2,0),(3,0)))
    def test_navigation_respects_both_native_npc_midstep_reservations(self):
        journey=self.journey();journey.state={'npcs':[{'x':4,'y':2,'motion':{'phase':'moving','origin_x':3,'origin_y':2,'target_x':4,'target_y':2}}]}
        self.assertEqual(journey.occupied(),{(3,2),(4,2)})
        del journey.state['npcs'][0]['motion']['origin_x']
        with self.assertRaises(ProtocolError):journey.occupied()

    def test_unreachable_or_single_grass_lane_fails_before_input(self):
        for model in [Geometry('route',[[0,1,0,0]],grass=[[False,False,True,True]]),Geometry('route',[[0]],grass=[[True]])]:
            with self.assertRaisesRegex(ProtocolError,'grass lane'):training_lane(model,(0,0),set())

class RestartPreparationTests(unittest.TestCase):
    def scenario(self,**values):
        return {'processes':[{'journey':dict(name='brock-natural',**values)},{'restart':True,'journey':{'name':'brock-continue'}}]}
    def test_three_starters_training_tail_and_current_motion_schema_compatible(self):
        for starter in FAMILIES:
            restarting.validate(self.scenario(starter=starter,max_training_battles=256,training_level=16,max_capture_attempts=24,max_blackouts=1,evolution_policy='accept'))
        restarting.validate({'processes':[{'journey':{'name':'npc-motion-save','location':'pewter-mart'}},{'restart':True,'journey':{'name':'npc-motion-continue'}}]})
    def test_bad_budgets_and_cross_journey_options_rejected(self):
        for options in [dict(max_training_battles=257),dict(max_training_battles=True),dict(starter='mew'),dict(training_level=21),dict(evolution_policy='force')]:
            with self.subTest(options=options),self.assertRaises(ProtocolError):restarting.validate(self.scenario(**options))
        scenario={'processes':[{'journey':{'name':'npc-motion-save','location':'pewter-mart','training_level':16}},{'restart':True,'journey':{'name':'npc-motion-continue'}}]}
        with self.assertRaises(ProtocolError):restarting.validate(scenario)

class SuiteBudgetTests(unittest.TestCase):
    def test_only_actual_named_campaign_gets_large_bounded_default_and_override_wins(self):
        with tempfile.TemporaryDirectory()as folder:
            path=Path(folder)/'case.json'
            for scenario,expected in [({'journey':{'name':'brock-natural'}},3600),({'processes':[{'journey':{'name':'brock-natural'}}]},3600),({'journey':{'name':'brock-supplementary'}},240),({'journey':{'name':'npc-motion-save'}},240),({'commands':['snapshot']},240)]:
                path.write_text(json.dumps(scenario));job={'scenario':path}
                self.assertEqual(suite.job_timeout(job),expected);self.assertEqual(suite.job_timeout(job,17),17)
            for value in [0,-1,float('nan'),float('inf'),True]:
                with self.assertRaises(ProtocolError):suite.job_timeout({},value)
            self.assertEqual(suite.job_timeout({'name':'brock-natural'}),240)

if __name__=='__main__':unittest.main()

class CaptureAndRecoveryTests(unittest.TestCase):
    def capture_journey(self,caught=False,consume=True):
        journey=BrockJourney(None,'/private/tmp',{});journey.training_mode='capture';journey.capture_pending=True
        members=[{'species':'squirtle','hp':24}];stock={'money':1000,'quantities':{'pokeBall':2},'slots':[{'id':'pokeBall','quantity':2}]}
        journey.state={'root':'battle','session':{'party':{'active':1}}};journey.party=lambda:members;journey.inventory=lambda:stock;journey.quantity=lambda id:stock['quantities'].get(id,0)
        journey.select=lambda *args:None;commands=[]
        def send(command):
            commands.append(command)
            if command.startswith('record '):return
            if journey.state['root']=='battle':journey.state['root']='bag'
            else:
                journey.state.update(root='battle',battle={'capture_result':{'caught':caught,'checks':4 if caught else 1}})
                if consume:stock['quantities']['pokeBall']-=1
                if caught:members.append({'species':'pidgey','hp':5})
        journey.send=send
        battle={'trainerName':None,'player':{'level':6,'hp':24,'maxHP':24},'enemy':{'species':'pidgey','level':2,'hp':5,'maxHP':10},'legal_moves':[move()]}
        return journey,battle,commands
    def test_actual_failed_ball_consumes_one_and_keeps_capture_goal_pending(self):
        journey,battle,commands=self.capture_journey()
        self.assertTrue(journey.battle_preparation_action(battle,['FIGHT','BAG','POKEMON','RUN']))
        self.assertEqual(commands,['press a','press a','record brock-capture-1 48']);self.assertTrue(journey.capture_pending)
        self.assertFalse(journey.summary['captures'][0]['result']['caught']);self.assertEqual(journey.quantity('pokeBall'),1)
    def test_actual_caught_result_requires_owned_reserve_and_consumed_ball(self):
        journey,battle,commands=self.capture_journey(caught=True)
        journey.battle_preparation_action(battle,['FIGHT','BAG','POKEMON','RUN'])
        self.assertFalse(journey.capture_pending);self.assertEqual(len(journey.party()),2)
        journey,battle,commands=self.capture_journey(caught=True,consume=False)
        with self.assertRaisesRegex(ProtocolError,'consume exactly one'):journey.battle_preparation_action(battle,['FIGHT','BAG','POKEMON','RUN'])
    def test_healthy_target_is_weakened_with_real_move_unless_ko_risk(self):
        journey,battle,commands=self.capture_journey();battle['enemy'].update(hp=30,maxHP=30);battle['player']['stat_stages']={'acc':0}
        self.assertFalse(journey.battle_preparation_action(battle,['FIGHT','BAG','POKEMON','RUN']));self.assertEqual(commands,[])
        battle['enemy'].update(hp=3,maxHP=3)
        self.assertTrue(journey.battle_preparation_action(battle,['FIGHT','BAG','POKEMON','RUN']))
    def test_true_blackout_validates_half_money_checkpoint_healing_and_retry_bound(self):
        journey=BrockJourney(None,'/private/tmp',{'max_blackouts':1})
        journey.summary['battles']=[{'trainer_id':'source-jr','money_before':1995,'outcome':{'won':False,'blackout':True,'money_delta':-998}}]
        journey.state={'zone_id':'pewter','player':{'x':13,'y':26},'session':{'checkpoint':{'zone_id':'pewter','x':13,'y':26}}}
        journey.inventory=lambda:{'money':997};journey.party=lambda:[{'hp':30,'maxHP':30,'status':'none','pp':{'tackle':35},'maxPP':{'tackle':35}}];journey.checkpoint=lambda name:None
        journey.recover_blackout();self.assertEqual(journey.summary['blackouts'][0]['kind'],'actual-defeat-not-victory')
        with self.assertRaisesRegex(ProtocolError,'exhausted'):journey.recover_blackout()
    def test_identified_source_training_lanes_are_real_blue_grass_not_door_shortcuts(self):
        import os
        from tools.harness.brock_journey import load_models,MAPS
        root=Path(os.environ['PARCEL_BUNDLE_SOURCE']);models,doors,trainers=load_models(root)
        self.assertEqual(len(models),14);self.assertEqual(len(trainers),5)
        for name in ['Route2','ViridianForest']:
            model=models[MAPS[name]]
            origin=next((x,y)for y,row in enumerate(model.collision)for x,blocked in enumerate(row)if not blocked and model.grass[y][x])
            a,b=training_lane(model,origin,set())
            self.assertTrue(model.grass[a[1]][a[0]]and model.grass[b[1]][b[0]])
            self.assertIsInstance(model.path(origin,{a}),list);self.assertEqual(abs(a[0]-b[0])+abs(a[1]-b[1]),1)

class CampaignPlanTests(unittest.TestCase):
    def test_stage_registers_all_three_true_restarts_and_single_process_routes(self):
        from unittest.mock import patch
        stage=Path(__file__).resolve().parents[2]
        expected={'brock--brock-restart','brock--brock-restart-bulbasaur','brock--brock-restart-charmander'}
        with patch.object(suite,'PROJECT',stage):
            jobs=suite.select_jobs(sorted(expected));self.assertEqual({job['name']for job in jobs},expected)
            for job in jobs:
                data=json.loads(job['scenario'].read_text());restarting.validate(data)
                self.assertEqual(data['processes'][0]['journey']['evolution_policy'],'accept')
                self.assertEqual(suite.job_timeout(job),3600)
    def test_plan_records_actual_campaign_and_regular_deadlines_without_launch_or_retry(self):
        from argparse import Namespace
        from unittest.mock import patch
        with tempfile.TemporaryDirectory()as folder:
            root=Path(folder);campaign=root/'campaign.json';campaign.write_text(json.dumps({'journey':{'name':'brock-natural'}}))
            regular=root/'regular.json';regular.write_text(json.dumps({'commands':['snapshot']}))
            for override in [None,9]:
                output=root/str(override)
                args=Namespace(output=str(output),only=None,mutations=False,plan_only=True,continue_on_failure=False,job_timeout=override,sdk=None)
                jobs=[{'name':'campaign','scenario':campaign},{'name':'regular','scenario':regular}]
                with patch.object(suite,'select_jobs',return_value=jobs):
                    suite.execute_suite(args,launch=lambda *args:self.fail('plan launched runtime'))
                plan=json.loads((output/'suite-plan.json').read_text())
                self.assertEqual([job['job_timeout_seconds']for job in plan['jobs']],[3600,240]if override is None else[9,9])
                self.assertFalse(json.loads((output/'suite.json').read_text())['ok'])
