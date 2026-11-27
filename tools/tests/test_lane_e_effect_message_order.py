#!/usr/bin/env python3
"""Crit and effectiveness lines come after the damage and before a secondary.

docs/validation/fidelity-ledger.md Combat row uses Gen V/B2W2 rules.
Bulbapedia's Critical hit page prints "A critical hit!" after the damage is
dealt. Showdown sim/battle-actions.ts at 9b136a8c8cdb860a8ab96fa063f906604e352547
runs secondaries() after spreadDamage, so a burn, freeze, paralysis, or stat
drop is not printed before the effectiveness line. The cartridge order used
here is damage, then "A critical hit!", then the effectiveness line, then the
secondary line. Showdown's protocol adds the effectiveness line before the
crit line and before its -damage record; that protocol order is not the text
order this port prints.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/effect_message_order_host.lua"


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
        if "case " not in block:
            continue
        head, _, body = block.partition("---\n")
        label = None
        dealt = None
        for line in head.splitlines():
            if line.startswith("case "):
                label = line.split(" ", 1)[1]
            elif line.startswith("dealt "):
                dealt = int(line.split(" ", 1)[1])
        if label:
            found[label] = (dealt, body)
    return found


def before(body, earlier, later):
    left = body.find(earlier)
    right = body.find(later)
    if left < 0 or right < 0:
        raise AssertionError(f"missing {earlier!r} or {later!r} in:\n{body}")
    if left > right:
        raise AssertionError(f"{earlier!r} follows {later!r} in:\n{body}")


class EffectMessageOrderTests(unittest.TestCase):
    def test_secondary_follows_crit_and_effectiveness(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        found = cases(completed.stdout)
        self.assertEqual(set(found), {"burn", "stat", "crit"})

        dealt, burn = found["burn"]
        self.assertGreater(dealt, 0)
        self.assertNotIn("A critical hit!", burn)
        before(burn, "It's not very effective...", "SLOWBRO was burned!")

        dealt, stat = found["stat"]
        self.assertGreater(dealt, 0)
        self.assertNotIn("A critical hit!", stat)
        before(stat, "It's not very effective...", "BLASTOISE's SPEED fell!")

        dealt, crit = found["crit"]
        self.assertGreater(dealt, 0)
        before(crit, "A critical hit!", "It's not very effective...")
        before(crit, "It's not very effective...", "SLOWBRO was burned!")


if __name__ == "__main__":
    unittest.main()
