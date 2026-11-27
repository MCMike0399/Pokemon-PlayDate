#!/usr/bin/env python3
"""Explore update crashes when switchZone has cleared the player.

A fresh Continue, a loss to Mewtwo, and `zone kanto_cerulean_cave_1f 20 10
down` published game/overworldState.lua:88: attempt to index a nil value
(local 'player'). Cell (20, 10) is collision 1. switchZone nils
game.player. OverworldState:enter asserted fieldWorld.enter before
Player() ran, so the rebuild never happened. The harness beforeFrame
swallowed that assert and the next update indexed pendingBoulder.

The handoff is tools/notes/lane-e-nil-player-reentry.patch. It is not
applied here. This test crashes on the current tree and returns on the
patched file. MallocPoolSize stays 16645684. No skip.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PROBE = r"""
function Class(name)
    local class = {}
    _G[name] = class
    function class:extends()
        return class
    end
    return class
end
State = {}
playdate = { graphics = {} }
function import() end
dofile(__SOURCE__)
local self = { owner = { game = { player = nil }, fieldArrival = false } }
local ok, err = pcall(function()
    ExploreSubstate.update(self)
    ExploreSubstate.exit(self)
end)
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    os.exit(1)
end
print("nil-player-ok")
"""


def function_body(text, name):
    start = text.split("function " + name, 1)[1]
    return start.split("\nfunction ", 1)[0]


class NilPlayerReentryTests(unittest.TestCase):
    def test_explore_update_survives_a_nil_player(self):
        script = ROOT / "Source/game/overworldState.lua"
        code = PROBE.replace("__SOURCE__", json.dumps(str(script)))
        result = subprocess.run(
            ["lua5.4", "-e", code],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("nil-player-ok", result.stdout)

    def test_field_reload_assert_follows_the_player(self):
        text = (ROOT / "Source/game/overworldState.lua").read_text(encoding="utf-8")
        enter = function_body(text, "OverworldState:enter(opts)")
        player_at = enter.find("game.player = Player")
        assert_at = enter.find("assert(reloadAccepted, reloadProblem)")
        self.assertIsNotNone(player_at)
        self.assertIsNotNone(assert_at)
        self.assertLess(player_at, assert_at)
        self.assertNotIn("assert(accepted, problem)", enter)


if __name__ == "__main__":
    unittest.main()
