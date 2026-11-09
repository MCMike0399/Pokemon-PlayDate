"""Hyper Beam, Giga Impact, Thrash, Outrage, and freeze-thaw host checks."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / 'tools/tests/recharge_rampage_freeze_host.lua'


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


class RechargeRampageFreezeTests(unittest.TestCase):
    def test_recharge_rampage_and_freeze_thaw(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('recharge-rampage-freeze-host ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
