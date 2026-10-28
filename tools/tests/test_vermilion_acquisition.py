"""Host boundaries for real-input collection and a proposed supplementary overlay.

No Lua execution, battle/RNG simulation, encounters or claimed native outcomes.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import generate_vermilion_journey as generator
from tools.harness import cerulean_journey as cj, vermilion_journey as vj, restarting
from tools.harness.protocol import ProtocolError
from tools.tests.test_vermilion_journey import NoRuntime, journey, CASES, ROOT


def owner(species, box=3):
    return {'kind': 'vermilion-collection', 'party': {'version': 1, 'active': 1,
             'members': [{'species': s, 'xp': 300, 'hp': 20, 'moves': ['tackle']} for s in species]},
            'storage': {'version': 1, 'active': box, 'boxes': [[] for _ in range(12)]},
            'owned': {s: True for s in species}}


def caught(before, species):
    after = copy.deepcopy(before)
    after['owned'][species] = True
    mon = {'species': species, 'xp': 200, 'hp': 18, 'moves': ['tackle']}
    if len(before['party']['members']) < 6:
        after['party']['members'].append(mon)
        destination = {'destination': 'party', 'index': len(after['party']['members'])}
    else:
        box = before['storage']['active']
        after['storage']['boxes'][box - 1].append(mon)
        destination = {'destination': 'storage', 'box': box, 'index': len(after['storage']['boxes'][box - 1])}
    return after, {'caught': True, 'destination': destination}


class RecruitmentBoundaryTests(unittest.TestCase):
    def test_party_capture_requires_actual_append_and_new_owned_flag(self):
        before = owner(['wartortle', 'rattata'])
        before['owned']['squirtle'] = True
        after, result = caught(before, 'bellsprout')
        self.assertEqual(vj.verify_capture_commit(before, after, 'bellsprout', result), result['destination'])
        for mutate in (
            lambda v: v['owned'].pop('bellsprout'),
            lambda v: v['party']['members'].pop(),
            lambda v: v['party'].update(active=2),
            lambda v: v['owned'].update(abra=True),
        ):
            invalid = copy.deepcopy(after)
            mutate(invalid)
            with self.assertRaises(ProtocolError):
                vj.verify_capture_commit(before, invalid, 'bellsprout', result)

    def test_full_party_capture_verifies_selected_box_and_preserves_party(self):
        before = owner(['wartortle', 'rattata', 'bellsprout', 'caterpie', 'metapod', 'pidgey'])
        before['storage']['boxes'][2] = [{'species': 'sandshrew', 'xp': 100}]
        before['owned']['sandshrew'] = True
        after, result = caught(before, 'meowth')
        self.assertEqual(result['destination'], {'destination': 'storage', 'box': 3, 'index': 2})
        self.assertEqual(vj.verify_capture_commit(before, after, 'meowth', result), result['destination'])
        self.assertEqual(len(after['party']['members']), 6)
        for destination in ({'destination': 'party', 'index': 7}, {'destination': 'storage', 'box': 1, 'index': 2},
                            {'destination': 'storage', 'box': 3, 'index': 1}, {'destination': 'storage', 'box': True, 'index': 2}):
            with self.subTest(destination=destination), self.assertRaises(ProtocolError):
                vj.verify_capture_commit(before, after, 'meowth', dict(result, destination=destination))
        altered = copy.deepcopy(after)
        altered['storage']['boxes'][0].append({'species': 'pidgey'})
        with self.assertRaisesRegex(ProtocolError, 'another PC box'):
            vj.verify_capture_commit(before, altered, 'meowth', result)

    def test_no_caught_result_or_duplicate_can_become_a_new_capture_receipt(self):
        before = owner(['wartortle', 'rattata'])
        after, result = caught(before, 'bellsprout')
        for invalid in ({'caught': False}, {'caught': True}, {'caught': True, 'destination': {}}):
            with self.assertRaises(ProtocolError):
                vj.verify_capture_commit(before, after, 'bellsprout', invalid)
        with self.assertRaisesRegex(ProtocolError, 'already owned'):
            vj.verify_capture_commit(after, after, 'bellsprout', result)

    def test_collection_ball_input_uses_real_bag_and_accepts_selected_box_commit(self):
        driver = journey()
        driver.vermilion = generator.project(ROOT / 'Source')
        before = owner(['wartortle', 'rattata', 'bellsprout', 'caterpie', 'metapod', 'pidgey'])
        after, result = caught(before, 'meowth')
        driver.acquisition_active = True
        driver.acquisition_targets = {'meowth'}
        driver.collection_battle_balls = 0
        driver.state = {'root': 'battle', 'zone_id': 'pokered:ROUTE_6',
                        'session': {'pokedex': {'owned': before['owned']},
                                    'inventory': {'money': 3000, 'slots': [{'id': 'pokeBall', 'quantity': 20}]}}}
        observations = [before, after]
        driver.observe = lambda kind: observations.pop(0)
        selected, sent = [], []
        driver.select = lambda path, index: selected.append((path, index))
        def send(command):
            sent.append(command)
            if len(sent) == 1:
                driver.state['root'] = 'bag'
            elif len(sent) == 2:
                driver.state['root'] = 'battle'
                driver.state['battle'] = {'capture_result': result}
                driver.state['session']['inventory']['slots'][0]['quantity'] = 19
        driver.send = send
        battle = {'enemy': {'species': 'meowth'}, 'player': {'hp': 20, 'maxHP': 20, 'status': 'none'}}
        self.assertTrue(driver.battle_preparation_action(battle, ['FIGHT', 'BAG', 'POKEMON', 'RUN']))
        self.assertEqual(selected, [('battle.menu.selected', 2), ('bag.selected', 1)])
        self.assertEqual(sent[:2], ['press a', 'press a'])
        self.assertEqual(driver.collection['captures'][0]['commit'], result['destination'])
        self.assertEqual(driver.collection['balls'], 1)
        self.assertEqual(driver.collection['captures'][0]['after_quantity'], 19)

    def test_wild_collection_does_not_misattribute_stale_event_trainer_receipt(self):
        driver = journey()
        driver.acquisition_active = True
        driver.state = {'battle': {'trainerName': None}, 'event': {'id': vj.SURGE}}
        sentinel = object()
        with patch.object(vj.BrockJourney, 'battle', return_value=sentinel) as wild_loop:
            self.assertIs(driver.battle('collection-wild'), sentinel)
            wild_loop.assert_called_once_with(driver, 'collection-wild', 'attack', None)
        driver.state['battle']['trainerName'] = 'LT.SURGE'
        with patch.object(cj.CeruleanJourney, 'battle', return_value=sentinel) as trainer_loop:
            self.assertIs(driver.battle('source-trainer', expected='win'), sentinel)
            trainer_loop.assert_called_once_with('source-trainer', 'attack', 'win')

    def test_full_selected_box_and_missing_owner_records_fail_closed(self):
        before = owner(['wartortle', 'rattata', 'bellsprout', 'caterpie', 'metapod', 'pidgey'])
        before['storage']['boxes'][2] = [{'species': 'pidgey'} for _ in range(20)]
        after, result = caught(before, 'meowth')
        with self.assertRaises(ProtocolError):
            vj.verify_capture_commit(before, after, 'meowth', result)
        for mutation in ({'storage': {}}, {'owned': []}, {'storage': {'version': 1, 'active': True, 'boxes': [[]] * 12}}):
            with self.assertRaises(ProtocolError):
                vj.validate_collection_owner(dict(before, **mutation))


class PlanningBoundaryTests(unittest.TestCase):
    def test_common_blue_tables_and_actual_machine_compatibility_are_projected(self):
        projected = generator.project(ROOT / 'Source')
        self.assertEqual(projected, json.loads((ROOT / 'Source/dev/vermilionJourney.json').read_text()))
        expected = {'Route24': ['bellsprout', 'caterpie', 'metapod', 'pidgey'], 'Route6': ['meowth'],
                    'Route11': ['sandshrew', 'spearow', 'drowzee'], 'DiglettsCave': ['diglett']}
        for name, targets in expected.items():
            policy = projected['collection'][name]
            self.assertEqual(policy['targets'], targets)
            self.assertEqual(sum(policy['weights'].values()), 256)
            self.assertTrue(all(policy['weights'][s] >= 50 for s in targets))
            self.assertNotIn('abra', targets)
        self.assertIn('bellsprout', projected['cut_species'])
        self.assertNotIn('rattata', projected['cut_species'])
        for shop in projected['shops'].values():
            self.assertEqual(shop['prices']['pokeBall'], 200)
            self.assertEqual(shop['sell_prices']['nugget'], 5000)

    def test_projection_rejects_drifted_route24_input_even_with_valid_common_weights(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'Source'
            shutil.copytree(ROOT / 'Source', source)
            target = source / 'data/sourceSlice/Route24.json'
            raw = json.loads(target.read_text())
            raw['encounters']['grass']['slots'][0]['level'] += 1
            target.write_text(json.dumps(raw))
            with self.assertRaisesRegex(ValueError, 'Route24 source map pin'):
                generator.project(source)

    def test_real_prepared_geometry_has_common_grass_lanes_and_honest_cave_gap(self):
        from tools.harness.brock_journey import training_lane
        with tempfile.TemporaryDirectory() as directory:
            build = Path(directory)
            shutil.copytree(ROOT / 'Source', build / 'Source')
            shutil.copyfile(ROOT / 'Source/main.lua', build / 'original-main.lua')
            for source, destination in [('proposed-source-maps', 'sourceMaps'),
                                        ('proposed-compact', 'sourceMapCache/compact'),
                                        ('proposed-tile-grids', 'sourceMapCache/tile-grids')]:
                shutil.copyfile(ROOT / 'Source/data/vermilionPreparation' / (source + '.json'),
                                build / 'Source/data' / (destination + '.json'))
            manifest = {p.relative_to(build / 'Source').as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in (build / 'Source').rglob('*') if p.is_file()}
            (build / 'source-manifest.json').write_text(json.dumps(manifest))
            models, maps, _ = cj.source_models(cj.StagedSource(build))
            for name in ('Route24', 'Route6', 'Route11'):
                entry = maps['maps'][name]
                model = models[entry['id']]
                origin = (entry['spawn']['x'], entry['spawn']['y'])
                occupied = {(e['x'], e['y']) for e in model.events['objects']}
                lane = training_lane(model, origin, occupied)
                self.assertTrue(all(model.grass[y][x] for x, y in lane))
            cave = models[maps['maps']['DiglettsCave']['id']]
            # Current prepared data has slots but no eligible terrain. Do not
            # claim the optional fallback can run until root supplies that seam.
            self.assertFalse(any(any(row) for row in cave.grass))

    def test_cave_lane_uses_actual_zone_eligibility_without_changing_source_model(self):
        from tools.harness.brock_journey import SourceGeometry
        driver = journey()
        model = SourceGeometry('pokered:DIGLETTS_CAVE', [[0] * 40 for _ in range(36)])
        driver.models = {model.name: model}
        driver.state = {'zone_id': model.name, 'player': {'x': 0, 'y': 0}, 'npcs': []}
        driver.observe = lambda kind: {'kind': kind, 'zone_id': model.name, 'cells': []}
        with self.assertRaisesRegex(ProtocolError, 'actual Zone policy has no eligible cells'):
            driver.collection_lane('DiglettsCave')
        driver.observe = lambda kind: {'kind': kind, 'zone_id': model.name,
                                       'cells': [{'x': 35, 'y': 30}, {'x': 35, 'y': 31}]}
        self.assertEqual(set(driver.collection_lane('DiglettsCave')), {(35, 30), (35, 31)})
        self.assertFalse(any(any(row) for row in model.grass))

    def test_vermilion_budget_extension_does_not_change_earlier_bounds(self):
        driver = journey({'name': 'vermilion-natural', 'max_actions': 20000, 'vermilion_actions': 30000})
        self.assertEqual(driver.config['max_actions'], 20000)
        self.assertEqual(cj.BOUNDS['max_actions'], (1, 20000))
        driver.begin_continuation()
        self.assertEqual(driver.config['max_actions'], 50000)
        self.assertEqual(cj.BOUNDS['max_actions'], (1, 20000))
        with self.assertRaises(ProtocolError):
            driver.begin_continuation()
        for key, (low, high) in vj.COLLECTION_BOUNDS.items():
            for invalid in (True, low - 1, high + 1):
                with self.subTest(key=key, invalid=invalid), self.assertRaises(ProtocolError):
                    journey({'name': 'vermilion-natural', key: invalid})

    def test_rare_target_and_late_bellsprout_fail_before_input(self):
        driver = journey()
        driver.vermilion = generator.project(ROOT / 'Source')
        driver.state = {'session': {'party': {'members': [{'species': 'rattata'}] * 6}}}
        with self.assertRaisesRegex(ProtocolError, 'not a pinned common'):
            driver.collect('Route24', ['abra'], 'CeruleanPokecenter', 'CeruleanMart')
        with self.assertRaisesRegex(ProtocolError, 'before filling the party'):
            driver.collect('Route24', ['bellsprout'], 'CeruleanPokecenter', 'CeruleanMart')

    def test_exhausted_collection_step_or_battle_budget_stops_before_input(self):
        for key, count in [('steps', 12000), ('battles', 180)]:
            driver = journey()
            driver.acquisition_active = True
            driver.collection[key] = count
            with self.subTest(key=key), self.assertRaises(ProtocolError):
                driver.step(None)
            self.assertEqual(driver.collection[key], count)

    def test_real_ball_budget_is_enforced_before_bag_command(self):
        driver = journey({'name': 'vermilion-natural', 'collection_balls': 1})
        driver.acquisition_active = True
        driver.acquisition_targets = {'bellsprout'}
        driver.collection['balls'] = 1
        driver.state = {'session': {'pokedex': {'owned': {}}, 'inventory': {'money': 1000, 'slots': []}}}
        battle = {'enemy': {'species': 'bellsprout'}, 'player': {'hp': 20, 'maxHP': 20, 'status': 'none'}}
        with self.assertRaisesRegex(ProtocolError, 'total ball budget'):
            driver.battle_preparation_action(battle, ['FIGHT', 'BAG', 'POKEMON', 'RUN'])

    def test_collection_heals_exhausted_attack_pp_even_with_status_pp_remaining(self):
        driver = journey()
        driver.state = {'session': {'party': {'active': 1, 'members': [
            {'hp': 20, 'maxHP': 20, 'status': 'none', 'moves': ['tackle', 'growl'],
             'pp': {'tackle': 0, 'growl': 40}}]}}}
        driver.observed_moves = {'tackle': {'category': 'physical'}, 'growl': {'category': 'status'}}
        self.assertTrue(driver.collection_needs_healing())
        driver.state['session']['party']['members'][0]['pp']['tackle'] = 10
        self.assertFalse(driver.collection_needs_healing())

    def test_funds_and_purchase_limit_do_not_fabricate_inventory(self):
        driver = journey({'name': 'vermilion-natural', 'collection_balls': 1})
        driver.vermilion = generator.project(ROOT / 'Source')
        driver.map_manifest = {'maps': {'CeruleanMart': {'id': 'pokered:CERULEAN_MART'}}}
        driver.vermilion_active = True
        driver.collection['purchased'] = 1
        driver.state = {'session': {'inventory': {'money': 600, 'slots': [{'id': 'pokeBall', 'quantity': 2}]}}}
        original = copy.deepcopy(driver.state)
        with self.assertRaisesRegex(ProtocolError, 'insufficient real ball stock/funds'):
            driver.collection_supplies('CeruleanMart')
        self.assertEqual(driver.state, original)


class AideFixtureBoundaryTests(unittest.TestCase):
    def fixture_owner(self, key):
        # Data boundary only. Actual recruitment runs solely in root's SDK.
        threshold = 10 if key == 'hm05' else 30
        data = (ROOT / 'Source/data/pokemon.lua').read_text()
        original = sorted((int(dex), species) for species, dex in re.findall(
            r'^    (\w+) = \{\n        name = [^\n]*?dex = (\d+),', data, re.M))
        species = ['squirtle'] + [s for _, s in original if s != 'squirtle'][:threshold - 1]
        value = owner(species[:6], box=1 if threshold == 10 else 2)
        value['owned'] = {s: True for s in species}
        receipts = []
        for index, s in enumerate(species[1:], 2):
            if index <= 6:
                destination = {'destination': 'party', 'index': index}
            else:
                box = 1 if index <= 26 else 2
                value['storage']['boxes'][box - 1].append({'species': s})
                destination = {'destination': 'storage', 'box': box, 'index': len(value['storage']['boxes'][box - 1])}
            receipts.append({'species': s, 'destination': destination})
        return value, {'kind': 'vermilion-aide-fixture', 'classification': 'supplementary', 'case': key,
                        'threshold': threshold, 'owned': threshold, 'recruits': receipts}

    def test_ten_and_thirty_distinct_specimens_must_match_owner_recruitment_receipts(self):
        for key in ('hm05', 'itemfinder'):
            driver = journey({'name': 'vermilion-supplementary', 'supplementary': True, 'case': key + '-full-retry'})
            driver.vermilion = generator.project(ROOT / 'Source')
            value, receipt = self.fixture_owner(key)
            driver.observe = lambda kind: receipt if kind == 'vermilion-aide-fixture' else value
            driver.qualify_aide_fixture(key)
            self.assertEqual(driver.summary['aide_fixture']['threshold'], len(value['owned']))
            bad = copy.deepcopy(value)
            bad['storage']['boxes'][0][0]['species'] = 'squirtle'
            driver.observe = lambda kind: receipt if kind == 'vermilion-aide-fixture' else bad
            with self.assertRaises(ProtocolError):
                driver.qualify_aide_fixture(key)

    def test_natural_mode_rejects_aide_fixture_and_setup_without_input(self):
        driver = journey()
        with self.assertRaisesRegex(ProtocolError, 'cannot enter the natural'):
            driver.qualify_aide_fixture('hm05')
        with self.assertRaisesRegex(ProtocolError, 'requires explicit supplementary'):
            driver.setup_fixture('Route2Gate', vermilion_aide_capacity='hm05')

    def test_root_fixture_patch_is_narrow_and_recruits_real_species_through_owners(self):
        text = (CASES / 'root-aide-capacity-fixture.patch').read_text()
        additions = '\n'.join(line[1:] for line in text.splitlines() if line.startswith('+') and not line.startswith('+++'))
        self.assertIn('session:recruit(mon)', additions)
        self.assertIn('storage:selectBox(', additions)
        self.assertNotRegex(additions, r'(?:dex|pokedex|owned)\s*\[[^\]]+\]\s*=')
        self.assertNotIn('SessionCodec.decode', additions)
        species = re.findall(r'"(\w+)"', additions.split('local species = {', 1)[1].split('}', 1)[0])
        self.assertEqual(len(species), 30)
        self.assertEqual(len(set(species)), 30)
        data = (ROOT / 'Source/data/pokemon.lua').read_text()
        actual = {s for s, dex in re.findall(r'^    (\w+) = \{\n        name = [^\n]*?dex = (\d+),', data, re.M) if int(dex) <= 30}
        self.assertEqual(set(species), actual)

    def test_proposed_root_patches_apply_without_changing_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            for relative in ('Source/dev/fixtures.lua', 'Source/dev/diagnostics.lua', 'tools/harness/restarting.py'):
                target = temporary / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(subprocess.check_output(['git', 'show', 'eda74a9:' + relative], cwd=ROOT))
            for name in ('root-aide-capacity-fixture.patch', 'root-collection-observations.patch', 'root-collection-options.patch'):
                subprocess.run(['git', 'apply', str(CASES / name)], cwd=temporary, check=True, capture_output=True)
            spec = importlib.util.spec_from_file_location('vermilion_collection_restarting', temporary / 'tools/harness/restarting.py')
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            for scenario in CASES.glob('*.json'):
                restarting.validate(json.loads(scenario.read_text()))
            bad = {'processes': [{'journey': {'name': 'brock-natural', 'collection_balls': 80}},
                                 {'restart': True, 'journey': {'name': 'brock-continue'}}]}
            with self.assertRaises(ProtocolError):
                module.validate(bad)


if __name__ == '__main__':
    unittest.main()
