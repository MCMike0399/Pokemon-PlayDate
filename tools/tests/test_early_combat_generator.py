"""Bounded Gen V mapping checks, no network or alternative SDK."""
import importlib.util
from pathlib import Path
import re
import unittest
import tempfile
import json
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('gen',ROOT/'tools/generate_gen5_data.py');gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)
class EarlyCombatGeneratorTests(unittest.TestCase):
    def test_gen5_overrides_ignore_later_meta(self):
        later={'meta_ailment_id':'0','flinch_chance':'0','stat_chance':'100','healing':'0'}
        changes=[{'stat_id':'6','change':'2'}]
        self.assertEqual(gen.build_effects('stringShot',later,changes,11,True),['ModifyStat(DEFENDER, "spe", -1)'])
        self.assertEqual(gen.build_effects('rapidSpin',later,changes,10,False),['RapidSpinEffect()'])
        self.assertEqual(gen.build_effects('curse',None,[],1,True),['CurseEffect()'])
        self.assertEqual(gen.build_effects('toxic',None,[],10,True),['ApplyStatus(DEFENDER, "badPoison")'])
    def test_all_concrete_dependencies_generate_real_effects(self):
        effects={'mudSport':'MudSportEffect()','rage':'RageEffect()','leechSeed':'LeechSeedEffect()','bind':'PartialTrapEffect()','wrap':'PartialTrapEffect()','fireSpin':'PartialTrapEffect()','spikes':'EntryHazardEffect("spikes")','toxicSpikes':'EntryHazardEffect("toxicSpikes")','stealthRock':'EntryHazardEffect("stealthRock")'}
        for key,effect in effects.items():self.assertEqual(gen.build_effects(key,None,[],10,True),[effect])
        self.assertEqual(gen.build_effects('defenseCurl',None,[],7,True),['ModifyStat(ATTACKER, "def", 1)','DefenseCurlEffect()'])
    def test_generated_projection_preserves_every_existing_scalar_and_unowned_effect(self):
        import json
        spec=importlib.util.spec_from_file_location('verify',ROOT/'tools/verify_early_combat.py');verify=importlib.util.module_from_spec(spec);spec.loader.exec_module(verify)
        manifest=json.loads((ROOT/'tools/references/early-combat.json').read_text())
        self.assertEqual(verify.check_moves(ROOT/'Source/battle/moves.lua',manifest),424)
        rows=dict(re.findall(r'^    (\w+) = (Move[^\n]+)$',(ROOT/'Source/battle/moves.lua').read_text(),re.M))
        for field in ['type = "poison"','category = "status"','power = 0','accuracy = 90','pp = 10','targetId = 10','ApplyStatus(DEFENDER, "badPoison")']:self.assertIn(field,rows['toxic'])
    def test_corrupt_source_pin_and_unowned_move_edit_fail(self):
        spec=importlib.util.spec_from_file_location('verify',ROOT/'tools/verify_early_combat.py');verify=importlib.util.module_from_spec(spec);spec.loader.exec_module(verify)
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);source=root/'source';source.write_bytes(b'original')
            manifest={'primary':{'files':{'source':{'url':'unused','sha256':verify.digest(b'original')}}}}
            verify.check_pins(root,manifest);source.write_bytes(b'corrupt')
            with self.assertRaisesRegex(ValueError,'checksum'):verify.check_pins(root,manifest)
            source.unlink()
            with self.assertRaises(OSError):verify.check_pins(root,manifest)
            manifest=json.loads((ROOT/'tools/references/early-combat.json').read_text())
            moves=(ROOT/'Source/battle/moves.lua').read_text()
            bad=root/'moves.lua';bad.write_text(moves.replace('name = "TACKLE"','name = "BROKEN"',1))
            with self.assertRaisesRegex(ValueError,'scalar'):verify.check_moves(bad,manifest)
            bad.write_text(moves.replace('ModifyStat(DEFENDER, "atk", -1)','ModifyStat(DEFENDER, "atk", -2)',1))
            with self.assertRaisesRegex(ValueError,'unowned'):verify.check_moves(bad,manifest)
if __name__=='__main__':unittest.main()
