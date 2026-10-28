"""Primary-source validation only; real battle contracts belong to SDK/root."""
import json
from pathlib import Path
import tempfile
import unittest

from tools.check_contact_ability_sources import DEFAULT_CACHE, MANIFEST, ROOT, load, policies
from tools.generate_ability_move_metadata import entries


class ContactAbilitySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = load()

    def test_primary_hashes_match_existing_pins_and_exact_commit(self):
        new = json.loads(MANIFEST.read_text())
        old = json.loads((ROOT/'tools/references/early-abilities-sources.json').read_text())['files']
        for name, record in new['files'].items():
            self.assertIn('/'+new['revision']+'/',record['url'])
            if name in old:
                self.assertEqual(record,old[name])
        self.assertEqual(new['revision'],'9b136a8c8cdb860a8ab96fa063f906604e352547')

    def test_resolved_primary_callbacks_and_major_exceptions(self):
        report = policies(self.sources)
        self.assertEqual(report['abilities'],7)
        self.assertFalse(report['sdk_executed'])
        base=entries(self.sources['ps_data_abilities.ts'])
        for ability, number in [('effectspore',27),('cutecharm',56),('synchronize',28),
                                ('stench',1),('angerpoint',83),('naturalcure',30),('magicguard',98)]:
            self.assertIn('num: '+str(number)+',',base[ability])

    def test_checksum_failure_is_not_silently_accepted_or_refetched(self):
        first=next(iter(json.loads(MANIFEST.read_text())['files']))
        with tempfile.TemporaryDirectory() as temporary:
            cache=Path(temporary)
            (cache/first).write_bytes((DEFAULT_CACHE/first).read_bytes()+b'corrupt')
            with self.assertRaisesRegex(ValueError,'source checksum'):
                load(cache)

    def test_contact_probability_mutation_is_rejected_by_primary_policy_check(self):
        altered=dict(self.sources)
        altered['ps_data_abilities.ts']=altered['ps_data_abilities.ts'].replace('r < 11','r < 10')
        with self.assertRaises(AssertionError):
            policies(altered)

    def test_primary_orders_hit_before_secondaries_before_contact(self):
        actions=self.sources['ps_sim_battle-actions.ts']
        start=actions.index('// 3. onHit event happens here')
        hit=actions.index('this.runMoveEffects(',start)
        secondary=actions.index('this.secondaries(',hit)
        contact=actions.index("this.battle.runEvent('DamagingHit'",secondary)
        self.assertLess(hit,secondary)
        self.assertLess(secondary,contact)
        for generation in [8,7,6,5]:
            moves=entries(self.sources[f'ps_data_mods_gen{generation}_moves.ts'])
            for name in ['attract','safeguard']:
                if name in moves:
                    self.assertNotIn('onBeforeMove',moves[name])
                    self.assertNotIn('onSetStatus',moves[name])


if __name__ == '__main__':
    unittest.main()
