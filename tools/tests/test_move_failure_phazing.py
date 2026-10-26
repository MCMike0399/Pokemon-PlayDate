"""Fail-closed support inventory and exact Gen V phazing producer migrations.

The behavior contracts run separately in the actual SDK, by the runtime owner.
"""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import generate_move_support as support
from tools import move_producer_contract as contract
from tools.generate_ability_move_metadata import REV, FILES
from tools.tests.test_move_producer_contract import gen

ROOT = Path(__file__).resolve().parents[2]


def phaze_fixture():
    rows = []
    for number, identifier in [(18, 'whirlwind'), (46, 'roar')]:
        rows.append(dict(id=str(number), identifier=identifier, type_id='1',
                         damage_class_id='1', power='', accuracy='100', pp='20',
                         target_id='10', priority='-6', effect_chance='', generation_id='1'))
    return dict(moves=rows, move_changelog=[], move_meta=[],
                move_meta_stat_changes=[], types=[dict(id='1', identifier='normal')])


class MoveFailurePhazingTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / 'Source/battle/moves.lua').read_text()
        self.rows = contract.read_rows(self.text)
        self.inventory = json.loads((ROOT / 'tools/references/move-support.json').read_text())

    def test_frozen_packet_matches_canonical_manifest(self):
        folder = ROOT / 'docs/plans/implementation-handoffs'
        manifest = json.loads((folder / 'manifest.json').read_text())
        entry = next(e for e in manifest['packets'] if e['packet'] == 'pokemon-whirlwind-01')
        self.assertEqual(entry['sha256'], '7e82e300fda92fa1435e4cec6a00b795e5d90bb8464b4b5732fb0929c03f3d79')
        self.assertEqual(hashlib.sha256((folder / entry['archive']).read_bytes()).hexdigest(), entry['sha256'])

    def test_generated_inventory_is_complete_and_pins_the_default_gen5_oracle(self):
        self.assertEqual(self.inventory['oracle'], dict(revision=REV, source_sha256=FILES))
        self.assertEqual(set(self.inventory['moves']), set(self.rows))
        self.assertEqual(support.render(), (ROOT / 'Source/battle/moveSupport.lua').read_text())

    def test_missing_new_move_and_invalid_support_decisions_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools/references').mkdir(parents=True)
            (root / 'Source/battle').mkdir(parents=True)
            (root / 'Source/battle/moves.lua').write_text(self.text)
            path = root / 'tools/references/move-support.json'
            del self.inventory['moves']['tackle']
            path.write_text(json.dumps(self.inventory))
            with self.assertRaisesRegex(ValueError, 'exact move registry'):
                support.render(root)
            self.inventory['moves']['tackle'] = {'handler': 'automatic-from-power'}
            path.write_text(json.dumps(self.inventory))
            with self.assertRaisesRegex(ValueError, 'invalid move support'):
                support.render(root)

    def test_damage_and_partial_status_special_cases_cannot_pass_as_plain_attacks(self):
        keys = ('dig', 'razorWind', 'magnitude', 'furyCutter', 'gyroBall',
                'hyperBeam', 'thrash', 'focusPunch', 'falseSwipe', 'dreamEater',
                'selfDestruct', 'payDay', 'circleThrow', 'dragonTail', 'bugBite',
                'reflect', 'haze', 'rest', 'substitute', 'transform', 'metronome',
                'stockpile', 'swallow', 'memento', 'flatter', 'swagger', 'healPulse')
        for key in keys:
            with self.subTest(move=key):
                self.assertTrue(self.inventory['moves'][key]['gap'])

    def test_explicit_existing_handlers_are_not_mistaken_for_empty_effects(self):
        # These rules intentionally have no generic effects array or zero power.
        for key in ('bide', 'solarBeam', 'skullBash', 'petalDance', 'rollout',
                    'electroBall', 'endeavor', 'suckerPunch', 'feint', 'struggle',
                    'guillotine', 'sonicBoom', 'psywave', 'ragePowder', 'helpingHand'):
            with self.subTest(move=key):
                self.assertIn('handler', self.inventory['moves'][key])
        for key, entry in self.inventory['moves'].items():
            row = contract.fields(self.rows[key])
            if entry.get('handler') in ('dsl', 'engine-dsl') and row['category'] == 'status' and not row.get('attemptRule'):
                self.assertTrue(row.get('effects'), key)
        self.assertEqual(self.inventory['moves']['splash']['handler'], 'intentional-no-effect')

    def generate(self, text, folder):
        source, output = folder / 'input.lua', folder / 'output.lua'
        source.write_text(text)
        with patch.object(gen, 'MOVES_INPUT', str(source)), patch.object(gen, 'MOVES_LUA', str(output)), patch.object(gen, 'EXTRA_MOVE_KEYS', []):
            gen.generate_moves(phaze_fixture(), True)
        return output.read_text()

    def test_phazing_migration_only_adds_typed_payload_and_is_idempotent(self):
        old = '-- move-producer-contract: 12\n'
        for key in ('whirlwind', 'roar'):
            prefix, _ = contract.split_payload(self.rows[key])
            suffix = contract.load_contract()['transitions'][key][0]['legacy_suffix']
            old += '    ' + key + ' = ' + prefix + suffix + '\n'
        with tempfile.TemporaryDirectory() as folder:
            output = self.generate(old, Path(folder))
            self.assertEqual(self.generate(output, Path(folder)), output)
        for key, row in contract.read_rows(output).items():
            fields = contract.fields(row)
            self.assertEqual((fields['power'], fields['accuracy'], fields['pp'], fields['priority'], fields['targetId']), (0, 100, 20, -6, 10))
            self.assertEqual(row, self.rows[key])
            self.assertEqual(contract.payload(row), dict(effects=['ForceSwitchEffect ( DEFENDER )'], secondaries=[]))

    def test_payload_rollback_wrong_target_and_unrelated_mutations_reject(self):
        text = '-- move-producer-contract: 13\n' + '\n'.join('    ' + k + ' = ' + self.rows[k] for k in ('whirlwind', 'roar'))
        for before, after in [('ForceSwitchEffect(DEFENDER)', 'NoEffect()'),
                              ('ForceSwitchEffect(DEFENDER)', 'ForceSwitchEffect(ATTACKER)'),
                              (', effects = { ForceSwitchEffect(DEFENDER) }', ''),
                              ('accuracy = 100', 'accuracy = 0'), ('pp = 20', 'pp = 21')]:
            with tempfile.TemporaryDirectory() as folder, self.subTest(mutation=after):
                with self.assertRaisesRegex(ValueError, 'unexpected changes'):
                    self.generate(text.replace(before, after, 1), Path(folder))


if __name__ == '__main__':
    unittest.main()
