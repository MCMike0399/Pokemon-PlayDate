"""Squirtle can reach Brock on the source maps, without a debug warp.

The fixture is a post-Oak party: intro done, starter Squirtle. The walk is
Pallet's north connection, Route 1, Viridian, Route 2, the forest gates, and
Pewter's gym door. pret/pokered af519899 data/trainers/parties.asm BrockData
is level 12 Geodude then level 14 Onix. scripts/PewterGym.asm gives the
Boulder Badge and TM34, and clears the first Route 22 rival.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def compact():
    return json.loads((ROOT / "Source/data/sourceMapCache/compact.json").read_text())["maps"]


class SquirtlePewterTests(unittest.TestCase):
    def test_route_reaches_the_gym_door(self):
        maps = compact()

        def north(name):
            return next(row["target_header"] for row in maps[name]["connections"] if row["direction"] == "north")

        self.assertEqual(north("PalletTown"), "Route1")
        self.assertEqual(north("Route1"), "ViridianCity")
        self.assertEqual(north("ViridianCity"), "Route2")
        self.assertEqual(north("Route2"), "PewterCity")
        forest = {warp["id"]: warp["destination"]["map"] for warp in maps["Route2"]["warps"]}
        self.assertEqual(forest["pokered:ROUTE_2:warps:2"], "VIRIDIAN_FOREST_NORTH_GATE")
        self.assertEqual(forest["pokered:ROUTE_2:warps:6"], "VIRIDIAN_FOREST_SOUTH_GATE")
        self.assertEqual(maps["ViridianForestNorthGate"]["last_outdoor"], "Route2")
        self.assertEqual(maps["ViridianForestSouthGate"]["last_outdoor"], "Route2")
        gym_door = next(warp for warp in maps["PewterCity"]["warps"] if warp["x"] == 16 and warp["y"] == 17)
        self.assertEqual(gym_door["destination"]["map"], "PEWTER_GYM")
        self.assertEqual(gym_door["destination"]["warp_index"], 1)
        self.assertEqual(maps["PewterGym"]["last_outdoor"], "PewterCity")
        brock = json.loads((ROOT / "Source/data/pewterSlice/PewterGym.json").read_text())
        objects = brock["events"]["objects"]
        self.assertEqual(objects[0]["id"], "pokered:PEWTER_GYM:objects:1")
        self.assertEqual((objects[0]["x"], objects[0]["y"]), (4, 1))

    def test_brock_party_badge_and_squirtle_matchup(self):
        trainers = json.loads((ROOT / "Source/data/pewterSlice/trainers.json").read_text())["trainers"]
        brock = next(row for row in trainers if row["id"] == "pokered:PEWTER_GYM:objects:1")
        junior = next(row for row in trainers if row["id"] == "pokered:PEWTER_GYM:objects:2")
        self.assertEqual(
            [(mon["species"], mon["level"]) for mon in brock["party"]],
            [("geodude", 12), ("onix", 14)])
        self.assertEqual(brock["payout"], 1386)
        self.assertTrue(brock["talk_only"])
        self.assertEqual(brock["sight_range_cells"], 0)
        self.assertEqual(
            [(mon["species"], mon["level"]) for mon in junior["party"]],
            [("diglett", 11), ("sandshrew", 11)])
        self.assertEqual(junior["sight_range_cells"], 5)
        self.assertTrue(junior["deactivated_by_brock"])
        events = json.loads((ROOT / "Source/data/sourceEvents.json").read_text())["events"]
        victory = events["pokered:PEWTER_GYM:objects:1"]
        self.assertEqual(victory["reward"]["item"], "tm34")
        self.assertEqual(victory["reward"]["flag"], "EVENT_GOT_TM34")
        self.assertTrue(victory["victory"]["flags"]["BADGE_BOULDER"])
        self.assertFalse(victory["victory"]["flags"]["EVENT_1ST_ROUTE22_RIVAL_BATTLE"])
        self.assertFalse(victory["victory"]["flags"]["EVENT_ROUTE22_RIVAL_WANTS_BATTLE"])
        self.assertTrue(victory["victory"]["trainers"]["pokered:PEWTER_GYM:objects:2"])
        chart = (ROOT / "Source/data/typechart.lua").read_text()
        self.assertIn("water = { dragon = 0.5, fire = 2.0, grass = 0.5, ground = 2.0, rock = 2.0, water = 0.5 }", chart)
        species = (ROOT / "Source/data/pokemon.lua").read_text()
        self.assertIn('squirtle = {\n        name = "SQUIRTLE", dex = 7, type = "water"', species)
        self.assertIn('geodude = {\n        name = "GEODUDE", dex = 74, type = "rock", type2 = "ground"', species)
        self.assertIn('onix = {\n        name = "ONIX", dex = 95, type = "rock", type2 = "ground"', species)
        self.assertIn("bubble|7|", species.split("squirtle = {", 1)[1].split("wartortle = {", 1)[0])
        self.assertIn("waterGun|13|", species.split("squirtle = {", 1)[1].split("wartortle = {", 1)[0])


if __name__ == "__main__":
    unittest.main()
