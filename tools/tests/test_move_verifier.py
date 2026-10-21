"""Offline B2W2 verifier contracts, independent tiny raw CSV fixtures."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout
from urllib.error import URLError

from tools.verify_moves.compare import Oracle, compare_learnset, verify
from tools.verify_moves.fetch_pokeapi import PinnedSources, SourceError
from tools.verify_moves.parse_lua import LuaParser, ParseError, ROOT, read_moves


def fixture():
    return {
        'version_groups': [{'id': '14', 'identifier': 'black-2-white-2'}],
        'types': [{'id': '1', 'identifier': 'normal'}],
        'move_damage_classes': [{'id': '2', 'identifier': 'physical'}],
        'moves': [dict(id=str(i), identifier=name, generation_id='1', type_id='1', power='40', pp='35',
                       accuracy='100', priority='0', damage_class_id='2', effect_id='1')
                  for i, name in [(1, 'pound'), (33, 'tackle')]],
        'move_changelog': [], 'move_meta': [],
        'pokemon_moves': [dict(pokemon_id='1', version_group_id='14', move_id=str(i),
                               pokemon_move_method_id='1', level='1', order=str(order))
                          for i, order in [(33, 1), (1, 2)]],
    }


def moves():
    return {key: dict(name=key.upper(), type='normal', category='physical', power=40,
                      accuracy=100, pp=35) for key in ('tackle', 'pound')}


def species():
    return {'dex': 1, 'moves': ['tackle', 'pound'],
            'learnset': [{'move': 'tackle', 'level': 1, 'order': 1}, {'move': 'pound', 'level': 1, 'order': 2}]}


class LearnsetTests(unittest.TestCase):
    def compare(self, row):
        return compare_learnset('fixture', row, Oracle(fixture()), moves())

    def test_ordered_level_aware_match(self):
        self.assertTrue(self.compare(species())['ok'])

    def test_flat_membership_is_never_success(self):
        row = species(); del row['learnset']
        self.assertIn('missing-level-metadata', [x['code'] for x in self.compare(row)['issues']])

    def test_wrong_level_fails_even_when_names_match(self):
        row = species(); row['learnset'][0]['level'] = 7
        self.assertFalse(self.compare(row)['ok'])

    def test_same_membership_wrong_sequence_fails(self):
        row = species(); row['learnset'].reverse(); row['moves'].reverse()
        self.assertEqual({'ordered-learnset-mismatch', 'ordered-move-names-mismatch'},
                         {x['code'] for x in self.compare(row)['issues']})

    def test_explicit_order_is_required_when_source_provides_it(self):
        row = species(); del row['learnset'][0]['order']
        self.assertFalse(self.compare(row)['ok'])

    def test_tie_fallback_uses_numeric_id_not_name_or_input_order(self):
        data = fixture()
        for row in data['pokemon_moves']: row['order'] = ''
        self.assertEqual(['pound', 'tackle'], [x['move'] for x in Oracle(data).learnsets[1]])

    def test_missing_order_sorts_after_explicit_order(self):
        data = fixture(); data['pokemon_moves'][1]['order'] = ''
        self.assertEqual(['tackle', 'pound'], [x['move'] for x in Oracle(data).learnsets[1]])

    def test_repeated_learning_events_are_not_collapsed_to_membership(self):
        data = fixture()
        data['pokemon_moves'].append(dict(data['pokemon_moves'][0], level='5', order=''))
        oracle = Oracle(data)
        self.assertEqual(['tackle', 'pound', 'tackle'], [row['move'] for row in oracle.learnsets[1]])
        row = species()
        self.assertFalse(compare_learnset('fixture', row, oracle, moves())['ok'])

    def test_other_versions_and_methods_are_excluded(self):
        data = fixture()
        for version, method in [('13', '1'), ('14', '4')]:
            data['pokemon_moves'].append(dict(data['pokemon_moves'][0], move_id='99999', version_group_id=version, pokemon_move_method_id=method))
        self.assertEqual(2, len(Oracle(data).learnsets[1]))

    def test_unknown_reference_move_id_fails_closed(self):
        data = fixture(); data['pokemon_moves'][0]['move_id'] = '99999'
        with self.assertRaisesRegex(SourceError, 'unknown learnset move ID'): Oracle(data)

    def test_unknown_local_move_is_reported(self):
        row = species(); row['moves'][0] = 'unknown'
        self.assertIn('unknown-move-key', {x['code'] for x in self.compare(row)['issues']})

    def test_invalid_local_level_schema_fails(self):
        row = species(); row['learnset'][0]['level'] = '1'
        self.assertIn('invalid-learnset-entry', {x['code'] for x in self.compare(row)['issues']})

    def test_duplicate_source_rows_fail(self):
        data = fixture(); data['pokemon_moves'].append(data['pokemon_moves'][0].copy())
        with self.assertRaisesRegex(SourceError, 'duplicate learnset row'): Oracle(data)

    def test_wrong_version_group_identity_fails(self):
        data = fixture(); data['version_groups'][0]['identifier'] = 'black-white'
        with self.assertRaises(SourceError): Oracle(data)


class MoveFieldTests(unittest.TestCase):
    def test_empty_inputs_cannot_succeed(self):
        for roster, library in [({}, moves()), ({'fixture': species()}, {})]:
            with self.assertRaises(SourceError): verify(roster, library, Oracle(fixture()))

    def test_scalar_fields_match_independent_oracle(self):
        self.assertTrue(verify({'fixture': species()}, moves(), Oracle(fixture()))['ok'])

    def test_each_relevant_field_mismatch_is_detected(self):
        for field, bad in [('type', 'water'), ('category', 'special'), ('pp', 2), ('power', 50), ('accuracy', 90), ('priority', 1)]:
            with self.subTest(field=field):
                rows = moves(); rows['pound'][field] = bad
                result = verify({'fixture': species()}, rows, Oracle(fixture()))
                failures = [x for x in result['move_fields'] if not x['ok']]
                self.assertEqual(field, failures[0]['issues'][0]['field'])

    def test_reverse_history_restores_earliest_post_b2w2_value_per_field(self):
        data = fixture()
        blank = dict(type_id='', power='', pp='', accuracy='', priority='', effect_id='')
        data['move_changelog'] = [dict(blank, move_id='33', changed_in_version_group_id='20', power='55', pp='25'),
                                  dict(blank, move_id='33', changed_in_version_group_id='15', power='50'),
                                  dict(blank, move_id='33', changed_in_version_group_id='14', power='99')]
        expected = Oracle(data).fields('tackle')
        self.assertEqual(50, expected['power']); self.assertEqual(25, expected['pp'])

    def test_pre_sv_snapshot_avoids_missing_gen_ix_pp_history(self):
        data = fixture(); data['moves_pre_sv'] = [dict(x, pp='10') for x in data['moves']]
        data['move_changelog_pre_sv'] = []
        self.assertEqual(10, Oracle(data).fields('pound')['pp'])

    def test_unmapped_move_key_is_failure(self):
        rows = moves(); rows['unmapped'] = rows['pound'].copy()
        result = verify({'fixture': species()}, rows, Oracle(fixture()))
        self.assertEqual(1, result['counts']['move_field_failures'])

    def test_missing_runtime_dispatch_never_counts_as_supported(self):
        rows = moves(); rows['pound'].update(category='status', power=0)
        result = verify({'fixture': species()}, rows, Oracle(fixture()))
        inventory = {x['move']: x for x in result['runtime_semantics']}
        self.assertEqual('status-dispatch-review-required', inventory['pound']['status'])
        self.assertFalse(result['ok'])

    def test_explicit_ohko_dispatch_still_requires_independent_runtime_evidence(self):
        rows = moves(); rows['pound'].update(power=0, ohko=True)
        result = verify({'fixture': species()}, rows, Oracle(fixture()))
        inventory = {x['move']: x for x in result['runtime_semantics']}
        self.assertEqual('requires-independent-runtime-contract', inventory['pound']['status'])
        self.assertFalse(result['runtime_semantics_complete'])
        rows['pound']['ohko'] = False
        result = verify({'fixture': species()}, rows, Oracle(fixture()))
        inventory = {x['move']: x for x in result['runtime_semantics']}
        self.assertEqual('missing-damage-dispatch', inventory['pound']['status'])


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.raw = b'id,identifier\n14,black-2-white-2\n'
        self.manifest = {'revision': 'a' * 40, 'files': {'version_groups.csv': {
            'sha256': hashlib.sha256(self.raw).hexdigest(), 'columns': ['id', 'identifier']}}}

    def source(self, **options):
        return PinnedSources(self.root, manifest=self.manifest, **options)

    def test_missing_offline_cache_is_error(self):
        with self.assertRaisesRegex(SourceError, 'missing pinned cache'): self.source().load('version_groups.csv')

    def test_valid_cache_requires_no_network(self):
        (self.root / 'version_groups.csv').write_bytes(self.raw)
        def unavailable(*args, **kwargs): self.fail('network called despite cached input')
        self.assertEqual('14', self.source(opener=unavailable).load('version_groups.csv')[0]['id'])

    def test_corrupt_cache_is_preserved_and_never_silently_refetched(self):
        path = self.root / 'version_groups.csv'; path.write_bytes(b'corrupt')
        def unavailable(*args, **kwargs): self.fail('corrupt cache silently refetched')
        with self.assertRaisesRegex(SourceError, 'checksum mismatch'): self.source(fetch=True, opener=unavailable).load('version_groups.csv')
        self.assertEqual(b'corrupt', path.read_bytes())

    def test_fetch_failure_is_structured_error(self):
        def unavailable(*args, **kwargs): raise URLError('offline fixture')
        with self.assertRaisesRegex(SourceError, 'offline fixture'): self.source(fetch=True, opener=unavailable).load('version_groups.csv')

    def test_wrong_download_hash_is_not_cached(self):
        def bad(*args, **kwargs): return io.BytesIO(b'wrong')
        with self.assertRaises(SourceError): self.source(fetch=True, opener=bad).load('version_groups.csv')
        self.assertFalse((self.root / 'version_groups.csv').exists())

    def test_schema_failure_even_with_valid_hash(self):
        self.manifest['files']['version_groups.csv']['columns'] = ['wrong']
        (self.root / 'version_groups.csv').write_bytes(self.raw)
        with self.assertRaisesRegex(SourceError, 'schema mismatch'): self.source().load('version_groups.csv')

    def test_truncated_row_fails_schema(self):
        raw = b'id,identifier\n14\n'
        self.manifest['files']['version_groups.csv']['sha256'] = hashlib.sha256(raw).hexdigest()
        (self.root / 'version_groups.csv').write_bytes(raw)
        with self.assertRaisesRegex(SourceError, 'malformed rows'): self.source().load('version_groups.csv')

    def test_successful_download_uses_immutable_revision_and_caches(self):
        seen = []
        def fetch(request, **kwargs): seen.append(request.full_url); return io.BytesIO(self.raw)
        self.source(fetch=True, opener=fetch).load('version_groups.csv')
        self.assertIn('/' + 'a' * 40 + '/', seen[0])
        self.assertEqual(self.raw, (self.root / 'version_groups.csv').read_bytes())


class ParserAndCLITests(unittest.TestCase):
    def test_reads_actual_full_production_tables_without_execution(self):
        species_rows, move_rows = LuaParser().parse(), read_moves()
        self.assertEqual(151, len(species_rows)); self.assertEqual(425, len(move_rows))
        original = json.loads((Path(__file__).resolve().parents[1] / 'references/early-combat.json').read_text())
        self.assertEqual(set(move_rows), set(original['original_keys']) | set(original['new_keys']) | {'bide'})
        self.assertEqual({k: move_rows['bide'][k] for k in ('type','category','power','accuracy','pp','priority','targetId','contact','damageRule')},
                         dict(type='normal',category='physical',power=0,accuracy=0,pp=10,priority=1,targetId=7,contact=True,damageRule='bide'))
        self.assertTrue(all(row.get('learnset') for row in species_rows.values()))
        self.assertEqual(2184, sum(len(row['learnset']) for row in species_rows.values()))
        for key in ('charm', 'psywave', 'stormThrow', 'struggle', 'toxic'):
            self.assertIn(key, move_rows)
        self.assertIsInstance(move_rows['tackle']['pp'], int)
        self.assertEqual(10, move_rows['toxic']['pp'])
        self.assertEqual(90, move_rows['toxic']['accuracy'])

    def test_nested_level_metadata_parses_without_losing_order(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.lua'
            path.write_text('pokemonData = { sample = { dex = 1, moves = {"tackle"}, learnset = {{move = "tackle", level = 3, order = 2}} } }')
            row = LuaParser(path).parse()['sample']
            self.assertEqual([{'move': 'tackle', 'level': 3, 'order': 2}], row['learnset'])

    def test_malformed_or_duplicate_lua_data_fails_closed(self):
        for text in ['pokemonData = {x = { dex=1, moves={"tackle"}',
                     'pokemonData={x={dex=1,moves={"tackle"}},x={dex=2,moves={"pound"}}}',
                     'pokemonData={x={dex=1,moves={dynamicMove()}}}']:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'fixture.lua'; path.write_text(text)
                with self.assertRaises(ParseError): LuaParser(path).parse()

    def test_cli_content_gap_exit_and_success_exit_are_distinct(self):
        from tools.verify_moves.main import main
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pokemon, move_file = root / 'pokemon.lua', root / 'moves.lua'
            move_file.write_text('moveData={tackle=Move{name="TACKLE",type="normal",category="physical",power=40,accuracy=100,pp=35},pound=Move{name="POUND",type="normal",category="physical",power=40,accuracy=100,pp=35}}')
            for has_levels, expected_code in [(False, 1), (True, 0)]:
                extra = ',learnset={{move="tackle",level=1,order=1},{move="pound",level=1,order=2}}' if has_levels else ''
                pokemon.write_text('pokemonData={fixture={dex=1,moves={"tackle","pound"}' + extra + '}}')
                output = root / f'result-{has_levels}.json'
                with patch('tools.verify_moves.main.PinnedSources.all', return_value=fixture()), redirect_stdout(io.StringIO()):
                    code = main(['fixture', '--pokemon', str(pokemon), '--moves', str(move_file), '--output', str(output)])
                self.assertEqual(expected_code, code)
                self.assertEqual(has_levels, json.loads(output.read_text())['ok'])

    def test_cli_source_failure_has_nonzero_exit_and_json_diagnostic(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'failure.json'
            result = subprocess.run([sys.executable, str(ROOT / 'tools/verify_moves/main.py'), '--cache', directory, '--output', str(output)], capture_output=True, text=True)
            self.assertEqual(2, result.returncode)
            self.assertEqual('source-or-schema-error', json.loads(output.read_text())['kind'])


if __name__ == '__main__':
    unittest.main()
