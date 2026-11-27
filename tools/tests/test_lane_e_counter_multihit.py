#!/usr/bin/env python3
"""Counter doubles the last strike of a multi-hit physical move.

Pokémon Showdown's Counter condition (data/moves.ts onDamagingHit) stores
`this.effectState.damage = 2 * damage`. That assignment replaces the previous
strike. data/mods/gen5/moves.ts does not override Counter, so Generation V
uses that condition.

sim/battle-actions.ts counts each hit on its own for Counter and keeps
move.totalDamage for recoil only. DamagingHit runs from spreadMoveHit, and
the multi-hit loop calls that once per strike, so the stored value is the
last strike.

Bulbapedia's Generation I effect says Counter counters only the last hit of
a multistrike move. The Generation V section does not change that to the
sum of the strikes.

Double Kick, Fury Attack, and Comet Punch are physical multi-hit moves in
pokered. The countered damage is twice the last strike's HP loss, which is
less than twice the total.
"""

import subprocess
import unittest
from pathlib import Path

from gap_move_cases import ROOT, flag, lua_binary, number

HOST = Path(__file__).resolve().parent / "counter_last_host.lua"


def rows():
    completed = subprocess.run(
        [lua_binary(), str(HOST), str(ROOT)],
        check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr or completed.stdout)
    found = {}
    for line in completed.stdout.splitlines():
        if " " not in line:
            continue
        key, value = line.split(" ", 1)
        found[key] = value
    return found


class CounterLastStrikeTests(unittest.TestCase):
    def test_counter_doubles_only_the_last_strike(self):
        found = rows()
        for move in ("doubleKick", "furyAttack", "cometPunch"):
            hits = number(found, move + "-hits")
            last = number(found, move + "-last")
            total = number(found, move + "-sum")
            countered = number(found, move + "-countered")
            self.assertGreaterEqual(hits, 2, move)
            self.assertGreater(last, 0, move)
            self.assertGreater(total, last, move)
            self.assertFalse(flag(found, move + "-failed"), move)
            self.assertEqual(countered, last * 2, move)
            self.assertNotEqual(countered, total * 2, move)


if __name__ == "__main__":
    unittest.main()
