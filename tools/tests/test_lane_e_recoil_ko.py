#!/usr/bin/env python3
"""A recoil KO that moves first must not run the queued foe move.

20261119T162301Z-route22-rival.mp4 at 0:15-0:19: Venusaur moves first,
uses Double-Edge, and faints from recoil. Charizard's queued Wing
Attack still runs, including the hit animation on the empty player
platform.

resolveRound treats handleFaint's "replacement" as permission to run
the next queued action. The foe is alive, so the attacker check does
not skip them. performMove says the move and presents it before
moveHasTarget notices the fainted target.

Gen V does not run that action. Residuals still resolve, then the
forced switch. The patch is not applied.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATTLE = ROOT / 'Source/battle/battle.lua'
PATCH = ROOT / 'tools/notes/lane-e-recoil-ko.patch'
HOST = ROOT / 'tools/tests/recoil_ko_host.lua'


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
    raise AssertionError('Lua 5.4 is required to call the battle host')


def run_host(battle_path=None):
    command = [lua_binary(), str(HOST), str(ROOT)]
    if battle_path is not None:
        command.append(str(battle_path))
    return subprocess.run(command, check=False, capture_output=True, text=True)


def assert_skipped(test, completed):
    test.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
    text = completed.stdout
    test.assertIn('VENUSAUR fainted!', text)
    test.assertIn('damaged by recoil!', text)
    test.assertNotIn('CHARIZARD used WING ATTACK!', text)
    test.assertIn('phase forcedSwitch', text)
    test.assertIn('userhp 0', text)
    wing_before = next(line for line in text.splitlines() if line.startswith('wingpp-before '))
    wing_after = next(line for line in text.splitlines() if line.startswith('wingpp '))
    test.assertEqual(wing_before.split()[1], wing_after.split()[1])


class RecoilKoTests(unittest.TestCase):
    def test_live_source_still_runs_the_queued_move(self):
        completed = run_host()
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('CHARIZARD used WING ATTACK!', completed.stdout)
        self.assertIn('phase forcedSwitch', completed.stdout)

    @unittest.expectedFailure
    def test_unpatched_recoil_ko_skips_the_queued_move(self):
        assert_skipped(self, run_host())

    def test_patch_skips_the_queued_move_and_keeps_its_pp(self):
        check = subprocess.run(
            ['git', 'apply', '--check', str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        patched = Path('/tmp/lane-e-recoil-battle.lua')
        applied = subprocess.run(
            ['patch', '-o', str(patched), str(BATTLE), str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        assert_skipped(self, run_host(patched))
        self.assertIn('CHARIZARD used WING ATTACK!', run_host().stdout)
        self.assertNotIn('outcome == "replacement" then return self:finishRound()', BATTLE.read_text())


if __name__ == '__main__':
    unittest.main()
