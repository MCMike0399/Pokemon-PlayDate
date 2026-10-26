"""Pinned-source/generator checks only. Runtime cases are real SDK contracts."""
import json
import os
from pathlib import Path
import tempfile
import unittest

from tools import generate_cerulean_story as story

ROOT = Path(__file__).resolve().parents[2]


class CeruleanStorySourceTests(unittest.TestCase):
    def test_exact_reproduction_from_vendored_and_external_pinned_source(self):
        expected = story.build()
        for name, raw in expected.items():
            self.assertEqual((ROOT/'Source/data/ceruleanStory'/name).read_bytes(), raw)
        reference = Path(os.environ['POKERED_REFERENCE_DIR'])
        self.assertEqual(story.build(reference), expected)

    def test_modified_source_is_rejected_before_generation(self):
        with tempfile.TemporaryDirectory() as folder:
            import shutil
            reference = Path(folder)/'reference'
            shutil.copytree(story.REFERENCE, reference)
            target = reference/'scripts/BillsHouse.asm'
            target.write_bytes(target.read_bytes().replace(b'S_S_TICKET', b'MASTER_BALL'))
            with self.assertRaisesRegex(ValueError, 'unverified pinned story source'):
                story.build(reference)

    def test_stable_object_ids_match_source_order_and_pc_hidden_event(self):
        sources = story.verified(story.REFERENCE)
        events = json.loads(story.build()['events.json'])['events']
        expected = {'BILLS_HOUSE':('BillsHouse',[1,2,3]),
                    'MT_MOON_B2F':('MtMoonB2F',[1,6,7]),
                    'CERULEAN_GYM':('CeruleanGym',[1])}
        for map_id, (name, indices) in expected.items():
            rows = [line.strip() for line in sources[f'data/maps/objects/{name}.asm'].splitlines()
                    if line.strip().startswith('object_event ')]
            for index in indices:
                self.assertIn(f'pokered:{map_id}:objects:{index}', events)
                if name == 'MtMoonB2F' and index in [6,7]:
                    self.assertIn('SPRITE_FOSSIL', rows[index-1])
        self.assertIn('hidden_event  1,  4, BillsHousePC, SPRITE_FACING_UP', sources['data/events/hidden_events.asm'])
        self.assertIn(story.PC, events)
        self.assertEqual(len(events), 8)

    def test_rosters_and_payouts_independent_source_rows(self):
        data = json.loads(story.build()['trainers.json'])['trainers']
        sources = story.verified(story.REFERENCE)
        self.assertIn('db 12, GRIMER, VOLTORB, KOFFING, 0', sources['data/trainers/parties.asm'])
        self.assertIn('db $FF, 18, STARYU, 21, STARMIE, 0', sources['data/trainers/parties.asm'])
        self.assertEqual(data[story.MOON+'1']['party'],[
            {'species':'grimer','level':12},{'species':'voltorb','level':12},{'species':'koffing','level':12}])
        self.assertEqual(data[story.MISTY]['party'],[{'species':'staryu','level':18},{'species':'starmie','level':21}])
        self.assertEqual(data[story.MISTY]['payout'],2079)
        self.assertEqual(data[story.MOON+'1']['payout'],300)

    def test_source_movement_fallthrough_and_player_detour(self):
        movement = json.loads(story.build()['scenes.json'])['movement']
        self.assertEqual(movement['nerd_dome'],['right','up'])
        self.assertEqual(movement['nerd_helix'],['up'])
        self.assertEqual(movement['bill_enter'],['up']*3)
        self.assertEqual(movement['bill_around'],['right','up','up','left','up'])
        self.assertEqual(movement['bill_exit'],['down','right','right','right','down'])

    def test_only_two_source_machine_cells_have_script_collision_exceptions(self):
        events = json.loads(story.build()['events.json'])['events']
        exceptions = {identity:d['script_collision_positions'] for identity,d in events.items()
                      if d.get('script_collision_positions')}
        self.assertEqual(exceptions, {
            story.BILL+'1':[{'x':6,'y':2}],story.BILL+'2':[{'x':1,'y':2}]})
        for identity, positions in exceptions.items():
            for position in positions:
                self.assertIn(position,events[identity]['script_positions'])

    def test_misty_rewards_and_source_labels_preserve_source_case(self):
        artifacts = story.build()
        events = json.loads(artifacts['events.json'])['events']
        texts = json.loads(artifacts['dialogue.json'])['texts']
        misty = events[story.MISTY]
        self.assertEqual(misty['reward']['item'],'tm11')
        self.assertEqual(misty['victory']['flags'], {'BADGE_CASCADE':True,'EVENT_BEAT_MISTY':True})
        self.assertNotIn('EVENT_GOT_TM11', misty['victory']['flags'])
        self.assertIn('_MtMoonB2fSuperNerdEachTakeOneText',texts)
        for label in [*misty['won'],*misty['before'],*misty['after'],*misty['reward']['success'],
                      '_SSTicketReceivedText','_BillsHouseInitiatedText','_MtMoonB2FReceivedFossilText']:
            self.assertIn(label,texts)
        self.assertEqual(texts['_SSTicketReceivedText']['recipe'][2]['symbol'],'wStringBuffer')
