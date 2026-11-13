#!/usr/bin/env python3
"""Walking onto the Cycling Road without a Bicycle crashes the map change.

Session leg 58 resumed in Fuchsia and stepped through Route 18 Gate.
The live error was:

    runtime error: game/overworldState.lua:515: bicycle-required

FieldCycling.enter refuses ROUTE_18 (33, 8) and (33, 9) when the bag has
no Bicycle. DoorWarpSubstate still calls switchZone, and the overworld
reload asserts that refusal. Pret stops the player in the gate. This test
fails until tools/notes/lane-e-bicycle-road.patch is applied. The patch
does not give the player a Bicycle and does not change MallocPoolSize.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / "Source/game/overworldState.lua"
PATCH = ROOT / "tools/notes/lane-e-bicycle-road.patch"


def door_load(source):
    body = source.split("local function load()", 1)[1]
    return body.split("if GameBootstrap then", 1)[0]


class BicycleRoadTest(unittest.TestCase):
    def test_patch_refuses_the_road_before_the_zone_change(self):
        patch = PATCH.read_text(encoding="utf-8")
        added = "\n".join(
            line[1:] for line in patch.splitlines() if line.startswith("+") and not line.startswith("+++"))
        self.assertIn('failure == "bicycle-required"', added)
        self.assertLess(added.index('failure == "bicycle-required"'), added.index("switchZone") if "switchZone" in added else len(added))
        self.assertIn('self.machine:change("explore")', added)
        self.assertIn("player.lastTraversalBlock = {kind = \"bicycle-required\"}", added)
        self.assertNotIn("MallocPoolSize", patch)
        self.assertNotIn("quantity(\"bicycle\")", patch.replace('quantity("bicycle") == 1', ""))

    def test_cycling_road_door_does_not_assert(self):
        load = door_load(STATE.read_text(encoding="utf-8"))
        refusal = load.split("switchZone(door.to)", 1)[0]
        self.assertIn(
            'failure == "bicycle-required"',
            refusal,
            "the Cycling Road door asserts bicycle-required. "
            "Apply tools/notes/lane-e-bicycle-road.patch",
        )
        self.assertIn('self.machine:change("explore")', refusal)
        self.assertIn('player.lastTraversalBlock = {kind = "bicycle-required"}', refusal)


if __name__ == "__main__":
    unittest.main()
