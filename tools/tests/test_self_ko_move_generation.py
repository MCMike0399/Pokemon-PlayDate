"""Exact two-row epoch18 metadata and fail-closed producer preservation."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen, ROOT

KEYS = ('selfDestruct', 'explosion')


def current():
    rows = c.read_rows((ROOT / 'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 18\n' + '\n'.join('    ' + key + ' = ' + rows[key] for key in KEYS) + '\n'


def fixture():
    moves = [dict(id=str(i), identifier=name, type_id='1', damage_class_id='2',
                  power=str(power), accuracy='100', pp='5', target_id='9', priority='0',
                  effect_chance='', generation_id='1')
             for i, name, power in ((120, 'self-destruct', 200), (153, 'explosion', 250))]
    return dict(moves=moves, move_changelog=[], move_meta=[], move_meta_stat_changes=[],
                types=[dict(id='1', identifier='normal')])


def generate(text, directory):
    source, target = directory / 'input.lua', directory / 'output.lua'
    source.write_text(text)
    with patch.object(gen, 'MOVES_INPUT', str(source)), patch.object(gen, 'MOVES_LUA', str(target)), patch.object(gen, 'EXTRA_MOVE_KEYS', []):
        gen.generate_moves(fixture(), True)
    return target.read_text()


class SelfKOProducerTests(unittest.TestCase):
    def test_epoch17_to18_only_adds_declared_two_flags_and_regenerates(self):
        before = current().replace('contract: 18', 'contract: 17').replace(', selfDestruct = true', '')
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            after = generate(before, directory)
            self.assertEqual(c.producer_epoch(after), 19)
            self.assertEqual(c.read_rows(after), c.read_rows(current()))
            self.assertEqual(generate(after, directory), after)
            for key in KEYS:
                self.assertEqual(c.drop_fields(c.read_rows(after)[key], ('selfDestruct',)), c.read_rows(before)[key])

    def test_epoch18_flag_deletion_wrong_type_identity_and_original_scalar_mutants_reject(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            after = generate(current(), directory)
            for old, new in [(', selfDestruct = true', ''), ('selfDestruct = true', 'selfDestruct = false'),
                             ('selfDestruct = true', 'selfDestruct = "always"'), ('power = 200', 'power = 400'),
                             ('pp = 5', 'pp = 10'), ('targetId = 9', 'targetId = 10'),
                             ('protectable = true', 'protectable = false')]:
                with self.subTest(mutation=(old, new)), self.assertRaisesRegex(ValueError, 'unexpected changes'):
                    generate(after.replace(old, new, 1), directory)

    def test_current_inverse_and_missing_current_flags_fail_closed(self):
        rows = c.read_rows((ROOT / 'Source/battle/moves.lua').read_text())
        lowered = c.legacy_rows(rows, 19)
        self.assertEqual(len(lowered), 424)
        self.assertEqual(c.digest(json.dumps(lowered, sort_keys=True, separators=(',', ':')).encode()),
                         c.load_contract()['legacy_rows_sha256'])
        for key in KEYS:
            mutant = dict(rows)
            mutant[key] = c.drop_fields(rows[key], ('selfDestruct',))
            with self.subTest(key=key), self.assertRaises(ValueError):
                c.legacy_rows(mutant, 19)
            self.assertEqual(c.RULE_EPOCHS[key], 18)


if __name__ == '__main__':
    unittest.main()
