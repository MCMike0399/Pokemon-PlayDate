#!/usr/bin/env python3
"""On-damage ability lines follow the crit and effectiveness lines.

docs/validation/fidelity-ledger.md Combat row uses Gen V/B2W2 rules.
A Sturdy endure, Anger Point, Static, and Poison Point are ability
messages for the hit that just landed. Gen V prints the damage, then
"A critical hit!" and the effectiveness line, then the ability line.
Move secondaries already wait in tools/notes/lane-e-effect-message-order.patch.
This follow-up queues the ability lines on that same flush. It does not
replace that patch. Apply both, in that order, on 247d60a9.
"""

import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/ability_message_order_host.lua"


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
        left = None
        for line in head.splitlines():
            if line.startswith("case "):
                label = line.split(" ", 1)[1]
            elif line.startswith("dealt "):
                dealt = int(line.split(" ", 1)[1])
            elif line.startswith("left "):
                left = int(line.split(" ", 1)[1])
        if label:
            found[label] = (dealt, left, body)
    return found


class AbilityMessageOrderTests(unittest.TestCase):
    def test_ability_follows_crit_and_effectiveness(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        found = cases(completed.stdout)
        self.assertEqual(set(found), {"sturdy", "anger", "static"})

        dealt, left, sturdy = found["sturdy"]
        self.assertGreater(dealt, 0)
        self.assertEqual(left, 1)
        self.assertNotIn("A critical hit!", sturdy)
        self.order(sturdy, "It's super effective!", "ONIX held on with Sturdy!")

        dealt, left, anger = found["anger"]
        self.assertGreater(dealt, 0)
        self.order(anger, "A critical hit!", "It's not very effective...")
        self.order(anger, "It's not very effective...", "SLOWBRO's Anger Point maximized its ATTACK!")

        dealt, left, static = found["static"]
        self.assertGreater(dealt, 0)
        self.order(static, "It's super effective!", "GYARADOS's Static!")

    def order(self, body, earlier, later):
        left = body.find(earlier)
        right = body.find(later)
        self.assertNotEqual(left, -1, f"missing {earlier!r} in:\n{body}")
        self.assertNotEqual(right, -1, f"missing {later!r} in:\n{body}")
        self.assertLess(left, right, f"{earlier!r} follows {later!r} in:\n{body}")


if __name__ == "__main__":
    unittest.main()
