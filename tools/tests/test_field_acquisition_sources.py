"""Primary pins and generation boundaries only; gameplay runs in the SDK."""
import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
REFERENCES = ROOT / 'tools/references'


class FieldAcquisitionSources(unittest.TestCase):
    def setUp(self):
        self.pin = json.loads((REFERENCES / 'field-acquisition-sources.json').read_text())

    def test_exact_primary_revisions_and_actual_bytes(self):
        self.assertEqual(self.pin['pokebw2_revision'], 'b279bbefa99bb2f6fbabcc95e4b6d3e939290353')
        self.assertEqual(self.pin['pkhex_revision'], 'd2fea14b563f4b16fef7788b9699b20d5b3f410f')
        for name, row in self.pin['files'].items():
            with self.subTest(name=name):
                data = (REFERENCES / row['path']).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), row['sha256'])
                revision = self.pin['pkhex_revision' if name in ('personal_b2w2', 'PersonalInfo5B2W2.cs') else 'pokebw2_revision']
                self.assertIn('/' + revision + '/', row['url'])

    def test_native_manager_uses_physical_non_egg_lead_without_hp_gate(self):
        text = (REFERENCES / 'traits/src_ov036_enc_pokeset.c').read_text()
        body = text.split('void CreateEncountManager(', 1)[1].split('u32 FieldEncount_CalcEncountRate(', 1)[0]
        self.assertIn('lead = PokeParty_GetPkm(party, 0);', body)
        self.assertIn('if (manager->leadIsEgg == FALSE)', body)
        self.assertNotIn('PKM_PARAM_HP', body)
        for field in ('leadAbility', 'leadSex', 'leadNature'):
            self.assertIn('manager->' + field + ' =', body)

    def test_native_conditional_gate_order_and_nature_overwrite(self):
        text = (REFERENCES / 'traits/src_ov036_enc_pokeset.c').read_text()
        body = text.split('static void SetupEncountFlagsByPartyPokeAbil(EncountManager *manager, u16 weather) {', 1)[1].split('static BOOL FieldEncount_CheckLevelRepelled', 1)[0]
        cute = body.index('manager->leadAbility == ABILITY_CUTE_CHARM && GFL_RandomLC(100) < 67')
        fallback = body.index('if (GFL_RandomLC(100) < 50)')
        synchronize = body.index('case ABILITY_SYNCHRONIZE:')
        self.assertLess(cute, fallback)
        self.assertLess(fallback, synchronize)
        self.assertIn('manager->cuteCharm = TRUE;\n        return;', body)
        creation = text.split('void FieldEncount_CreateWildPkm(', 1)[1].split('void FieldEncount_GenRoamingPkm(', 1)[0]
        self.assertLess(creation.index('PokeParty_CreatePkm('), creation.index('if (manager->synchronize)'))
        self.assertIn('PokeParty_SetParam(pkm, PKM_PARAM_NATURE, manager->leadNature);', creation)

    def test_native_pid_bounds_and_target_exclusions(self):
        text = (REFERENCES / 'traits/bw_src_system_poke_tool.c').read_text()
        pid = text.split('u32 PML_GenPID(', 1)[1].split('u8 getHiddenPowerType(', 1)[0]
        self.assertIn('u32 high = GFL_RandomLC(0) & ~0xff;', pid)
        self.assertIn('value += GFL_RandomLC(254 - value);', pid)
        self.assertIn('value = GFL_RandomLC(value) + 1;', pid)
        gender = text.split('static u32 getGenderValue(u16 species, u16 form, u8 sex) {', 1)[1].split('// A PID', 1)[0]
        self.assertIn('value = ratio - 1;', gender)
        enc = (REFERENCES / 'traits/src_ov036_enc_pokeset.c').read_text()
        pid = enc.split('static u32 FieldEncount_GenPID(const EncountManager *manager, void *personal, WildPkmParam *param) {', 1)[1].split('static int GetEncountSlotByProbability', 1)[0]
        self.assertIn('if (isGenderlessOrSetGender(sexRatio) != TRUE)', pid)
        self.assertIn('if (manager->leadSex == 0)', pid)
        self.assertIn('else if (manager->leadSex == 1)', pid)

    def test_primary_personal_layout_and_reachable_ability_slots(self):
        data = (REFERENCES / 'traits/personal_b2w2').read_bytes()
        layout = (REFERENCES / 'traits/PersonalInfo5B2W2.cs').read_text()
        self.assertIn('SIZE = 0x4C', layout)
        self.assertIn('Gender { get => Data[0x12]', layout)
        # Native IDs from the personal rows, not from runtime dispatch.
        for dex, ratio, slots in ((63, 63, (28, 39)), (35, 191, (56, 98)),
                                  (50, 127, (8, 71)), (120, 255, (35, 30)),
                                  (66, 63, (62, 99)), (88, 127, (1, 60))):
            with self.subTest(dex=dex):
                row = data[dex * 76:(dex + 1) * 76]
                self.assertEqual(row[0x12], ratio)
                self.assertEqual(tuple(row[0x18:0x1A]), slots)

    def test_native_rate_dispatch_is_deterministic_and_clamps_after_scaling(self):
        text = (REFERENCES / 'traits/src_ov036_enc_pokeset.c').read_text()
        body = text.split('u32 FieldEncount_CalcEncountRate(', 1)[1].split('static int FieldEncount_GenWildsCore', 1)[0]
        self.assertIn('rate *= 2;', body)
        self.assertIn('rate /= 2;', body)
        self.assertLess(body.index('manager->rateUp'), body.rindex('if (rate > 100)'))
        self.assertNotIn('Random', body)
        flags = text.split('static void SetupEncountFlagsByPartyPokeAbil(EncountManager *manager, u16 weather) {', 1)[1].split('case ABILITY_SAND_VEIL:', 1)[0]
        for name in ('ILLUMINATE', 'ARENA_TRAP', 'NO_GUARD', 'STENCH', 'WHITE_SMOKE', 'QUICK_FEET'):
            self.assertIn('case ABILITY_' + name + ':', flags)


if __name__ == '__main__':
    unittest.main()
