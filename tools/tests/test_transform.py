"""Gen V Transform host checks. The Simulator is not required."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / 'tools/tests/transform_host.lua'


def lua_binary():
    override = os.environ.get('LUA')
    if override:
        return override
    for name in ('lua', 'lua5.4'):
        found = shutil.which(name)
        if found:
            return found
    built = Path('/tmp/lua-5.4.7/src/lua')
    if built.is_file() and os.access(built, os.X_OK):
        return str(built)
    raise AssertionError('Lua 5.4 is required to call Transform')


class TransformHostTests(unittest.TestCase):
    def test_transform_copies_a_battle_forme_and_keeps_party_identity(self):
        # Disagreements with the pinned gen5 wording live in transform_host.lua.
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('transform-host ok', completed.stdout)

    def test_battle_scene_reads_the_transformed_forme(self):
        text = (ROOT / 'Source/battle/battleScene.lua').read_text()
        self.assertIn('conditions:speciesOf', text)
        self.assertIn('conditions:movesOf', text)
        self.assertIn('conditions:ppOf', text)
        self.assertIn('conditions:maxPPOf', text)
        learnset = (ROOT / 'Source/data/pokemon.lua').read_text()
        self.assertIn('learnset = "transform|1|-|144"', learnset)


if __name__ == '__main__':
    unittest.main()
