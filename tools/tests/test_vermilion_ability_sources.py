"""Pinned primary-data checks, with mutations; no Lua execution/emulation."""
import json
from pathlib import Path
import re
import tempfile
import unittest

from tools.check_contact_ability_sources import DEFAULT_CACHE, MANIFEST, load
from tools.generate_ability_move_metadata import project
from tools.check_vermilion_ability_sources import IDS, ROOT, REVISION, policies, verify


class VermilionAbilitySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = load()

    def test_primary_mod_chain_and_ordinary_specimen_slots(self):
        report = verify()
        self.assertEqual(report['primary_revision'], REVISION)
        self.assertEqual(report['abilities'], IDS)
        self.assertEqual(report['personal_species'], 151)
        self.assertFalse(report['sdk_executed'])
        self.assertEqual(report['native_discrepancies'], [])
        text = (ROOT / 'Source/data/specimenData.lua').read_text()
        slots = {int(n): (int(a), int(b)) for n, a, b in re.findall(
            r'\[(\d+)\] = \{first=(\d+),second=(\d+)', text)}
        for dex, expected in ((52, (53, 101)), (58, (22, 18)), (72, (29, 64)),
                              (60, (11, 6)), (129, (33, 33)), (109, (26, 26))):
            with self.subTest(dex=dex):
                self.assertEqual(slots[dex], expected)

    def test_callback_policy_mutations_are_rejected(self):
        changes = (
            ('ps_data_abilities.ts', 'basePowerAfterMultiplier <= 60', 'basePowerAfterMultiplier <= 59'),
            ('ps_data_mods_gen7_abilities.ts', 'onBasePowerPriority: 19', 'onBasePowerPriority: 18'),
            ('ps_data_abilities.ts', 'onModifySpAPriority: 5', 'onModifySpAPriority: 6'),
            ('ps_data_abilities.ts', '!(effect as ActiveMove).secondaries', 'true'),
            ('ps_data_mods_gen6_abilities.ts', "['drain', 'leechseed']", "['drain']"),
            ('ps_data_abilities.ts', 'target.baseMaxhp / 4', 'target.baseMaxhp / 8'),
        )
        for name, old, new in changes:
            with self.subTest(policy=old):
                self.assertIn(old, self.sources[name])
                changed = dict(self.sources)
                changed[name] = changed[name].replace(old, new)
                with self.assertRaises(AssertionError):
                    policies(changed)

    def test_pinned_generation_of_actual_trigger_move_metadata(self):
        keys = ('scratch', 'bite', 'furySwipes', 'ember', 'flameWheel', 'waterGun',
                'absorb', 'leechSeed', 'acid', 'rainDance', 'mudSlap', 'bulldoze',
                'sandAttack', 'protect', 'worrySeed', 'toxicSpikes')
        texts = [self.sources['ps_data_moves.ts']]
        texts += [self.sources[f'ps_data_mods_gen{g}_moves.ts'] for g in (8, 7, 6, 5)]
        generated = project(texts, {key.lower() for key in keys})
        tracked = json.loads((ROOT / 'tools/references/ability-move-metadata.json').read_text())
        self.assertEqual(tracked['revision'], REVISION)
        for key in keys:
            with self.subTest(move=key):
                self.assertEqual(tracked['moves'][key], generated[key.lower()])
        self.assertTrue(generated['furyswipes']['contact'])
        self.assertTrue(generated['mudslap']['secondary'])
        self.assertFalse(generated['sandattack']['typeImmunity'])

    def test_primary_byte_corruption_fails_without_fetch_or_repair(self):
        name = next(iter(json.loads(MANIFEST.read_text())['files']))
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / name
            path.write_bytes((DEFAULT_CACHE / name).read_bytes() + b'corruption')
            with self.assertRaisesRegex(ValueError, 'source checksum'):
                load(Path(temporary))
            self.assertTrue(path.read_bytes().endswith(b'corruption'))


if __name__ == '__main__':
    unittest.main()
