"""Primary-source/generator checks. Gameplay executes only in the actual SDK."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from tools import generate_vermilion_story as story

ROOT = Path(__file__).resolve().parents[2]


class VermilionStoryPins(unittest.TestCase):
    def setUp(self):
        self.sources = story.verified()
        self.output = {name:json.loads(raw) for name,raw in story.build().items()}

    def test_exact_generation_and_external_pinned_reference(self):
        for name,raw in story.build().items():
            self.assertEqual((ROOT/'Source/data/vermilionStory'/name).read_bytes(),raw)
        # Required source environment, never silently skip independent input.
        self.assertEqual(story.build(Path(os.environ['POKERED_REFERENCE_DIR'])),story.build())

    def test_pin_every_consumed_original_and_reject_mutated_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            ref=Path(directory)/'reference';shutil.copytree(story.REFERENCE,ref)
            target=ref/'engine/events/hidden_events/vermilion_gym_trash.asm'
            target.write_bytes(target.read_bytes().replace(b'and $e',b'and $f'))
            with self.assertRaisesRegex(ValueError,'unverified pinned Vermilion source'):
                story.build(ref)
        pin=json.loads((story.REFERENCE/'manifest.json').read_text())
        for path,digest in pin['files'].items():
            self.assertEqual(hashlib.sha256((story.REFERENCE/path).read_bytes()).hexdigest(),digest)

    def test_global_asm_label_boundaries_and_literal_utf8(self):
        source='_First::\n\ttext "POKéMON!"\n\tdone\nRoutine:\n\tld a, 3\n.local:\n\tret\n_Second::\n\ttext "¥"\n\tdone\n'
        recipes=story.recipes(source)
        self.assertEqual([r.get('text') for r in recipes['_First'] if 'text' in r],['POKéMON!'])
        self.assertFalse(any('ld a' in r.get('source','') for r in recipes['_First']))
        self.assertIn('.local:',story.global_block(source,'Routine'))
        self.assertNotIn('_Second',story.global_block(source,'Routine'))
        encoded=story.encoded({'text':'POKéMON ¥'})
        self.assertIn('é'.encode(),encoded);self.assertNotIn(b'\\u00e9',encoded)

    def test_original_three_counter_teams_levels_and_payouts(self):
        teams=self.output['trainers.json']['trainers'][story.RIVAL]['rival_parties']
        for starter,evolved in [('charmander','wartortle'),('squirtle','ivysaur'),('bulbasaur','charmeleon')]:
            self.assertEqual(teams[starter]['party'],[
                {'species':'pidgeotto','level':19},{'species':'raticate','level':16},
                {'species':'kadabra','level':18},{'species':evolved,'level':20}])
            self.assertEqual(teams[starter]['payout'],1300)
        surge=self.output['trainers.json']['trainers'][story.SURGE]
        self.assertEqual(surge['party'],[{'species':'voltorb','level':21},{'species':'pikachu','level':18},{'species':'raichu','level':24}])
        self.assertEqual(surge['payout'],2376)
        self.assertEqual(surge['sprite_source'],'SPRITE_ROCKER')
        self.assertIn('SPRITE_ROCKER',self.sources['data/maps/objects/VermilionGym.asm'])

    def test_source_paths_preserve_local_label_fallthrough(self):
        variants=self.output['scenes.json']['scenes']['rival']['variants']
        self.assertEqual([v['trigger'] for v in variants],[{'x':36,'y':8},{'x':37,'y':8}])
        self.assertEqual(variants[0]['approach'],['down']*3)
        self.assertEqual(variants[1]['approach'],['down']*4)
        self.assertEqual(variants[0]['departure'],['right']+['down']*5)
        self.assertEqual(variants[1]['departure'],['down']*4)
        positions=self.output['events.json']['events'][story.RIVAL]['script_positions']
        self.assertNotIn({'x':36,'y':4},positions)  # Actual captain warp is not a placement exception.
        self.assertIn({'x':36,'y':5},positions)  # Narrow root lease-transit extension required.

    def test_all_fifteen_hidden_target_identities_in_source_order(self):
        trash=self.output['scenes.json']['scenes']['trash']
        self.assertEqual(trash['count'],15)
        for i,can in enumerate(trash['cans']):
            self.assertEqual(can,{'x':1+2*(i//3),'y':7+2*(i%3),'index':i,
                                  'id':f'pokered:VERMILION_GYM:hidden_events:{i+4}'})
        self.assertIn('call CheckIfCoordsInFrontOfPlayerMatch',self.sources['engine/overworld/hidden_events.asm'])
        self.assertEqual(trash['table'][4],[4,1,3,5,7])
        source=self.sources['engine/events/hidden_events/vermilion_gym_trash.asm']
        self.assertIn('swap a',source);self.assertIn('and b\n\tdec a',source)
        self.assertIn('one of the zero bytes',source)

    def test_source_entry_reset_and_exit_conditions(self):
        city=story.global_block(self.sources['scripts/VermilionCity.asm'],'VermilionCity_Script')
        self.assertIn('.setFirstLockTrashCanIndex',city)
        self.assertIn('and $e',city)
        self.assertNotIn('ResetEvent EVENT_1ST_LOCK_OPENED',city)
        self.assertNotIn('ResetEvent EVENT_2ND_LOCK_OPENED',self.sources['scripts/VermilionGym.asm'])
        dock=story.global_block(self.sources['scripts/VermilionDock.asm'],'VermilionDock_Script')
        self.assertIn('CheckEventReuseHL EVENT_GOT_HM01',dock)
        self.assertIn('ld a, [wDestinationWarpID]\n\tcp $1',dock)
        self.assertIn('SetEventForceReuseHL EVENT_SS_ANNE_LEFT',self.sources['scripts/VermilionDock.asm'])
        self.assertIn('warp_event 27,  0, VERMILION_DOCK, 2',self.sources['data/maps/objects/SSAnne1F.asm'])

    def test_captain_full_bag_and_surge_reward_source_order(self):
        captain=self.sources['scripts/SSAnneCaptainsRoom.asm']
        self.assertIn('SetEvent EVENT_RUBBED_CAPTAINS_BACK',captain)
        gift=story.global_block(captain,'SSAnneCaptainsRoomCaptainText')
        self.assertLess(gift.index('call GiveItem'),gift.index('SetEvent EVENT_GOT_HM01'))
        self.assertIn('jr nc, .bag_full',gift)
        surge=self.output['events.json']['events'][story.SURGE]
        self.assertEqual(surge['reward']['item'],'tm24')
        self.assertTrue(surge['victory']['flags']['BADGE_THUNDER'])
        self.assertEqual(len(surge['victory']['trainers']),3)
        self.assertEqual(surge['reward']['flag'],'EVENT_GOT_TM24')

    def test_exact_script_block_projection_and_missing_closed_door_dependency(self):
        effects=self.output['terrain.json']['effects']
        self.assertEqual(effects['gym-close']['block'],36)
        self.assertEqual(effects['gym-close']['targets'],[{'x':2,'y':2}])
        self.assertEqual(effects['gym-close']['keys'][:2],['pokered:GYM:cell:20-21-30-31']*2)
        self.assertEqual(effects['gym-open']['keys'],['pokered:GYM:cell:11-11-11-11']*4)
        self.assertEqual(effects['ship-departed']['targets'],[{'x':x,'y':2} for x in [5,6,7,8]])
        self.assertEqual(effects['ship-departed']['keys'],['pokered:SHIP_PORT:cell:14-14-14-14']*4)
        self.assertIn('lb bc, 2, 2',self.sources['scripts/VermilionGym.asm'])

    def test_prepared_restarts_use_distinct_processes_and_no_second_fixture(self):
        for name in ['puzzle-real-restart.json','ship-real-exit-restart.json']:
            scenario=json.loads((ROOT/'tools/harness/scenarios/vermilion-story'/name).read_text())
            first,second=scenario['processes']
            self.assertTrue(second['restart'])
            self.assertEqual(first['requests'][0][0]['op'],'fixture')
            self.assertNotIn('fixture',json.dumps(second))
            self.assertIn('observe saved',json.dumps(first))
            self.assertIn('observe loaded',json.dumps(second))
            self.assertNotIn('quest_flags',json.dumps(second))

    def test_only_bespoke_text_and_events_no_ordinary_roster_duplication(self):
        texts=self.output['dialogue.json']['texts']
        self.assertNotIn('_SSAnne2FWaiterText',texts)
        self.assertNotIn('_VermilionGymGentlemanBattleText',texts)
        self.assertIn('_SSAnne2FRivalVictoryText',texts)
        self.assertIn('_VermilionGymTrashSuccessText3',texts)
        self.assertEqual(set(self.output['trainers.json']['trainers']),{story.SURGE,story.RIVAL})
        self.assertEqual(len(self.output['events.json']['events']),20)

    def test_all_source_recipe_line_numbers_and_global_boundaries(self):
        for label,record in self.output['dialogue.json']['texts'].items():
            source=self.sources[record['source']];block=story.global_block(source,label)
            for operation in record['recipe']:
                line=source.splitlines()[operation['source_line']-1].strip()
                self.assertTrue(line,operation)
                if 'text' in operation:
                    self.assertIn('"'+operation['text']+'"',line)
                self.assertNotRegex(operation.get('source',''),r'^(ld|call|ret|jp|jr) ')
            self.assertNotRegex(block,r'^_[A-Za-z0-9_]+::')

if __name__=='__main__': unittest.main()
