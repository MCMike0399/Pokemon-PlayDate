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


if __name__ == '__main__':
    unittest.main()
