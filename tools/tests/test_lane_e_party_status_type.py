#!/usr/bin/env python3
"""The party stats page is missing TYPE1/.

pokered has no engine/menus/status_screen.asm. engine/pokemon/status_screen.asm
StatusScreen (af519899) places TypesIDNoOTText at hlcoord 10, 9. That string
is TYPE1/ then TYPE2/ then ID No. then OT/. PrintMonType at hlcoord 11, 10
prints the first name and skips the second when the type bytes match.
data/names.asm prints PSYCHIC for PSYCHIC_TYPE. Mewtwo stores type psychic
and type2 nil.

The handoff is tools/notes/lane-e-party-status-type.patch. It is not applied
here. This test fails on the current tree. MallocPoolSize stays 16645684.
No skip.
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
dofile(__SOURCE__)
local function check(mon, first, second)
    local lines = PartyState.typeLines(mon)
    assert(lines[1] == first, lines[1])
    assert(lines[2] == second, lines[2])
end
check({ type = "psychic", type2 = nil }, "TYPE1/ PSYCHIC", "TYPE2/")
check({ type = "grass", type2 = "poison" }, "TYPE1/ GRASS", "TYPE2/ POISON")
check({ type = "water", type2 = "water" }, "TYPE1/ WATER", "TYPE2/")
print("type-lines-ok")
"""


def function_body(text, name):
    start = text.split("function " + name, 1)[1]
    return start.split("\nfunction ", 1)[0]


class PartyStatusTypeTests(unittest.TestCase):
    def test_stats_page_draws_type1(self):
        script = ROOT / "Source/game/partyState.lua"
        code = PROBE.replace("__SOURCE__", json.dumps(str(script)))
        result = subprocess.run(
            ["lua5.4", "-e", code],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("type-lines-ok", result.stdout)
        stats = function_body(script.read_text(encoding="utf-8"), "PartyState:_paintScreen(party)")
        stats = stats.split('if self.phase == "stats"', 1)[1].split("elseif", 1)[0]
        self.assertIn("PartyState.typeLines(mon)", stats)
        self.assertIn("TYPE1/", script.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
