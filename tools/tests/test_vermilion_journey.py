"""Host boundary checks. No Simulator, Lua evaluation or game/RNG emulation."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import generate_vermilion_journey as generator
from tools.harness import cerulean_journey as cj, vermilion_journey as vj, midgame_journey as mj, restarting
from tools.harness.protocol import ProtocolError

ROOT = Path(__file__).resolve().parents[2]
CASES = ROOT / 'tools/harness/scenarios/vermilion'


class NoRuntime:
    identity = {'build_id': 'host-boundary', 'session_id': 'host-owned'}

    def send(self, *args, **kwargs):
        raise AssertionError('host boundary test attempted runtime input')


def journey(config=None, build=None):
    return vj.VermilionJourney(NoRuntime(), '/unused', config or {'name': 'vermilion-natural'}, build)


def campaign_receipt():
    payload = {key: {} for key in cj.CODEC_FIELDS - {'version', 'pokemonEncoding'}}
    payload.update(version=1, pokemonEncoding='decimal-counters-v1')
    return dict(starter='squirtle', fossil='dome', zone_id='pokered:ROUTE_11',
                player={'x': 3, 'y': 4, 'facing': 'down'}, flags={'quest': {}, 'trainers': {}},
                inventory={}, party={}, checkpoint={}, codec=payload)


def b_codec():
    codec = campaign_receipt()['codec']
    codec.update(version=4, fieldWorld=dict(version=1, mapPalOffset=0),
                 daycare=dict(version=1, earned='0'),
                 fieldTravel=dict(version=1, mode='walking', strength=False, visited=[]), coins=0)
    codec['questFlags'] = {flag: True for flag in (
        'BADGE_SOUL', 'EVENT_GOT_TM06', 'EVENT_RESCUED_MR_FUJI', 'EVENT_GOT_POKE_FLUTE',
        'EVENT_BEAT_ROUTE12_SNORLAX', 'EVENT_BEAT_ROUTE16_SNORLAX', 'EVENT_GOT_HM03',
        'EVENT_GOT_HM04', 'EVENT_GAVE_GOLD_TEETH')}
    codec['inventory'] = dict(money=1000, slots=[dict(id=item, quantity=1)
        for item in ('pokeFlute', 'bicycle', 'hm03', 'hm04')])
    codec['safari'] = dict(version=1, active=False, steps=0, balls=0, ending='none')
    return codec


def receipt():
    return dict(campaign=campaign_receipt(), classification='natural', case=None, cut_cells=[])


class ConfigTests(unittest.TestCase):
    def test_three_starters_and_all_supplements_are_explicit(self):
        starters, supplements = set(), set()
        for path in CASES.glob('*.json'):
            scenario = json.loads(path.read_text())
            if path.name == 'owner-projection.json':
                continue
            groups = scenario.get('processes', [scenario])
            previous = {}
            for index, group in enumerate(groups):
                config = group['journey']
                vj.validate_config(config)
                if 'processes' in scenario:
                    vj.validate_process_journey(config, index, previous)
                previous = config
            config = groups[0]['journey']
            if config.get('supplementary'):
                supplements.add(config['case'])
            else:
                starters.add(config['starter'])
                self.assertEqual(scenario['initial_save'], {'milestone': '5.3', 'starter': config['starter']})
                self.assertNotIn('training_level', config)
                self.assertNotIn('max_training_battles', config)
                self.assertLessEqual(config['collection_battles'], 60)
                self.assertLessEqual(config['collection_phase_battles'], 20)
                self.assertEqual(len(groups), 2)
                self.assertTrue(groups[1]['restart'])
        self.assertEqual(starters, set(cj.FAMILIES))
        self.assertEqual(supplements, vj.CASES)

    def test_rejects_shortcuts_unbounded_inputs_and_unlabeled_fixtures(self):
        for mutation in ({'max_actions': True}, {'max_steps': 5001}, {'max_puzzle_attempts': 0},
                         {'starter': 'pikachu'}, {'quest_flags': {}}, {'supplementary': True},
                         {'case': 'blackout'}, {'save_path': '/arbitrary/save'}):
            with self.subTest(mutation=mutation), self.assertRaises(ProtocolError):
                journey(dict(name='vermilion-natural', **mutation))
        driver = journey()
        for command in ('warp kanto_vermilion_city', 'move down 2', 'battle raichu 1',
                        'encounters off', 'intro skip', {'op': 'fixture', 'options': {'quest_flags': {}}}):
            with self.subTest(command=command), self.assertRaises(ProtocolError):
                driver.send(command)
        driver.initializing = True
        with self.assertRaises(ProtocolError):
            driver.reset(player_pokemon={'species': 'bulbasaur', 'hp': 1})

    def test_continue_cannot_change_identity_or_fixture_classification(self):
        initial = dict(name='vermilion-natural', starter='charmander', fossil='dome')
        for config, index, previous in [
            ({'name': 'vermilion-continue'}, 0, {}),
            (dict(initial, name='vermilion-continue', starter='bulbasaur'), 1, initial),
            (dict(initial, name='vermilion-natural'), 1, initial),
            ({'name': 'vermilion-continue'}, 1, {'name': 'cerulean-natural'}),
        ]:
            with self.subTest(config=config), self.assertRaises(ProtocolError):
                vj.validate_process_journey(config, index, previous)
        fixture = dict(name='vermilion-supplementary', supplementary=True, case='field-cut-reload')
        vj.validate_process_journey(dict(fixture, name='vermilion-supplementary-continue'), 1, fixture)
        with self.assertRaises(ProtocolError):
            vj.validate_process_journey(dict(fixture, name='vermilion-supplementary-continue', case='blackout'), 1, fixture)

    def test_summary_retains_requested_name_and_no_acceptance_claim(self):
        driver = journey()
        self.assertEqual(driver.summary['journey']['name'], 'vermilion-natural')
        self.assertEqual(driver.summary['acceptance'], 'unrun candidate')

    def test_chain_import_checks_accepted_proof_and_both_slots_before_copy(self):
        # Filesystem boundary only; these bytes are never passed to a game.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            docs = root / 'docs/validation'
            docs.mkdir(parents=True)
            proof = json.loads((ROOT / 'docs/validation/cerulean-acceptance-20261028.json').read_text())
            (docs / 'cerulean-acceptance-20261028.json').write_text(json.dumps(proof))
            slots = root / 'slots'
            slots.mkdir()
            files = []
            for name in ('adventure.a.json', 'adventure.b.json'):
                raw = name.encode()
                (slots / name).write_bytes(raw)
                files.append({'file': name, 'sha256': hashlib.sha256(raw).hexdigest()})
            for starter in cj.FAMILIES:
                scenario = json.loads((CASES / ('restart-' + starter + '.json')).read_text())
                record = dict(starter=starter, from_milestone='5.3', directory=str(slots), files=files,
                              accepted_commit=proof['accepted_main_code'], accepted_source_sha256=proof['source_sha256'])
                manifest = docs / 'chain-saves.json'
                manifest.write_text(json.dumps({'saves': [record]}))
                data, output = root / starter, root / (starter + '-output')
                data.mkdir()
                output.mkdir()
                restarting.validate(scenario)
                restarting.import_chain_save(scenario, root, data, output)
                for name in ('adventure.a.json', 'adventure.b.json'):
                    self.assertEqual((data / name).read_bytes(), (slots / name).read_bytes())
                    (data / name).unlink()
                record['accepted_source_sha256'] = 'wrong'
                manifest.write_text(json.dumps({'saves': [record]}))
                with self.assertRaisesRegex(ProtocolError, 'accepted Cerulean proof'):
                    restarting.import_chain_save(scenario, root, data, output)
                record['accepted_source_sha256'] = proof['source_sha256']
                record['files'] = [files[0], dict(files[1], sha256='wrong')]
                manifest.write_text(json.dumps({'saves': [record]}))
                with self.assertRaisesRegex(ProtocolError, 'checksum changed'):
                    restarting.import_chain_save(scenario, root, data, output)
                self.assertEqual(list(data.iterdir()), [])

    def test_successful_chain_exports_to_54_with_pending_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data, output = root / 'data', root / 'output'
            data.mkdir()
            output.mkdir()
            (output / 'starting-save.json').write_text('{"from_milestone":"5.3"}')
            for name in ('adventure.a.json', 'adventure.b.json'):
                (data / name).write_bytes(name.encode())
            for starter in cj.FAMILIES:
                scenario = json.loads((CASES / ('restart-' + starter + '.json')).read_text())
                with patch.object(Path, 'home', return_value=root):
                    restarting.export_chain_save(scenario, data, output, NoRuntime.identity)
                chain = root / 'Developer/Pokemon-PlayDate-env/evidence/chain'
                provenance = json.loads((chain / '5.4' / starter / 'provenance.json').read_text())
                self.assertIn('pending', provenance['status'])
                self.assertEqual(provenance['milestone'], '5.4')
                self.assertFalse((chain / '5.3').exists())
                for item in provenance['files']:
                    raw = (chain / '5.4' / starter / item['file']).read_bytes()
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), item['sha256'])


class ProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.build = Path(cls.temporary.name)
        shutil.copytree(ROOT / 'Source', cls.build / 'Source')
        shutil.copyfile(cls.build / 'Source/main.lua', cls.build / 'original-main.lua')
        # Explicit negative activation fixture keeps this boundary meaningful
        # after root eventually activates all 65 maps.
        manifest_path = cls.build / 'Source/data/sourceMaps.json'
        manifest = json.loads(manifest_path.read_text())
        manifest['maps'].pop('Route5', None)
        manifest_path.write_text(json.dumps(manifest))
        projected = generator.project(cls.build / 'Source')
        (cls.build / 'Source/dev/vermilionJourney.json').write_text(json.dumps(projected))
        cls.rehash()

    @classmethod
    def rehash(cls):
        files = {p.relative_to(cls.build / 'Source').as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in (cls.build / 'Source').rglob('*') if p.is_file()}
        (cls.build / 'source-manifest.json').write_text(json.dumps(files))

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_generation_is_exact_and_pins_every_map_and_three_counter_teams(self):
        actual = generator.project(ROOT / 'Source')
        saved = json.loads((ROOT / 'Source/dev/vermilionJourney.json').read_text())
        self.assertEqual(actual, saved)
        self.assertEqual(len(actual['maps']), 35)
        self.assertEqual({m['path'] for m in actual['maps'].values()} - set(actual['sources']), set())
        self.assertIn('bulbasaur', actual['cut_species'])
        self.assertNotIn('squirtle', actual['cut_species'])
        variants = actual['trainers'][vj.RIVAL]['rival_parties']
        self.assertEqual({s: t['party'][-1]['species'] for s, t in variants.items()},
                         {'bulbasaur': 'charmeleon', 'charmander': 'wartortle', 'squirtle': 'ivysaur'})
        if (ROOT / 'Source/game/daycare.lua').is_file():
            self.assertIn('game/daycare.lua', actual['daycare_inputs'])
        else:
            self.assertEqual(actual['daycare_inputs'], [])

    def test_inactive_maps_fail_before_any_runtime_request(self):
        with self.assertRaisesRegex(ProtocolError, 'inactive milestone 5.4 maps'):
            journey(build=self.build).dependencies()

    def test_staged_owner_byte_drift_is_not_hidden_by_live_checkout(self):
        target = self.build / 'Source/domain/teaching.lua'
        original = target.read_bytes()
        try:
            target.write_bytes(original + b'\n-- mutation\n')
            with self.assertRaisesRegex(ProtocolError, 'stale Vermilion owner pin: domain/teaching.lua'):
                vj.validate_projection(cj.StagedSource(self.build))
        finally:
            target.write_bytes(original)

    def test_generator_rejects_corrupt_prepared_map_and_wrong_counter(self):
        for relative, mutate in [
            ('data/vermilionPreparation/Route5.json', lambda v: dict(v, name='WrongRoute')),
            ('data/vermilionStory/trainers.json', lambda v: self.wrong_counter(v)),
        ]:
            target = self.build / 'Source' / relative
            original = target.read_bytes()
            try:
                target.write_text(json.dumps(mutate(json.loads(original))))
                with self.subTest(relative=relative), self.assertRaises(ValueError):
                    generator.project(self.build / 'Source')
            finally:
                target.write_bytes(original)

    def wrong_counter(self, value):
        value['trainers'][vj.RIVAL]['rival_parties']['squirtle']['party'][-1]['species'] = 'wartortle'
        return value

    def test_missing_owner_pin_and_recursive_pin_fail_closed(self):
        original_read = cj.StagedSource.read
        for mutate in (lambda v: v['sources'].pop('data/machineData.lua'),
                       lambda v: v['sources'].update({'../secret': 'digest'})):
            def altered(source, relative):
                result = original_read(source, relative)
                if relative == vj.PROJECTION:
                    mutate(result)
                return result
            with patch.object(cj.StagedSource, 'read', altered), self.assertRaises(ProtocolError):
                vj.validate_projection(cj.StagedSource(self.build))


class DecisionTests(unittest.TestCase):
    def test_aide_threshold_uses_unique_owned_species_never_seen_or_party_count(self):
        driver = journey()
        event, _, _ = vj.GIFTS['hm05']
        driver.vermilion = {'events': {event: {'threshold': 10}}}
        driver.state = {'session': {'pokedex': {'seen': {str(i): True for i in range(40)},
                                               'owned': {'squirtle': True, 'pidgey': True}}}}
        self.assertEqual(driver.owned_count(), 2)
        with self.assertRaisesRegex(ProtocolError, '10 actual unique owned species'):
            driver.gift('hm05')

    def test_missing_cut_user_never_constructs_an_artificial_species(self):
        driver = journey()
        driver.vermilion = {'cut_species': ['bulbasaur', 'rattata']}
        driver.state = {'session': {'party': {'members': [{'species': 'squirtle', 'moves': ['tackle']}]}}}
        with self.assertRaisesRegex(ProtocolError, 'no actually owned compatible Cut user'):
            driver.teach_cut()

    def test_teaching_opens_the_actual_item_pause_menu(self):
        driver = journey()
        driver.vermilion = {'cut_species': ['bulbasaur']}
        driver.state = {'session': {'party': {'members': [{'species': 'bulbasaur', 'moves': ['tackle']}]},
                                    'inventory': {'slots': [{'id': 'hm01', 'quantity': 1}]}}}
        class ItemMenuReached(Exception):
            pass
        def send(command):
            if command == 'press b':
                driver.state.update(root='pause', pause={'phase': 'menu', 'selected': 1,
                                     'menu': {'options': ['POKEMON', 'ITEM', 'RED', 'SAVE', 'CLOSE']}})
            elif command == 'press a':
                self.assertEqual(driver.state['pause']['selected'], 2)
                raise ItemMenuReached()
            else:
                self.fail('unexpected input before Item menu: ' + command)
        driver.send = send
        driver.select = lambda path, index: driver.state['pause'].update(selected=index)
        with self.assertRaises(ItemMenuReached):
            driver.teach_cut()

    def test_teaching_waits_for_actual_input_release_before_advancing_message(self):
        driver = journey()
        driver.vermilion = {'cut_species': ['bulbasaur']}
        mon = {'species': 'bulbasaur', 'moves': ['tackle']}
        driver.state = {'root': 'overworld', 'session': {'party': {'members': [mon]},
                         'inventory': {'slots': [{'id': 'hm01', 'quantity': 1}]}}}
        # Explicit UI boundary publications, not a Pokemon/rules simulator.
        trace = [
            ('press b', {'root': 'pause', 'pause': {'phase': 'menu', 'selected': 2,
                'menu': {'options': ['POKEMON', 'ITEM', 'RED', 'SAVE', 'CLOSE']}}}),
            ('press a', {'root': 'bag', 'bag': {'phase': 'list', 'selected': 1}}),
            ('press a', {'bag': {'phase': 'actions', 'menu': {'selected': 1}}}),
            ('press a', {'root': 'party', 'party_ui': {'selected': 1}}),
            ('press a', {'root': 'learning', 'learning': {'phase': 'message', 'dialog_ready': True,
                                                       'input_blocked': True}}),
            ('wait 2', {'learning': {'phase': 'message', 'dialog_ready': True, 'input_blocked': False}}),
            ('press a', {'root': 'bag'}),
            ('press b', {'root': 'overworld'}),
        ]
        def send(command):
            expected, publication = trace.pop(0)
            self.assertEqual(command, expected)
            driver.state.update(copy.deepcopy(publication))
            if len(trace) == 1:
                mon['moves'] = ['tackle', 'cut']
        driver.send = send
        driver.checkpoint = lambda label: None
        self.assertEqual(driver.teach_cut(), 1)
        self.assertEqual(trace, [])

    def test_read_only_geometry_update_is_detached_and_rejects_other_map(self):
        driver = journey()
        from tools.harness.brock_journey import SourceGeometry
        driver.models = {'gym': SourceGeometry('gym', [[1, 0], [0, 0]])}
        driver.state = {'zone_id': 'gym'}
        observed = {'zone_id': 'gym', 'collision': [[0, 0], [0, 0]]}
        driver.apply_world_observation(observed)
        observed['collision'][0][0] = 1
        self.assertEqual(driver.model().collision[0][0], 0)
        for value in ({'zone_id': 'other'}, {'zone_id': 'gym', 'collision': [[False, 0], [0, 0]]}):
            with self.assertRaises(ProtocolError):
                driver.apply_world_observation(value)

    def test_puzzle_decisions_use_real_can_dispatch_not_secret_indices(self):
        driver = journey({'name': 'vermilion-natural', 'max_puzzle_attempts': 3})
        driver.vermilion = {'scenes': {'trash': {'cans': [{'index': 0}], 'table': [[2, 1, 3, 0, 0]]}}}
        driver.flag = lambda flag: False
        calls = []
        driver.inspect_can = lambda can: calls.append(can['index'])
        with self.assertRaisesRegex(ProtocolError, 'attempt bound exhausted'):
            driver.puzzle()
        self.assertEqual(calls, [0, 0, 0])

    def test_daycare_without_eligible_actual_second_member_fails_after_visit(self):
        driver = journey()
        driver.map_manifest = {'maps': {'Daycare': {'id': 'pokered:DAYCARE'}}}
        visited = []
        driver.travel = lambda zone: visited.append(zone)
        driver.checkpoint = lambda label: None
        driver.observe = lambda kind: {'owner': {'earned': 0, 'party': {'members': [{'species': 'squirtle', 'moves': ['tackle']}]}}}
        driver.starter_index = lambda: 1
        with self.assertRaisesRegex(ProtocolError, 'no actual eligible second Day Care member'):
            driver.daycare_service()
        self.assertEqual(visited, ['pokered:DAYCARE'])

    def test_daycare_driver_checks_actual_transfer_steps_quote_and_paid_return(self):
        driver = journey()
        driver.map_manifest = {'maps': {'Daycare': {'id': 'pokered:DAYCARE'},
                                         'UndergroundPathRoute5': {'id': 'pokered:UNDERGROUND_PATH_ROUTE_5'}}}
        starter = {'species': 'squirtle', 'moves': ['tackle'], 'hp': 20, 'xp': 120}
        second = {'species': 'pidgey', 'moves': ['tackle'], 'hp': 15, 'xp': 100, 'ivs': {'hp': 6}}
        before = {'party': {'members': [starter, second]}, 'money': 500, 'earned': 0}
        deposited = {'party': {'members': [starter]}, 'money': 500, 'earned': 0, 'pokemon': second}
        grown = dict(deposited, earned=8)
        returned = dict(second, xp=108)
        after = {'party': {'members': [starter, returned]}, 'money': 400, 'earned': 0}
        observations = [{'owner': v} for v in (before, deposited)] + [
            {'owner': grown, 'withdrawal': {'status': 'ready', 'fee': 100}}, {'owner': after}]
        driver.observe = lambda kind: observations.pop(0)
        driver.starter_index = lambda: 1
        visits, interactions = [], []
        driver.travel = lambda zone: visits.append(zone)
        driver.approach_daycare = lambda: None
        driver.interact = lambda **kw: interactions.append((kw, driver.daycare_index))
        driver.checkpoint = lambda label: None
        driver.daycare_service()
        self.assertEqual([i[1] for i in interactions], [2, None])
        self.assertEqual(visits, ['pokered:DAYCARE', 'pokered:UNDERGROUND_PATH_ROUTE_5', 'pokered:DAYCARE'])
        self.assertEqual(driver.summary['daycare_service']['earned'], 8)
        self.assertEqual(driver.summary['daycare_service']['returned']['ivs'], second['ivs'])

    def test_aide_capacity_requires_actual_explicit_recruitment_receipt(self):
        for key in ('hm05', 'itemfinder'):
            driver = journey({'name': 'vermilion-supplementary', 'supplementary': True, 'case': key + '-full-retry'})
            event = vj.GIFTS[key][0]
            driver.vermilion = {'events': {event: {'threshold': 10 if key == 'hm05' else 30}}}
            driver.observe = lambda kind: {'kind': kind}  # Missing support cannot pass.
            with self.subTest(key=key), self.assertRaisesRegex(ProtocolError, 'actual supplementary aide recruitment receipt'):
                driver.qualify_aide_fixture(key)
            self.assertFalse(driver.initialized)

    def test_codec_payload_only_requested_at_save_continue_boundaries(self):
        driver = journey()
        driver.export = {'session_codec': 1}
        response = dict(kind='validate', version=1, valid=True, roundtrip_equal=True,
                        payload=campaign_receipt()['codec'])
        driver.observe = lambda kind: response
        with self.assertRaisesRegex(ProtocolError, 'masquerade'):
            driver.codec_guard()
        self.assertEqual(driver.codec_guard('saved'), response['payload'])


class ReceiptAndPatchTests(unittest.TestCase):
    def test_schema_three_preserves_daycare_and_rejects_incomplete_or_lossy_data(self):
        payload = campaign_receipt()['codec']
        payload.update(version=3, fieldWorld={'version': 1, 'mapPalOffset': 0},
                       daycare={'version': 1, 'earned': '0'})
        vj.validate_boundary_payload(payload)
        state = receipt()
        state['campaign']['codec'] = payload
        vj.validate_receipt_state(state)
        for mutation in ({'earned': '01'}, {'earned': 0}, {'earned': '1'},
                         {'earned': '1250001'}, {'pokemon': None}, {'extra': True}):
            bad = copy.deepcopy(payload)
            bad['daycare'].update(mutation)
            with self.subTest(mutation=mutation), self.assertRaises(ProtocolError):
                vj.validate_boundary_payload(bad)
        bad = copy.deepcopy(payload)
        bad.pop('daycare')
        with self.assertRaises(ProtocolError):
            vj.validate_boundary_payload(bad)

    def test_wrong_build_and_relabelled_supplements_fail_before_input(self):
        state = receipt()
        vj.validate_receipt_state(state)
        packet = dict(schema=1, kind='vermilion-saved', state=state, **NoRuntime.identity)
        for mutation in ({'build_id': 'other'}, {'session_id': 'other'}, {'kind': 'cerulean-saved'}):
            with self.assertRaises(ProtocolError):
                journey({'name': 'vermilion-continue'}).continue_saved(dict(packet, **mutation))
        packet['state'] = dict(state, classification='supplementary', case='field-cut-reload')
        with self.assertRaisesRegex(ProtocolError, 'cannot relabel'):
            journey({'name': 'vermilion-continue'}).continue_saved(packet)

    def test_unapplied_dispatch_patch_routes_scenarios_and_checks_immutable_receipts(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            for name in ('journeys.py', 'restarting.py', 'brock_capture.py'):
                path = temporary / 'tools/harness' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(subprocess.check_output(['git', 'show', 'f8d5ce8:tools/harness/' + name], cwd=ROOT))
            subprocess.run(['git', 'apply', str(CASES / 'root-registration.patch')], cwd=temporary, check=True, capture_output=True)
            subprocess.run(['git', 'apply', str(CASES / 'root-collection-options.patch')], cwd=temporary, check=True, capture_output=True)
            def load(name):
                spec = importlib.util.spec_from_file_location('vermilion_patch_' + name, temporary / 'tools/harness' / (name + '.py'))
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                return module
            patched_restarting = load('restarting')
            dispatch = load('journeys')
            for path in CASES.glob('*.json'):
                restarting.validate(json.loads(path.read_text()))
            expected = {'ok': True}
            with patch.object(vj, 'run', return_value=expected) as run:
                scenario = {'journey': {'name': 'vermilion-continue'}}
                self.assertIs(dispatch.run(None, scenario, temporary, temporary, {}, temporary), expected)
                run.assert_called_once_with(None, scenario, temporary, temporary, {}, temporary)
            path = temporary / 'receipt.json'
            packet = dict(schema=1, kind='vermilion-saved', state=receipt(), **NoRuntime.identity)
            path.write_text(json.dumps(packet))
            reference = {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            self.assertEqual(patched_restarting.read_receipt(reference, NoRuntime.identity), packet)
            path.write_text(json.dumps(dict(packet, session_id='changed')))
            with self.assertRaises(ProtocolError):
                patched_restarting.read_receipt(reference, NoRuntime.identity)

    def test_readonly_patch_applies_to_exact_base_without_modifying_shared_files(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            path = temporary / 'Source/dev/diagnostics.lua'
            path.parent.mkdir(parents=True)
            path.write_bytes(subprocess.check_output(['git', 'show', 'f8d5ce8:Source/dev/diagnostics.lua'], cwd=ROOT))
            result = subprocess.run(['git', 'apply', '--check', str(CASES / 'root-observations.patch')],
                                    cwd=temporary, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


class MidgameSaveInputTests(unittest.TestCase):
    def test_fuchsia_bag_room_uses_the_local_item_pc(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', dict(
            name='midgame-natural', starter='charmander', packet='5.5b', content_scope='optional'))
        with patch.object(driver, 'inventory', side_effect=[{'slots': [None] * 16}, {'slots': [None] * 15}]), \
                patch.object(driver, 'quantity', return_value=0), \
                patch.object(driver, 'store_unused_items') as store:
            driver.ensure_room('FuchsiaMart')
        store.assert_called_once_with('FuchsiaPokecenter')

    def test_fuchsia_route_crosses_fixed_exits_without_reentering_route12(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', dict(
            name='midgame-natural', starter='squirtle', packet='5.5b', content_scope='critical'))
        driver.completed_steps = {'route12-snorlax', 'route13-rested'}
        class ReachedFuchsia(Exception):
            pass
        def heal(name):
            if name == 'FuchsiaPokecenter':
                raise ReachedFuchsia
        with patch.object(driver, 'heal_here', side_effect=heal), \
                patch.object(driver, 'restock'), \
                patch.object(driver, 'zone', side_effect=lambda name: name), \
                patch.object(driver, 'travel') as travel, \
                patch.object(driver, 'source_waypoint'), \
                patch.object(driver, 'cross') as cross, patch.object(driver, 'warp'):
            with self.assertRaises(ReachedFuchsia):
                driver.route_fuchsia()
        travel.assert_called_once_with('Route13')
        self.assertEqual([call.args for call in cross.call_args_list], [
            ('left', 'Route14', (19, 10)), ('left', 'Route15', (59, 8)),
            ('left', 'FuchsiaCity', (39, 16))])

    def test_snorlax_travel_includes_the_final_component_goal(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', dict(
            name='midgame-natural', starter='squirtle', packet='5.5b', content_scope='critical'))
        driver.models = {'route12': type('Model', (), {'padding': 0})()}
        class ReachedApproach(Exception):
            pass
        with patch.object(driver, 'zone', return_value='route12'), \
                patch.object(driver, 'travel') as travel, \
                patch.object(driver, 'source_waypoint'), \
                patch.object(driver, 'require_event', side_effect=ReachedApproach):
            with self.assertRaises(ReachedApproach):
                driver.wake_snorlax('ROUTE_12', 1, (10, 61))
        travel.assert_called_once_with('route12', goal=(10, 61))

    def test_tower_reserves_bag_room_before_entering(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', dict(
            name='midgame-natural', starter='squirtle', packet='5.5b', content_scope='critical'))
        calls = []
        class EnteredTower(Exception):
            pass
        with patch.object(driver, 'scene_data', return_value={}), \
                patch.object(driver, 'heal_here'), patch.object(driver, 'restock'), \
                patch.object(driver, 'ensure_room', side_effect=lambda mart: calls.append(mart)), \
                patch.object(driver, 'zone', side_effect=lambda name: name), \
                patch.object(driver, 'travel', side_effect=EnteredTower):
            with self.assertRaises(EnteredTower):
                driver.route_tower()
        self.assertEqual(calls, ['LavenderMart'])

    def test_save_releases_dialog_input_before_pressing_b(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', dict(
            name='midgame-natural', starter='squirtle', packet='5.5a', content_scope='critical'))
        # Squirtle trace ticks 2786-2787: final A dismisses healing, then B
        # arrives while the overworld gesture owner still awaits neutral input.
        driver.state = {'root': 'overworld', 'overworld': 'explore',
                        'player': {'settled': True, 'moving': False}}
        expected = iter([
            (['wait 1'], driver.state),
            (['wait 3', 'press b'], driver.state),
            ([{'op': 'await', 'path': 'root', 'equals': 'pause', 'frames': 8}],
             {'root': 'pause', 'pause': {'phase': 'menu'}}),
        ])

        def send(commands, **options):
            wanted, snapshot = next(expected)
            self.assertEqual(commands, wanted)
            return {'snapshot': copy.deepcopy(snapshot)}

        class ReachedSaveMenu(Exception):
            pass

        # Exercise the inherited Save entry, stopping before any save write.
        with patch.object(driver.client, 'send', side_effect=send), \
                patch.object(driver, 'pause_option', side_effect=ReachedSaveMenu) as menu:
            with self.assertRaises(ReachedSaveMenu):
                driver.save()
        menu.assert_called_once_with('SAVE')
        self.assertEqual(list(expected), [])
        self.assertFalse(driver.saving)


class MidgameBImportTests(unittest.TestCase):
    def test_overlay_input_waits_for_actual_owner_phase(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', self.scenario()['processes'][0]['journey'])
        driver.state = {'root': 'fieldGear'}
        for phase, command in [('cast', 'wait 3'), ('bite', 'wait 3'), ('result', 'press a')]:
            with self.subTest(phase=phase), patch.object(driver, 'observe', return_value={
                    'fieldGear': dict(installed=True, active=True, phase=phase)}), patch.object(driver, 'send') as send:
                self.assertTrue(driver.advance_event())
                send.assert_called_once_with(command)
        driver.state = {'root': 'safariPassage'}
        for phase, command in [('announcement', 'press a'), ('before', 'wait 3'), ('fade', 'wait 3'), ('after', 'wait 3')]:
            with self.subTest(phase=phase), patch.object(driver, 'safari_observation', return_value={
                    'passage': dict(phase=phase)}), patch.object(driver, 'send') as send:
                self.assertTrue(driver.advance_event())
                send.assert_called_once_with(command)
        with patch.object(driver, 'safari_observation', return_value={'passage': dict(phase='failed', lastFailure='stale')}):
            with self.assertRaisesRegex(ProtocolError, 'stale'):
                driver.advance_event()

    def test_safari_run_uses_two_column_cursor_and_requires_commit(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', self.scenario()['processes'][0]['journey'])
        battle = dict(active=True, phase='command', selected=1, turns=0, encounter=1,
                      menu=dict(active=True, columns=2, options=['BALL', 'BAIT', 'ROCK', 'RUN']))
        with patch.object(driver, 'safari_observation', return_value={'battle': battle}), patch.object(driver, 'send') as send, \
                patch.object(driver, 'inventory', return_value={}), patch.object(driver, 'party', return_value=[]):
            driver.advance_safari_battle()
            send.assert_called_once_with('press right')
            send.reset_mock()
            battle['selected'] = 2
            driver.advance_safari_battle()
            send.assert_called_once_with('press down')
            battle['selected'] = 4
            with patch.object(driver, 'inventory', return_value={}), patch.object(driver, 'party', return_value=[]):
                with self.assertRaisesRegex(ProtocolError, 'did not actually commit'):
                    driver.advance_safari_battle()

    def scenario(self, starter='squirtle'):
        return json.loads((mj.SCENARIOS / ('restart-55b-' + starter + '.json')).read_bytes())

    def fixture(self, root):
        # Host publication double only. Slot bytes are never interpreted as game data.
        docs, slots, run_root = root / 'docs/validation', root / 'slots', root / 'producer'
        docs.mkdir(parents=True)
        slots.mkdir()
        run_root.mkdir()
        files = []
        for name in ('adventure.a.json', 'adventure.b.json'):
            raw = name.encode()
            (slots / name).write_bytes(raw)
            files.append(dict(file=name, sha256=hashlib.sha256(raw).hexdigest()))
        proof = json.loads((ROOT / 'docs/validation/midgame-a-acceptance-20261029.json').read_bytes())
        accepted = next(r for r in proof['starters'] if r['starter'] == 'squirtle')
        accepted.update(files=files, evidence=str(run_root))
        origin = copy.deepcopy(next(r for r in json.loads((ROOT / 'docs/validation/chain-saves.json').read_bytes())['saves']
                                    if r['from_milestone'] == '5.4' and r['starter'] == 'squirtle'))
        shutil.copyfile(ROOT / 'docs/validation/vermilion-acceptance-20261028.json',
                        docs / 'vermilion-acceptance-20261028.json')
        record = dict(starter='squirtle', from_milestone='5.5a', origin_milestone='5.4',
                      directory=str(slots), source=str(run_root), files=files,
                      accepted_commit=proof['accepted_main_code'],
                      accepted_source_sha256=proof['production_source_sha256'],
                      journey_source_sha256=accepted['source_sha256'],
                      acceptance='docs/validation/midgame-a-acceptance-20261029.json')
        (docs / 'midgame-a-acceptance-20261029.json').write_text(json.dumps(proof))
        (docs / 'chain-saves.json').write_text(json.dumps(dict(saves=[origin, record])))
        state = dict(starter='squirtle', packet='5.5a', content_scope='critical',
                     codec=campaign_receipt()['codec'],
                     completed_steps=['celadon_gym', 'hideout-scope', 'rock-tunnel-flash-lavender'])
        packet = dict(schema=1, kind='midgame-saved', state=state, **NoRuntime.identity)
        groups = []
        for index in (1, 2):
            generation = run_root / 'processes' / f'{index:04d}'
            (generation / 'runtime-data').mkdir(parents=True)
            raw = json.dumps(packet).encode()
            (generation / 'journey-receipt.json').write_bytes(raw)
            for item in files:
                shutil.copyfile(slots / item['file'], generation / 'runtime-data' / item['file'])
            groups.append(dict(evidence=f'processes/{index:04d}', status='exited', returncode=0,
                               pid=index, previous_pid=1 if index == 2 else None,
                               previous_exit_confirmed=True, fresh_ready=True,
                               durable_after={r['file']: r['sha256'] for r in files},
                               journey_receipt=dict(path=f'processes/{index:04d}/journey-receipt.json',
                                                    sha256=hashlib.sha256(raw).hexdigest())))
        (run_root / 'run.json').write_text(json.dumps(dict(processes=groups, **NoRuntime.identity)))
        (run_root / 'outcome.json').write_text(json.dumps(dict(ok=True, session_id=NoRuntime.identity['session_id'])))
        (slots / 'provenance.json').write_text(json.dumps(dict(milestone='5.5a', starter='squirtle',
            evidence=str(run_root), files=files, source_sha256=record['journey_source_sha256'],
            build_id=NoRuntime.identity['build_id'], starting_save=origin)))
        return record, run_root, slots

    def test_b_scenarios_preserve_a_and_require_exact_origin_and_restart(self):
        for starter in cj.FAMILIES:
            scenario = self.scenario(starter)
            restarting.validate(scenario)
            old = json.loads((mj.SCENARIOS / ('restart-' + starter + '.json')).read_bytes())
            restarting.validate(old)
            for mutate in ('origin', 'restart', 'scope', 'future'):
                changed = copy.deepcopy(scenario)
                if mutate == 'origin': changed['initial_save']['milestone'] = '5.4'
                if mutate == 'restart': changed['processes'][1]['restart'] = False
                if mutate == 'scope': changed['processes'][1]['journey']['content_scope'] = 'optional' if starter != 'charmander' else 'critical'
                if mutate == 'future': changed['processes'][0]['journey']['packet'] = '5.5c'
                with self.subTest(starter=starter, mutate=mutate), self.assertRaises(ProtocolError):
                    restarting.validate(changed)

    def test_import_binds_manifest_hashes_ancestry_and_stopped_continue_before_copy(self):
        for mutation in ('none', 'acceptance', 'slot', 'ancestry', 'live', 'same-pid', 'archive', 'receipt'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                record, producer, slots = self.fixture(root)
                data, output = root / 'data', root / 'output'
                data.mkdir(); output.mkdir()
                if mutation == 'acceptance':
                    path = root / record['acceptance']
                    proof = json.loads(path.read_bytes()); proof['starters'][1]['files'][0]['sha256'] = 'bad'
                    path.write_text(json.dumps(proof))
                if mutation == 'slot': (slots / 'adventure.b.json').write_bytes(b'changed')
                if mutation == 'ancestry':
                    path = slots / 'provenance.json'
                    value = json.loads(path.read_bytes()); value['starting_save']['accepted_commit'] = 'bad'
                    path.write_text(json.dumps(value))
                if mutation in {'live', 'same-pid'}:
                    path = producer / 'run.json'; value = json.loads(path.read_bytes())
                    value['processes'][1]['status' if mutation == 'live' else 'pid'] = 'ready' if mutation == 'live' else 1
                    path.write_text(json.dumps(value))
                if mutation == 'archive': (producer / 'processes/0002/runtime-data/adventure.a.json').write_bytes(b'changed')
                if mutation == 'receipt': (producer / 'processes/0002/journey-receipt.json').write_text('{}')
                if mutation == 'none':
                    result = restarting.import_chain_save(self.scenario(), root, data, output)
                    self.assertEqual(result['accepted_boundary']['state']['packet'], '5.5a')
                    self.assertEqual((data / 'adventure.a.json').read_bytes(), b'adventure.a.json')
                else:
                    with self.assertRaises(ProtocolError):
                        restarting.import_chain_save(self.scenario(), root, data, output)
                    self.assertEqual(list(data.iterdir()), [])

    def test_b_does_not_replay_a_and_final_receipt_requires_b_rewards(self):
        driver = mj.MidgameJourney(NoRuntime(), '/unused', self.scenario()['processes'][0]['journey'])
        calls = []
        with patch.object(driver, 'start_earned'), patch.object(driver, 'save'), patch.object(driver, 'write_receipt'):
            for method in ('route_tower', 'route_fuchsia', 'route_bicycle', 'route_lavender', 'route_a', 'route_saffron'):
                setattr(driver, method, lambda method=method: calls.append(method))
            driver.natural()
        self.assertEqual(calls, ['route_tower', 'route_fuchsia', 'route_bicycle'])
        state = dict(starter='squirtle', packet='5.5b', content_scope='critical',
                     codec=b_codec(), completed_steps=sorted(mj.B_STEPS))
        mj.validate_receipt_state(state)
        for step in mj.B_STEPS:
            with self.subTest(step=step), self.assertRaises(ProtocolError):
                mj.validate_receipt_state(dict(state, completed_steps=sorted(mj.B_STEPS - {step})))
        with patch.object(driver, 'observe', return_value={'safari': {'sessionInstalled': False}}):
            with self.assertRaisesRegex(ProtocolError, 'Safari requires'):
                driver.safari_journey()
        for key, value in [('active', True), ('balls', 1), ('ending', 'steps')]:
            changed = copy.deepcopy(state)
            changed['codec']['safari'][key] = value
            with self.subTest(resource=key), self.assertRaisesRegex(ProtocolError, 'resources'):
                mj.validate_receipt_state(changed)
        changed = copy.deepcopy(state)
        changed['codec']['inventory']['slots'].pop()
        with self.assertRaisesRegex(ProtocolError, 'rewards'):
            mj.validate_receipt_state(changed)

    def test_b_continue_compares_accepted_codec_before_travel(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            record, producer, slots = self.fixture(root)
            boundary = restarting.accepted_midgame_boundary(record, root)
            (root / 'starting-save.json').write_text(json.dumps(dict(record, accepted_boundary=boundary)))
            driver = mj.MidgameJourney(NoRuntime(), '/unused', self.scenario()['processes'][0]['journey'], root)
            changed = copy.deepcopy(boundary['state']['codec'])
            changed['inventory'] = {'money': 999}
            with patch.object(driver, 'dependencies'), patch.object(driver, 'title_continue'), \
                    patch.object(driver, 'codec_guard', return_value=changed) as guard, \
                    patch.object(driver, 'quantity', side_effect=AssertionError('rewards inspected before codec equality')):
                with self.assertRaisesRegex(ProtocolError, 'Continue differs'):
                    driver.start_earned()
                guard.assert_called_once_with('loaded')
            self.assertEqual(driver.completed_steps, set())

    def test_final_b_export_requires_restart_equal_receipts_and_stopped_bytes(self):
        for mutation in ('none', 'same-pid', 'codec', 'slot'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                record, producer, slots = self.fixture(root)
                (producer / 'starting-save.json').write_text(json.dumps(record))
                run = json.loads((producer / 'run.json').read_bytes())
                state = dict(starter='squirtle', packet='5.5b', content_scope='critical',
                             codec=b_codec(), completed_steps=sorted(mj.B_STEPS))
                for index, group in enumerate(run['processes']):
                    packet = dict(schema=1, kind='midgame-saved', state=copy.deepcopy(state), **NoRuntime.identity)
                    if mutation == 'codec' and index == 1:
                        packet['state']['codec']['inventory'] = {'money': 1}
                    path = producer / group['journey_receipt']['path']
                    path.write_text(json.dumps(packet))
                    group['journey_receipt']['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
                if mutation == 'same-pid': run['processes'][1]['pid'] = 1
                if mutation == 'slot': (slots / 'adventure.b.json').write_bytes(b'changed')
                (producer / 'run.json').write_text(json.dumps(run))
                with patch.object(Path, 'home', return_value=root):
                    if mutation == 'none':
                        restarting.export_chain_save(self.scenario(), slots, producer, NoRuntime.identity)
                    else:
                        with self.assertRaises(ProtocolError):
                            restarting.export_chain_save(self.scenario(), slots, producer, NoRuntime.identity)
                chain = root / 'Developer/Pokemon-PlayDate-env/evidence/chain'
                if mutation == 'none':
                    self.assertTrue((chain / '5.5b/squirtle/provenance.json').is_file())
                    self.assertFalse((chain / '5.5a').exists())
                else:
                    self.assertFalse(chain.exists())


if __name__ == '__main__':
    unittest.main()
