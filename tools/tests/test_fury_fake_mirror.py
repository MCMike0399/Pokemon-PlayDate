"""Gen V Fury Cutter, Fake Out, and Mirror Move host checks. The Simulator is not required."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / 'tools/tests/fury_fake_mirror_host.lua'


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
    raise AssertionError('Lua 5.4 is required to call the move host')


class FuryFakeMirrorHostTests(unittest.TestCase):
    def test_fury_cutter_fake_out_and_mirror_move(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('fury-fake-mirror-host ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
