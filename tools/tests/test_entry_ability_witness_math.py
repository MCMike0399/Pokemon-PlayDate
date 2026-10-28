"""Independent arithmetic for the SDK Shell Armor witness; no Lua execution.

Showdown 9b136 is the mechanics oracle. Park-Miller supplies this project's
seeded samples, not Showdown's PRNG. Native runtime acceptance belongs to root.
"""
import hashlib
import json
from pathlib import Path
import unittest

from tools.generate_ability_move_metadata import entries

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path.home() / 'Developer/Pokemon-PlayDate-env/preparation/common-abilities-oracle'
PINS = json.loads((ROOT / 'tools/references/early-abilities-sources.json').read_text())['files']


def primary(name, path=None):
    raw = (path or CACHE / name).read_bytes()
    if hashlib.sha256(raw).hexdigest() != PINS[name]['sha256']:
        raise ValueError('source checksum: ' + name)
    return raw


class EntryAbilityWitnessMath(unittest.TestCase):
    def test_primary_critical_guard_and_gen5_formula(self):
        abilities = entries(primary('ps_data_abilities.ts').decode())
        self.assertIn('onCriticalHit: false', abilities['shellarmor'])
        for gen in (8, 7, 6, 5):
            overrides = entries(primary(f'ps_data_mods_gen{gen}_abilities.ts').decode())
            if 'shellarmor' in overrides:
                self.assertIn('inherit: true', overrides['shellarmor'])
                self.assertNotIn('onCriticalHit', overrides['shellarmor'])
        actions = primary('ps_sim_battle-actions.ts').decode()
        trial = actions.index('moveHit.crit = this.battle.randomChance(')
        guard = actions.index("this.battle.runEvent('CriticalHit'", trial)
        bypass = actions.index('ignoreNegativeOffensive = true', guard)
        self.assertLess(trial, guard)
        self.assertLess(guard, bypass)
        self.assertIn('this.battle.gen >= 6 ? 1.5 : 2', actions)
        self.assertIn('baseDamage = this.battle.randomizer(baseDamage)', actions)
        moves = entries(primary('ps_data_mods_gen6_moves.ts').decode())
        self.assertIn('basePower: 50', moves['tackle'])
        self.assertNotIn('tackle', entries(primary('ps_data_mods_gen5_moves.ts').decode()))

    def test_seed1_endpoints_and_stage_bypass_discriminators(self):
        personal = primary('personal_b2w2', ROOT / 'tools/references/traits/personal_b2w2')
        # B2W2 personal records are 76 bytes; first fields HP, Atk, Def.
        squirtle, shellder = personal[7*76:7*76+3], personal[90*76:90*76+3]
        attack = 2*squirtle[1]*25//100 + 5
        defense = 2*shellder[2]*25//100 + 5
        hp = 2*shellder[0]*25//100 + 25 + 10
        self.assertEqual((attack, defense, hp), (29, 55, 50))
        state, samples = 1, []
        for low, high in ((1, 100), (1, 16), (85, 100)):
            state = state * 16807 % 2147483647
            span = high-low+1
            self.assertLess(state-1, (2147483646//span)*span)
            samples.append(low + (state-1) % span)
        self.assertEqual((samples, state), ([7, 1, 93], 1622650073))

        def damage(atk, defense, critical):
            base = ((2*25//5+2)*50*atk//defense)//50+2
            return base*(2 if critical else 1)*samples[2]//100

        # Neutral Normal -> Water: no STAB, resistance, burn or final modifier.
        self.assertEqual(hp-damage(attack//2, defense*2, False), 48)
        self.assertEqual(hp-damage(attack, defense, True), 36)
        # Wrongly bypassing stages under armor, or retaining stages on a real
        # crit, yields different endpoints. Both SDK assertions are necessary.
        self.assertEqual(hp-damage(attack, defense, False), 43)
        self.assertEqual(hp-damage(attack//2, defense*2, True), 45)


if __name__ == '__main__':
    unittest.main()
