#!/usr/bin/env python3
"""Counter returns twice the last physical hit, including a crit.

docs/validation/fidelity-ledger.md gives pokered moves Gen V/B2W2 rules and
the physical/special split (Combat row). The same ledger says "Gen V rules
apply to moves pokered has" (Wide Guard row). TM/HM policy executes those
moves under Gen V rules. Gen V Counter is twice the HP actually removed by
the last physical-category hit this turn. A crit is already inside that HP
loss. A special move and a move that deals no damage fail.

pokered HandleCounterMove (engine/battle/core.asm) only accepts Normal and
Fighting. That type filter is the Gen I rule the ledger replaced. Wing Attack
is physical Flying, so Gen V Counter succeeds. Water Gun is special and not
Normal or Fighting, so Counter fails. Growl deals no damage, so Counter fails.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/counter_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call the battle host")


def cases(text):
    found = {}
    for block in text.split("===="):
        rows = {}
        for line in block.splitlines():
            if " " not in line or line.startswith("CHAR") or line.startswith("HIT"):
                continue
            key, value = line.split(" ", 1)
            if key in {"case", "move", "crit-line", "counter-line", "failed-line",
                       "dealt", "counter-damage", "phase"}:
                rows[key] = value
        if "case" in rows:
            found[rows["case"]] = rows
    return found


class CounterTests(unittest.TestCase):
    def test_ai_counter_doubles_physical_damage_and_fails_otherwise(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        found = cases(completed.stdout)
        self.assertEqual(set(found), {
            "strength-plain", "strength-crit", "karate-plain", "karate-crit",
            "wing-plain", "water-gun", "growl"})

        def doubled(name, crit):
            row = found[name]
            dealt = int(row["dealt"])
            returned = int(row["counter-damage"])
            self.assertEqual(row["counter-line"], "true", name)
            self.assertEqual(row["failed-line"], "false", name)
            self.assertGreater(dealt, 0, name)
            self.assertEqual(returned, dealt * 2, name)
            self.assertEqual(row["crit-line"], "true" if crit else "false", name)
            self.assertEqual(row["phase"], "command", name)

        doubled("strength-plain", False)
        doubled("strength-crit", True)
        doubled("karate-plain", False)
        doubled("karate-crit", True)
        doubled("wing-plain", False)
        self.assertGreater(int(found["strength-crit"]["counter-damage"]),
                           int(found["strength-plain"]["counter-damage"]))
        self.assertGreater(int(found["karate-crit"]["counter-damage"]),
                           int(found["karate-plain"]["counter-damage"]))

        for name in ("water-gun", "growl"):
            row = found[name]
            self.assertEqual(row["counter-line"], "true", name)
            self.assertEqual(row["failed-line"], "true", name)
            self.assertEqual(int(row["counter-damage"]), 0, name)
            self.assertEqual(row["phase"], "command", name)
        self.assertGreater(int(found["water-gun"]["dealt"]), 0)
        self.assertEqual(int(found["growl"]["dealt"]), 0)


if __name__ == "__main__":
    unittest.main()
