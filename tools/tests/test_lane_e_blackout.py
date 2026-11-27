#!/usr/bin/env python3
"""A trainer wipe prints the pokered blackout page and leaves the map script.

pret/pokered af519899 text/text_2.asm _PlayerBlackedOutText2 is the loss
page for every fight except the lab rival. Route22Rival2AfterBattleScript
returns to the default script on LOST_BATTLE, so Blue's "Hahaha!" line must
not resume after the checkpoint warp.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_e_faint_host.lua"

# data/maps/special_warps.asm FlyWarpData. A Center heal stores this spot.
# Pallet is the new-game checkpoint. Viridian's nurse omits a checkpoint and
# EventState uses this same Viridian fly warp as its default.
FLY_WARPS = {
    "pokered:PALLET_TOWN": (5, 6),
    "pokered:VIRIDIAN_CITY": (23, 26),
    "pokered:PEWTER_CITY": (13, 26),
    "pokered:CERULEAN_CITY": (19, 18),
    "pokered:LAVENDER_TOWN": (3, 6),
    "pokered:VERMILION_CITY": (11, 4),
    "pokered:CELADON_CITY": (41, 10),
    "pokered:FUCHSIA_CITY": (19, 28),
    "pokered:CINNABAR_ISLAND": (11, 12),
    "pokered:INDIGO_PLATEAU": (9, 6),
    "pokered:SAFFRON_CITY": (9, 30),
    "pokered:ROUTE_4": (11, 6),
    "pokered:ROUTE_10": (11, 20),
}


class BlackoutTests(unittest.TestCase):
    def test_defeat_page_is_the_pokered_blackout_text(self):
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        branch = battle.split("if not playerTeamAlive then", 1)[1].split(
            'return "defeat"', 1)[0]
        self.assertIn('playerName .. " is out of\\nuseable POKéMON!\\f"', branch)
        self.assertIn('playerName .. " blacked\\nout!"', branch)
        self.assertIn('intro.stage == "rival_fight"', branch)

    def test_blackout_does_not_resume_the_rival_script(self):
        state = (ROOT / "Source/game/battleState.lua").read_text()
        lost = state.split("if not receipt.won then", 1)[1].split(
            "if receipt.initial_lab", 1)[0]
        self.assertLess(lost.index("if blackout then return end"), lost.index("descriptor.lost"))
        self.assertIn("game:returnToCheckpoint()", state)

    def test_wipe_page_and_center_fly_warps(self):
        completed = subprocess.run(
            ["lua5.4", str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("blackout-page-ok", completed.stdout)
        context = (ROOT / "Source/game/context.lua").read_text()
        self.assertIn('local HEAL <const> = {zone_id="pallet_town",x=5,y=6,facing="down"}', context)
        events = (ROOT / "Source/game/eventState.lua").read_text()
        self.assertIn(
            '{zone_id="pokered:VIRIDIAN_CITY",x=23,y=26,facing="down"}', events)
        events = json.loads((ROOT / "Source/data/sourceEvents.json").read_text())["events"]
        nurse = events["pokered:VIRIDIAN_POKECENTER:objects:1"]["steps"][0]
        self.assertEqual(nurse["op"], "heal")
        self.assertNotIn("checkpoint", nurse)
        seen = set()

        def walk(node):
            if isinstance(node, dict):
                if node.get("op") == "heal" and "checkpoint" in node:
                    spot = node["checkpoint"]
                    zone = spot["zone_id"]
                    self.assertEqual(
                        (spot["x"], spot["y"], spot["facing"]),
                        (*FLY_WARPS[zone], "down"),
                        zone)
                    seen.add(zone)
                for value in node.values():
                    walk(value)
            elif isinstance(node, list):
                for value in node:
                    walk(value)

        for path in (
            "Source/data/sourceEvents.json",
            "Source/data/sourceSlice/events.json",
            "Source/data/midgameEast/events.json",
            "Source/data/midgameSouth/events.json",
            "Source/data/midgameSaffron/events.json",
            "Source/data/vermilionPreparation/events.json",
            "Source/data/zCoast/events.json",
            "Source/data/zEndgame/events.json",
        ):
            payload = json.loads((ROOT / path).read_text())
            walk(payload.get("events", payload))
        self.assertTrue(seen >= set(FLY_WARPS) - {"pokered:PALLET_TOWN", "pokered:VIRIDIAN_CITY"})


if __name__ == "__main__":
    unittest.main()
