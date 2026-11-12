"""Pinned-oracle and exact-B149 preservation checks; no Lua execution claim."""
import hashlib
import json
import re
import subprocess
import unittest

from tools.check_contact_ability_sources import ROOT, load
from tools.generate_ability_move_metadata import entries
from tools import move_producer_contract as c

BASE = '83337bc09a6c4d84bfdffaef2da6ae5651a06dfd'


def base_bytes(name):
    return subprocess.check_output(['git', 'show', BASE + ':' + name], cwd=ROOT)


class SubstituteSeamTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = load()  # Existing local immutable cache; checks every SHA256.

    def test_oracle_inheritance_and_cost_trapping_rules(self):
        base = entries(self.sources['ps_data_moves.ts'])['substitute']
        for generation in (8, 7, 6):
            self.assertNotIn('substitute', entries(self.sources[f'ps_data_mods_gen{generation}_moves.ts']))
        self.assertIn('source.hp <= source.maxhp / 4 || source.maxhp === 1', base)
        self.assertIn('this.directDamage(target.maxhp / 4)', base)
        self.assertIn('Math.floor(target.maxhp / 4)', base)
        self.assertIn("delete target.volatiles['partiallytrapped']", base)
        self.assertNotIn('onTryHit', entries(self.sources['ps_data_mods_gen5_moves.ts'])['substitute'])

    def test_gen5_primary_interception_caps_before_per_hit_recoil_then_ceil_drain(self):
        sub = entries(self.sources['ps_data_mods_gen5_moves.ts'])['substitute']
        self.assertIn("target === source || move.flags['bypasssub']", sub)
        self.assertNotIn('infiltrates', sub)
        cap = sub.index("damage = target.volatiles['substitute'].hp as number")
        commit = sub.index("target.volatiles['substitute'].hp -= damage")
        recoil = sub.index('this.actions.applyRecoilDamage(damage, move, source)')
        drain = sub.index('Math.ceil(damage * move.drain[0] / move.drain[1])')
        after = sub.index("this.singleEvent('AfterSubDamage'")
        terminal = sub.index('return this.HIT_SUBSTITUTE')
        self.assertEqual(sorted((cap, commit, recoil, drain, after, terminal)),
                         [cap, commit, recoil, drain, after, terminal])
        self.assertIn('Math.round(damageDealt * move.recoil[0] / move.recoil[1])',
                      self.sources['ps_sim_battle-actions.ts'])

    def test_all_current_recoil_and_drain_encodings_match_exact_oracle_ratios(self):
        resolved = {}
        for name in ['ps_data_moves.ts'] + [f'ps_data_mods_gen{g}_moves.ts' for g in (8, 7, 6, 5)]:
            for key, body in entries(self.sources[name]).items():
                ratios = dict(re.findall(r'^\t\t(recoil|drain): (\[[^\]]+\])', body, re.M))
                resolved.setdefault(key, {}).update(ratios)
        rows = c.read_rows((ROOT / 'Source/battle/moves.lua').read_text())
        seen = set()
        for key, row in rows.items():
            value = c.fields(row).get('drain')
            if value is None:
                continue
            # fields stores tokenized scalar strings. No approximation inference
            # from power/category: every emitted drain encoding needs an oracle.
            value = int(value)
            expected = {50: ('drain', '[1, 2]'), -25: ('recoil', '[1, 4]'), -33: ('recoil', '[33, 100]')}
            self.assertIn(value, expected, key)
            field, ratio = expected[value]
            self.assertEqual(resolved[key.lower()][field], ratio, key)
            seen.add(value)
        self.assertEqual(seen, {50, -25, -33})

    def test_exact_base_schema_scalars_inverse_and_remaining_gaps_preserved(self):
        names = ['Source/data/pokemon.lua', 'Source/domain/sessionCodec.lua',
                 'Source/domain/pokemonCodec.lua', 'Source/data/sourceMaps.json']
        pins = {
            # e6e32628 keeps the v4 codec and adds the Hall of Fame team record.
            'Source/domain/sessionCodec.lua': 'e6e32628',
            # 68ff3b1f installs the remaining source maps. Its blob matches this tree.
            'Source/data/sourceMaps.json': '68ff3b1f',
        }
        for name in names:
            expected = (subprocess.check_output(['git', 'show', pins[name] + ':' + name], cwd=ROOT)
                        if name in pins else base_bytes(name))
            self.assertEqual((ROOT / name).read_bytes(), expected, name)
        text = (ROOT / 'Source/battle/moves.lua').read_text()
        self.assertEqual(c.producer_epoch(text), 19)
        legacy = c.legacy_rows(c.read_rows(text), 19)
        self.assertEqual(len(legacy), 424)
        self.assertEqual(hashlib.sha256(json.dumps(legacy, sort_keys=True, separators=(',', ':')).encode()).hexdigest(),
                         c.load_contract()['legacy_rows_sha256'])
        support = json.loads((ROOT / 'tools/references/move-support.json').read_text())
        for key in ('recycle', 'trick'):
            self.assertIn('gap', support['moves'][key])
        before = c.read_rows(base_bytes('Source/battle/moves.lua').decode())
        after = c.read_rows(text)
        ported = c.read_rows(subprocess.check_output(
            ['git', 'show', 'd9c39c11:Source/battle/moves.lua'], cwd=ROOT, text=True))
        self.assertEqual({key for key in before if before[key] != ported[key]}, {'substitute'})
        self.assertEqual({key for key in before if before[key] != after[key]}, {
            'substitute', 'thrash', 'outrage', 'hyperBeam', 'gigaImpact',
            'flameWheel', 'flareBlitz', 'lowKick', 'sunnyDay', 'hail'})
        self.assertEqual(c.split_payload(before['substitute'])[0], c.split_payload(after['substitute'])[0])


if __name__ == '__main__':
    unittest.main()
