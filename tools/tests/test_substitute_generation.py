"""Epoch19 producer/history and pinned Gen V Substitute policy qualification."""
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import move_producer_contract as c
from tools import generate_gen5_data as generator
from tools import generate_substitute_policy as policy
from tools.check_contact_ability_sources import load
from tools.generate_ability_move_metadata import entries
from tools.verify_moves.fetch_pokeapi import PinnedSources

ROOT = c.ROOT
BASE = '83337bc09a6c4d84bfdffaef2da6ae5651a06dfd'


def historical(name):
    return subprocess.check_output(['git', 'show', BASE + ':' + name], cwd=ROOT)


class SubstituteProducerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = load()
        pinned = PinnedSources()
        cls.data = {name: pinned.load(file) for name, file in (
            ('moves', 'moves_pre_sv.csv'), ('move_changelog', 'move_changelog_pre_sv.csv'),
            ('move_meta', 'move_meta.csv'), ('move_meta_stat_changes', 'move_meta_stat_changes.csv'), ('types', 'types.csv'))}
        cls.before_text = historical('Source/battle/moves.lua').decode()
        cls.after_text = (ROOT / 'Source/battle/moves.lua').read_text()

    def generate(self, text, directory):
        source, target = directory / 'input.lua', directory / 'output.lua'
        source.write_text(text)
        with patch.object(generator, 'MOVES_INPUT', str(source)), patch.object(generator, 'MOVES_LUA', str(target)), patch.object(generator, 'EXTRA_MOVE_KEYS', []):
            generator.generate_moves(self.data, True)
        return target.read_text()

    def test_exact_epoch18_upgrades_once_and_epoch19_reproduces_without_other_row_changes(self):
        self.assertEqual(c.producer_epoch(self.before_text), 18)
        self.assertEqual(c.producer_epoch(self.after_text), 19)
        before, after = c.read_rows(self.before_text), c.read_rows(self.after_text)
        self.assertEqual(len(after), 425)
        # d9c39c11 on main is the substitute port and changes only that row.
        # 8195076c and efd093cb then add rampage, recharge, defrost, Low Kick,
        # Sunny Day, and Hail. Those fields are introduced at epoch 19 so the
        # epoch-18 snapshot still inverts, and the generator reproduces them.
        ported = c.read_rows(subprocess.check_output(
            ['git', 'show', 'd9c39c11:Source/battle/moves.lua'], cwd=ROOT, text=True))
        self.assertEqual({key for key in before if before[key] != ported[key]}, {'substitute'})
        self.assertEqual({key for key in before if before[key] != after[key]}, {
            'substitute', 'thrash', 'outrage', 'hyperBeam', 'gigaImpact',
            'flameWheel', 'flareBlitz', 'lowKick', 'sunnyDay', 'hail'})
        self.assertEqual(c.split_payload(before['substitute'])[0], c.split_payload(after['substitute'])[0])
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.assertEqual(self.generate(self.before_text, directory), self.after_text)
            self.assertEqual(self.generate(self.after_text, directory), self.after_text)

    def test_current_payload_deletion_rollback_extra_effect_and_scalar_mutants_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for old, new in [('SubstituteEffect()', 'NoEffect()'), ('SubstituteEffect()', 'SubstituteEffect(), Heal(ATTACKER, 1)'),
                             ('SubstituteEffect()', ''), ('-- move-producer-contract: 19', '-- move-producer-contract: 18'), ('name = "SUBSTITUTE", type = "normal", category = "status", power = 0', 'name = "SUBSTITUTE", type = "normal", category = "status", power = 1')]:
                with self.subTest(mutation=(old, new)), self.assertRaisesRegex(ValueError, 'unexpected changes'):
                    self.generate(self.after_text.replace(old, new, 1), directory)
        rows = c.read_rows(self.after_text)
        rollback = dict(rows, substitute=c.read_rows(self.before_text)['substitute'])
        with self.assertRaisesRegex(ValueError, 'declared migration substitute'):
            c.legacy_rows(rollback, 19)

    def test_all_existing_migration_edges_original_hashes_and_epoch18_inverse_are_retained(self):
        old = json.loads(historical('tools/references/move-producer-migrations.json'))
        new = c.load_contract()
        # sunnyDay and hail are the epoch-19 weather edges for efd093cb.
        self.assertEqual(set(new['transitions']) - set(old['transitions']), {'substitute', 'sunnyDay', 'hail'})
        for key, value in old['transitions'].items():
            self.assertEqual(new['transitions'][key], value, key)
        for key in old:
            if key not in ('transitions', 'policy'):
                self.assertEqual(new[key], old[key], key)
        before = c.legacy_rows(c.read_rows(self.before_text), 18)
        after = c.legacy_rows(c.read_rows(self.after_text), 19)
        self.assertEqual(after, before)
        self.assertEqual(c.legacy_rows(c.read_rows(self.after_text)), after)
        with self.assertRaisesRegex(ValueError, 'future move effect'):
            c.legacy_rows(c.read_rows(self.after_text), 18)
        self.assertEqual(len(after), 424)
        self.assertEqual(c.digest(json.dumps(after, sort_keys=True, separators=(',', ':')).encode()),
                         'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')

    def test_pinned_policy_reproduces_all430_flags_and_explicit_gen5_exceptions(self):
        raw, lua = policy.build()
        self.assertEqual(policy.ARTIFACT.read_bytes(), raw)
        self.assertEqual(policy.LUA.read_text(), lua)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), c.load_contract()['substitute_policy_sha256'])
        rows = json.loads(raw)['bypass']
        self.assertEqual(len(rows), 430)
        runtime_keys = set(re.findall(r'^moveData\.(\w+)\s*=\s*Move\s*\{', (ROOT / 'Source/data/fieldMoveBattleData.lua').read_text(), re.M))
        self.assertEqual(set(rows), set(c.read_rows(self.after_text)) | runtime_keys)
        self.assertEqual(len(runtime_keys), 5)
        for key in runtime_keys:
            self.assertIs(rows[key], False, key)
        for key in ('roar', 'whirlwind', 'disable', 'encore', 'foresight', 'odorSleuth', 'curse', 'haze'):
            self.assertIs(rows[key], True, key)
        for key in ('sing', 'supersonic', 'snore', 'hyperVoice', 'bugBuzz', 'yawn', 'worrySeed', 'clearSmog', 'bide'):
            self.assertIs(rows[key], False, key)
        sub = entries(self.sources['ps_data_mods_gen5_moves.ts'])['substitute']
        self.assertNotIn('move.infiltrates', sub)
        self.assertIn("move.flags['bypasssub']", sub)

    def test_policy_replaces_multiline_flags_and_never_infers_sound_bypass(self):
        base = '\tx: {\n\t\tflags: { bypasssub: 1, sound: 1 },\n\t},\n'
        override = '\tx: {\n\t\tinherit: true,\n\t\tflags: {\n\t\t\tsound: 1,\n\t\t},\n\t},\n'
        sources = {'ps_data_moves.ts': base, **{f'ps_data_mods_gen{g}_moves.ts': '' for g in (8,7,6,5)}}
        self.assertEqual(policy.project(sources, ['x']), {'x': True})
        sources['ps_data_mods_gen5_moves.ts'] = override
        self.assertEqual(policy.project(sources, ['x']), {'x': False})
        with self.assertRaisesRegex(ValueError, 'missing primary flag'):
            policy.project(sources, ['unknown'])

    def test_current_singles_after_sub_damage_callback_inventory_and_intimidate_are_explicit(self):
        support = json.loads((ROOT / 'tools/references/move-support.json').read_text())['moves']
        resolved = {}
        for name in ['ps_data_moves.ts'] + [f'ps_data_mods_gen{g}_moves.ts' for g in (8,7,6,5)]:
            for key, body in entries(self.sources[name]).items():
                # Inherited literal callback bodies are replaced only at their
                # actual callback declaration; unrelated overrides retain them.
                if '\n\t\tonAfterSubDamage' in '\n' + body:
                    resolved[key] = body
        enabled = {key for key, value in support.items() if 'handler' in value}
        callbacks = {key for key in enabled if key.lower() in resolved}
        self.assertEqual(callbacks, {'rapidSpin', 'flameBurst'})
        self.assertIn('pokemon.hp && pokemon.removeVolatile', resolved['rapidspin'])
        self.assertIn('target.adjacentAllies()', resolved['flameburst'])
        intimidate = entries(self.sources['ps_data_abilities.ts'])['intimidate']
        self.assertIn("if (target.volatiles['substitute'])", intimidate)
        for generation in (8,7,6,5):
            override = entries(self.sources[f'ps_data_mods_gen{generation}_abilities.ts']).get('intimidate', '')
            self.assertNotIn('onStart', override)


if __name__ == '__main__':
    unittest.main()
