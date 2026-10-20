"""Run with GEN5_GENERATOR pointing at staged repair before root integration."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
PATH=Path(os.environ.get('GEN5_GENERATOR',Path(__file__).resolve().parents[1]/'generate_gen5_data.py'))
spec=importlib.util.spec_from_file_location('gen5_yield_generator',PATH);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
class YieldProjectionTests(unittest.TestCase):
    def test_full_species_generation_ignores_later_yields_and_preserves_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            src=Path(tmp)/'in.lua';out=Path(tmp)/'out.lua'
            src.write_text('''pokemonData = {
    pikachu = {
        name = "PIKACHU", dex = 25, type = "electric", type2 = nil,
        baseHP = 35, baseAtk = 55, baseDef = 40, baseSpA = 50, baseSpD = 50, baseSpe = 90, baseExp = 112,
        moves = { "growl" }, learnset = { { move="growl",level=1,id=45 } },
    },
}
function sentinelRuntime() return "preserve me" end
''')
            dex={'pikachu':{'types':['electric'],'baseStats':{'hp':35,'atk':55,'def':40,'spa':50,'spd':50,'spe':90}}}
            with patch.object(g,'POKEMON_INPUT',str(src)),patch.object(g,'POKEMON_LUA',str(out)),patch.object(g,'resolve_gen5_dex',return_value=dex):
                g.generate_species({'pokemon':[{'identifier':'pikachu','base_experience':'112','is_default':'1'}]}, {25:105})
            expected=src.read_text().replace('baseExp = 112','baseExp = 105')
            self.assertEqual(out.read_text(),expected)
    def test_missing_projection_fails_before_species_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            src=Path(tmp)/'in.lua';out=Path(tmp)/'out.lua'
            src.write_text('    pikachu = {\n        name = "PIKACHU", dex = 25, type = "electric", type2 = nil,\n        baseHP = 35, baseExp = 112,\n')
            dex={'pikachu':{'types':['electric'],'baseStats':{'hp':35,'atk':55,'def':40,'spa':50,'spd':50,'spe':90}}}
            with patch.object(g,'POKEMON_INPUT',str(src)),patch.object(g,'POKEMON_LUA',str(out)),patch.object(g,'resolve_gen5_dex',return_value=dex):
                with self.assertRaises(KeyError):g.generate_species({}, {})
            self.assertFalse(out.exists())
    def test_growth_loader_requires_authoritative_checked_projection(self):
        from tools import generate_growth_data as growth
        with patch.object(growth,'load_sources',return_value={'pinned':'bytes'}) as loader,patch.object(growth,'collect',return_value=({}, {25:(0,105),12:(0,173)})) as collect:
            self.assertEqual(g.load_gen5_yields(Path('/unused-cache'),False),{25:105,12:173})
            loader.assert_called_once_with(Path('/unused-cache'),False);collect.assert_called_once_with({'pinned':'bytes'})
if __name__=='__main__':unittest.main()
