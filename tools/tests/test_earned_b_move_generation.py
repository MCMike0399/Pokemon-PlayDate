"""Exact five-row epoch17 migration and fail-closed producer preservation."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen, ROOT

KEYS = ('rest', 'snore', 'foresight', 'revenge', 'yawn')
EFFECTS = {'rest': 'RestEffect()', 'foresight': 'ForesightEffect()', 'yawn': 'YawnEffect()'}
INVERSE = 'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea'


def fixture():
    vectors = [(156, 'rest', 14, 1, 0, 0, 10, 7, 0),
               (173, 'snore', 1, 3, 40, 100, 15, 10, 0),
               (193, 'foresight', 1, 1, 0, 0, 40, 10, 0),
               (279, 'revenge', 2, 2, 60, 100, 10, 10, -4),
               (281, 'yawn', 1, 1, 0, 0, 10, 10, 0)]
    columns = ('id', 'identifier', 'type_id', 'damage_class_id', 'power', 'accuracy', 'pp', 'target_id', 'priority')
    moves = [dict(zip(columns, map(str, row)), effect_chance='', generation_id='1') for row in vectors]
    meta = [dict(move_id='173', meta_ailment_id='0', ailment_chance='0', flinch_chance='30',
                 stat_chance='0', healing='0', drain='0', min_hits='', max_hits='')]
    return dict(moves=moves, move_changelog=[], move_meta=meta, move_meta_stat_changes=[],
                types=[dict(id=str(i), identifier=name) for i, name in ((1, 'normal'), (2, 'fighting'), (14, 'psychic'))])


def current():
    rows = c.read_rows((ROOT / 'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 17\n' + '\n'.join('    ' + key + ' = ' + rows[key] for key in KEYS) + '\n'


def prior():
    text = current().replace('contract: 17', 'contract: 16')
    for effect in EFFECTS.values():
        text = text.replace(', effects = { ' + effect + ' }', '')
    return text.replace(', attemptRule = "snore"', '').replace(', powerRule = "revenge"', '')


def generate(text, directory):
    source = directory / 'input.lua'
    target = directory / 'output.lua'
    source.write_text(text)
    with patch.object(gen, 'MOVES_INPUT', str(source)), patch.object(gen, 'MOVES_LUA', str(target)), patch.object(gen, 'EXTRA_MOVE_KEYS', []):
        gen.generate_moves(fixture(), True)
    return target.read_text()


class EarnedBProducerTests(unittest.TestCase):
    def test_exact_epoch16_to17_five_rows_and_idempotent_regeneration(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            result = generate(prior(), directory)
            before, after = c.read_rows(prior()), c.read_rows(result)
            self.assertEqual(c.producer_epoch(result), 19)
            self.assertEqual(after, c.read_rows(current()))
            self.assertEqual(set(before), set(KEYS))
            self.assertEqual({k for k in before if before[k] != after[k]}, set(KEYS))
            for key in KEYS:
                fields = dict(c.fields(after[key]))
                for field in ('attemptRule', 'powerRule'):
                    fields.pop(field, None)
                for field in c.PAYLOAD:
                    fields.pop(field, None)
                old = {k: v for k, v in c.fields(before[key]).items() if k not in c.PAYLOAD}
                self.assertEqual(fields, old)
            self.assertEqual(generate(result, directory), result)

    def test_current_rule_deletion_wrong_type_wrong_identity_and_scalar_mutants_reject(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            text = generate(prior(), directory)
            for token in ('attemptRule = "snore"', 'powerRule = "revenge"'):
                for replacement in ('', ', ' + token.split(' = ')[0] + ' = true', ', ' + token.replace('"snore"', '"sleepTalk"').replace('"revenge"', '"assurance"')):
                    with self.subTest(token=token, replacement=replacement), self.assertRaisesRegex(ValueError, 'unexpected changes'):
                        generate(text.replace(', ' + token, replacement, 1), directory)
            for old, new in [('power = 40', 'power = 50'), ('pp = 10', 'pp = 5'),
                             ('priority = -4', 'priority = 0'), ('Chance(30)', 'Chance(31)')]:
                with self.subTest(mutation=(old, new)), self.assertRaisesRegex(ValueError, 'unexpected changes'):
                    generate(text.replace(old, new, 1), directory)

    def test_current_payload_deletion_rollback_and_undeclared_intermediates_reject(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            text = generate(prior(), directory)
            for effect in EFFECTS.values():
                for replacement in ('NoEffect()', 'ApplyStatus(DEFENDER, "sleep")', effect + ', NoEffect()'):
                    with self.subTest(effect=effect, replacement=replacement), self.assertRaisesRegex(ValueError, 'unexpected changes'):
                        generate(text.replace(effect, replacement, 1), directory)
                with self.subTest(effect=effect), self.assertRaisesRegex(ValueError, 'unexpected changes'):
                    generate(text.replace(', effects = { ' + effect + ' }', '', 1), directory)
            for key in KEYS:
                meta = c.producer_metadata()[key]
                old, new = c.read_rows(prior())[key], c.read_rows(text)[key]
                self.assertTrue(c.compatible(key, old, new, meta, epoch=16))
                self.assertFalse(c.compatible(key, old, new, meta, epoch=17))
                self.assertFalse(c.compatible(key, new, old, meta, epoch=17))

    def test_current_inverse_and_genuine_epoch16_export_preserve_all_original424_hashes(self):
        text = (ROOT / 'Source/battle/moves.lua').read_text()
        rows = c.read_rows(text)
        self.assertEqual(len(rows), 425)
        legacy = c.legacy_rows(rows, 19)
        historical = dict(rows, **c.read_rows(prior()))
        historical["substitute"] = c.split_payload(rows["substitute"])[0] + " },"
        for key in ("selfDestruct", "explosion"):
            historical[key] = c.drop_fields(historical[key], ("selfDestruct",))
        self.assertEqual(c.legacy_rows(historical, 16), legacy)
        self.assertEqual(len(legacy), 424)
        self.assertEqual(c.digest(json.dumps(legacy, sort_keys=True, separators=(',', ':')).encode()), INVERSE)
        self.assertEqual(c.RULE_EPOCHS['chipAway'], 14)
        self.assertEqual(c.RULE_EPOCHS['snore'], 17)
        self.assertEqual(c.RULE_EPOCHS['revenge'], 17)
        transitions = c.load_contract()['transitions']
        self.assertEqual(transitions['reflect'][-1]['version'], 15)
        self.assertEqual(transitions['haze'][-1]['version'], 16)
        self.assertEqual(transitions['clearSmog'][-1]['version'], 16)
        for key in EFFECTS:
            self.assertEqual(transitions[key][-1]['version'], 17)
        for key in KEYS:
            mutated = dict(rows)
            if key in EFFECTS:
                mutated[key] = c.split_payload(rows[key])[0] + ' },'
            else:
                mutated[key] = c.drop_fields(rows[key], ('attemptRule', 'powerRule'))
            with self.subTest(key=key), self.assertRaises(ValueError):
                c.legacy_rows(mutated, 19)


if __name__ == '__main__':
    unittest.main()
