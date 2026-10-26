"""Validate declarative content, never execute rewritten Lua or simulate the SDK."""
import copy
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
DATA = ROOT / 'Source/data'


def descriptors(value):
    yield value
    if value['kind'] == 'cases':
        for branch in value['cases']:
            yield from descriptors(branch['then'])
        yield from descriptors(value['otherwise'])


def labels(value):
    for key, child in value.items():
        if key in {'labels', 'before', 'after', 'won', 'success', 'full', 'completed'}:
            if isinstance(child, list):
                yield from child
            elif isinstance(child, str):
                yield child
        elif key in {'welcome', 'prompt', 'farewell'}:
            yield child
        elif isinstance(child, dict):
            yield from labels(child)
        elif isinstance(child, list):
            for row in child:
                if isinstance(row, dict):
                    yield from labels(row)


def validate(data):
    assert data['schema'] == 1 and data['source_revision'] == REVISION
    for event_id, event in data['events'].items():
        assert event_id.startswith('pokered:') and len(event_id.split(':')) == 4
        assert event['content'] in {'viridian', 'pewter'}
        text = json.loads((DATA / (event['content'] + 'Slice') / 'dialogue.json').read_text())['texts']
        assert set(labels(event)) <= text.keys(), event_id
        for d in descriptors(event):
            assert d['kind'] in {'program', 'gift', 'pickup', 'trainer', 'cases', 'bespoke'}
            if 'steps' in d or 'prefix' in d:
                steps = d.get('steps', d.get('prefix', []))
                assert len(steps) <= 16
                for index, step in enumerate(steps):
                    assert step['op'] in {'dialog', 'give-item', 'battle', 'move', 'move-npc', 'set-flag', 'heal', 'shop', 'warp', 'receipt'}
                    if step['op'] in {'move', 'move-npc'}:
                        assert step['direction'] in {'up', 'down', 'left', 'right'}
                        assert type(step['count']) is int and 1 <= step['count'] <= 8
                    if step['op'] == 'warp':
                        assert index == len(steps) - 1
            if d['kind'] in {'gift', 'pickup'}:
                assert d['item'] and d['flag'] and d['success']
            if d['kind'] == 'trainer':
                assert d['before'] and d['won'] and d['after']
                if 'reward' in d:
                    assert d['reward']['full'] and d['reward']['success']


class SourceEventDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((DATA / 'sourceEvents.json').read_text())
        cls.events = cls.data['events']

    def test_complete_reviewed_registry_and_original_text(self):
        validate(self.data)
        self.assertEqual(len(self.events), 59)
        self.assertEqual(sum(e['content'] == 'viridian' for e in self.events.values()), 19)
        self.assertEqual(sum(e['content'] == 'pewter' for e in self.events.values()), 40)

    def test_object_and_sign_ids_exist_in_pinned_map_data(self):
        source_ids = set()
        for region in ['viridianSlice', 'pewterSlice']:
            for path in (DATA / region).glob('*.json'):
                source = json.loads(path.read_text())
                if isinstance(source.get('events'), dict):
                    for group in source['events'].values():
                        source_ids.update(e['id'] for e in group)
        for event_id in self.events:
            if ':objects:' in event_id or ':background_events:' in event_id:
                self.assertIn(event_id, source_ids)

    def test_pickups_keep_source_items_and_stable_flags(self):
        expected = {
            'pokered:ROUTE_2:objects:1': 'moonStone',
            'pokered:ROUTE_2:objects:2': 'hpUp',
            'pokered:VIRIDIAN_FOREST:objects:5': 'antidote',
            'pokered:VIRIDIAN_FOREST:objects:6': 'potion',
            'pokered:VIRIDIAN_FOREST:objects:7': 'pokeBall',
            'pokered:VIRIDIAN_FOREST:hidden:1': 'potion',
            'pokered:VIRIDIAN_FOREST:hidden:2': 'antidote',
        }
        actual = {key: d['item'] for key, d in self.events.items() if d['kind'] == 'pickup'}
        self.assertEqual(actual, expected)
        for event_id in actual:
            self.assertEqual(self.events[event_id]['flag'], 'PICKUP:' + event_id)

    def test_trainers_cover_same_pinned_rosters_and_dialogue(self):
        trainers = json.loads((DATA / 'pewterSlice/trainers.json').read_text())['trainers']
        self.assertEqual({d['id'] for d in trainers}, {key for key, d in self.events.items() if d['kind'] == 'trainer'})
        for trainer in trainers:
            if trainer['class_source'] != 'OPP_BROCK':
                event = self.events[trainer['id']]
                for key in ['before', 'won', 'after']:
                    self.assertEqual(event[key], ['_' + trainer['dialogue_script_labels'][key]])

    def test_brock_reward_and_victory_effects_remain_separate(self):
        brock = self.events['pokered:PEWTER_GYM:objects:1']
        self.assertEqual(brock['reward']['item'], 'tm34')
        self.assertEqual(brock['reward']['flag'], 'EVENT_GOT_TM34')
        self.assertEqual(brock['reward']['full_status'], 'tm-full-retry')
        self.assertEqual(brock['victory']['trainers'], {'pokered:PEWTER_GYM:objects:2': True})
        self.assertEqual(brock['victory']['flags'], {'BADGE_BOULDER': True, 'EVENT_1ST_ROUTE22_RIVAL_BATTLE': False, 'EVENT_ROUTE22_RIVAL_WANTS_BATTLE': False})

    def test_only_oak_is_bespoke_and_no_new_story_operations(self):
        self.assertEqual([key for key, d in self.events.items() if d['kind'] == 'bespoke'], ['pokered:OAKS_LAB:script:parcel-handoff'])
        self.assertFalse(any(step['op'] in {'warp', 'move-npc'} for event in self.events.values() for d in descriptors(event) for step in d.get('steps', [])))

    def test_mart_quest_and_source_movement_order(self):
        entry = self.events['pokered:VIRIDIAN_MART:script:entry']
        self.assertEqual(entry['cases'][0]['then']['status'], 'shop-available')
        self.assertEqual(entry['otherwise']['prefix'][1:], [{'op': 'move', 'direction': 'up', 'count': 2}, {'op': 'move', 'direction': 'left', 'count': 1}])
        self.assertEqual(entry['otherwise']['flag'], 'EVENT_GOT_OAKS_PARCEL')
        self.assertEqual(entry['otherwise']['full'], ['_ViridianMartClerkParcelQuestText'])

    def test_validator_rejects_unknown_text_and_unbounded_movement(self):
        mutated = copy.deepcopy(self.data)
        mutated['events']['pokered:ROUTE_1:objects:2']['steps'][0]['labels'] = ['_InventedText']
        with self.assertRaises(AssertionError):
            validate(mutated)
        mutated = copy.deepcopy(self.data)
        mutated['events']['pokered:VIRIDIAN_MART:script:entry']['otherwise']['prefix'][1]['count'] = 9
        with self.assertRaises(AssertionError):
            validate(mutated)
