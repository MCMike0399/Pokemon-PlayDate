"""Squirtle golden path from Cerulean through Bill to Vermilion.

pret/pokered af519899. The city south of the mart does not walk onto Route 5.
The burgled house back door does, and the backyard Rocket stands on that walk.
The y=32 ledge drops onto a Route 5 strip that never reaches the underground.
"""

import importlib.util
import json
import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = "af519899719f0754965776faac0e836a3b906e6d"
HELPER = Path(__file__).with_name("test_lane_k_route4_exit.py")


def load_helper():
    spec = importlib.util.spec_from_file_location("lane_k_route4_exit", HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_slice(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def walk_reach(collision, start, blocked=()):
    height, width = len(collision), len(collision[0])
    blocked = set(blocked)
    seen = {start}
    pending = [start]
    while pending:
        x, y = pending.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = (x + dx, y + dy)
            if nxt in seen or nxt in blocked:
                continue
            nx, ny = nxt
            if 0 <= nx < width and 0 <= ny < height and collision[ny][nx] == 0:
                seen.add(nxt)
                pending.append(nxt)
    return seen


def slice_warps(data):
    rows = []
    for warp in data["events"]["warps"]:
        dest = warp["destination"]
        name = dest.get("map") or dest.get("kind")
        if name == "last_outdoor_map":
            name = "LAST_MAP"
        rows.append((warp["x"], warp["y"], name, dest["warp_index"]))
    return rows


def feet_match(data, feet, allowed):
    mismatches = []
    for y, row in enumerate(feet):
        for x, foot in enumerate(row):
            grid = data["grids"][data["tile_ids"][y][x] - 1]
            collision = data["collision"][y][x]
            if grid["source_tile_ids"][2] != foot or collision != (0 if foot in allowed else 1):
                mismatches.append((x, y, foot, grid["source_tile_ids"][2], collision))
    return mismatches


class SquirtleNuggetPathTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        cls.ref = Path(reference)
        revision = subprocess.check_output(
            ["git", "-C", str(cls.ref), "rev-parse", "HEAD"], text=True).strip()
        if revision != REVISION:
            raise AssertionError(revision)
        cls.helper = load_helper()
        cls.overworld = (cls.ref / "gfx/blocksets/overworld.bst").read_bytes()
        cls.house = (cls.ref / "gfx/blocksets/house.bst").read_bytes()
        cls.underground = (cls.ref / "gfx/blocksets/underground.bst").read_bytes()
        tiles = (cls.ref / "data/tilesets/collision_tile_ids.asm").read_text(encoding="utf-8")
        cls.overworld_coll = cls.helper.coll_set(tiles, "Overworld_Coll")
        cls.house_coll = cls.helper.coll_set(tiles, "House_Coll")
        cls.underground_coll = cls.helper.coll_set(tiles, "Underground_Coll")
        cls.sizes = (cls.ref / "constants/map_constants.asm").read_text(encoding="utf-8")

    def assert_overworld(self, asm_name, blk, relative):
        width, height = self.helper.map_blocks(self.sizes, asm_name)
        feet = self.helper.feet_from_blocks(
            (self.ref / "maps" / blk).read_bytes(), self.overworld, width, height)
        data = load_slice(relative)
        self.assertEqual(data["source_revision"], REVISION)
        self.assertEqual(data["directional_rules"]["forbidden_tile_pairs"], [])
        self.assertEqual(feet_match(data, feet, self.overworld_coll), [])
        asm = (self.ref / "data/maps/objects" / f"{Path(blk).stem}.asm").read_text(encoding="utf-8")
        self.assertEqual(slice_warps(data), self.helper.warps(asm))
        return data

    def test_nugget_bridge_bill_and_the_rival_return(self):
        route24 = self.assert_overworld("ROUTE_24", "Route24.blk", "Source/data/sourceSlice/Route24.json")
        route25 = self.assert_overworld("ROUTE_25", "Route25.blk", "Source/data/sourceSlice/Route25.json")
        city = self.assert_overworld("CERULEAN_CITY", "CeruleanCity.blk", "Source/data/sourceSlice/CeruleanCity.json")
        script = (self.ref / "scripts/Route24.asm").read_text(encoding="utf-8")
        self.assertIn("dbmapcoord 10, 15", script)
        objects = (self.ref / "data/maps/objects/Route24.asm").read_text(encoding="utf-8")
        self.assertIn("object_event 11, 15, SPRITE_COOLTRAINER_M, STAY, LEFT, TEXT_ROUTE24_COOLTRAINER_M1, OPP_ROCKET, 6", objects)
        self.assertIn("object_event 11, 31, SPRITE_YOUNGSTER, STAY, LEFT, TEXT_ROUTE24_YOUNGSTER2, OPP_BUG_CATCHER, 9", objects)
        self.assertIn("object_event 10,  5, SPRITE_POKE_BALL, STAY, NONE, TEXT_ROUTE24_TM_THUNDER_WAVE, TM_THUNDER_WAVE", objects)
        parties = (self.ref / "data/trainers/parties.asm").read_text(encoding="utf-8")
        rocket = parties.split("RocketData:", 1)[1].split("\n\n", 1)[0]
        self.assertIn("db 15, EKANS, ZUBAT, 0", rocket)
        bridge = walk_reach(route24["collision"], (10, 35))
        self.assertIn((10, 15), bridge)
        self.assertIn((11, 31), bridge)
        east = [y for y in range(len(route24["collision"])) if (19, y) in bridge and route25["collision"][y][0] == 0]
        self.assertEqual(east, [8, 9])
        for y in east:
            self.assertIn((45, 3), walk_reach(route25["collision"], (0, y)))
        self.assertEqual(route25["collision"][3][45], 0)
        bills = load_slice("Source/data/sourceSlice/BillsHouse.json")
        self.assertEqual(slice_warps(bills), self.helper.warps(
            (self.ref / "data/maps/objects/BillsHouse.asm").read_text(encoding="utf-8")))
        self.assertIn((6, 5), walk_reach(bills["collision"], (2, 7)))
        bill_script = (self.ref / "scripts/BillsHouse.asm").read_text(encoding="utf-8")
        answered = bill_script.split("\n.answered_no\n", 1)[1].split("\n.text_script_end\n", 1)[0]
        self.assertIn("jr .use_machine", answered)
        self.assertIn("SCRIPT_BILLSHOUSE_POKEMON_WALK_TO_MACHINE", bill_script.split(".use_machine", 1)[1])
        city_walk = walk_reach(city["collision"], (19, 17))
        self.assertIn((20, 0), city_walk)
        self.assertIn((21, 0), city_walk)
        self.assertIn((20, 6), city_walk)
        self.assertIn((21, 6), city_walk)
        self.assertIn((30, 19), city_walk)
        self.assertNotIn((11, 35), city_walk)
        cerulean = (self.ref / "scripts/CeruleanCity.asm").read_text(encoding="utf-8")
        self.assertIn("dbmapcoord 20,  6", cerulean)
        self.assertIn("dbmapcoord 21,  6", cerulean)
        starter3 = cerulean.split("\n.NotSquirtle\n", 1)[1].split("\n.Charmander\n", 1)[0]
        self.assertIn("cp STARTER3", starter3)
        self.assertIn("ld a, $8", starter3)
        rival = parties.split("; Cerulean City", 1)[1].split("; Unused", 1)[0]
        self.assertIn("db $FF, 18, PIDGEOTTO, 15, ABRA, 15, RATTATA, 17, BULBASAUR, 0", rival)

    def test_back_door_reaches_vermilion_center(self):
        city = load_slice("Source/data/sourceSlice/CeruleanCity.json")
        house = load_slice("Source/data/sourceSlice/CeruleanTrashedHouse.json")
        route5 = self.assert_overworld("ROUTE_5", "Route5.blk", "Source/data/vermilionPreparation/Route5.json")
        route6 = self.assert_overworld("ROUTE_6", "Route6.blk", "Source/data/vermilionPreparation/Route6.json")
        vermilion = self.assert_overworld(
            "VERMILION_CITY", "VermilionCity.blk", "Source/data/vermilionPreparation/VermilionCity.json")
        width, height = self.helper.map_blocks(self.sizes, "CERULEAN_TRASHED_HOUSE")
        house_feet = self.helper.feet_from_blocks(
            (self.ref / "maps/CeruleanTrashedHouse.blk").read_bytes(), self.house, width, height)
        self.assertEqual(feet_match(house, house_feet, self.house_coll), [])
        self.assertEqual(slice_warps(house), self.helper.warps(
            (self.ref / "data/maps/objects/CeruleanTrashedHouse.asm").read_text(encoding="utf-8")))
        self.assertIn((3, 0), walk_reach(house["collision"], (2, 7)))
        self.assertIn((3, 0), walk_reach(house["collision"], (3, 7)))
        center = walk_reach(city["collision"], (19, 17))
        self.assertIn((27, 11), center)
        self.assertNotIn((27, 9), center)
        backyard = walk_reach(city["collision"], (27, 9))
        self.assertIn((11, 35), backyard)
        self.assertIn((25, 35), backyard)
        self.assertNotIn((16, 35), backyard)
        self.assertNotIn((11, 35), walk_reach(city["collision"], (27, 9), blocked=((30, 7), (30, 8), (30, 9))))
        cerulean = (self.ref / "scripts/CeruleanCity.asm").read_text(encoding="utf-8")
        self.assertIn("dbmapcoord 30,  7", cerulean)
        self.assertIn("dbmapcoord 30,  9", cerulean)
        objects = (self.ref / "data/maps/objects/CeruleanCity.asm").read_text(encoding="utf-8")
        self.assertIn("object_event 30,  8, SPRITE_ROCKET, STAY, NONE, TEXT_CERULEANCITY_ROCKET, OPP_ROCKET, 5", objects)
        parties = (self.ref / "data/trainers/parties.asm").read_text(encoding="utf-8")
        self.assertIn("db 17, MACHOP, DROWZEE, 0", parties.split("RocketData:", 1)[1].split("; Route 24", 1)[0])
        south = next(row for row in city["connections"] if row["direction"] == "south")
        self.assertEqual(south["entry_lateral_adjustment_cells"], -10)
        route = walk_reach(route5["collision"], (1, 0))
        for x in (11, 12, 13, 14, 25, 26, 27, 28):
            self.assertIn((x - 10, 0), route)
            self.assertIn((17, 27), route)
        self.assertIn((9, 29), route)
        self.assertIn((10, 29), route)
        self.assertNotIn((10, 33), route)
        self.assertNotIn((17, 27), walk_reach(route5["collision"], (6, 0)))
        ug5 = load_slice("Source/data/vermilionPreparation/UndergroundPathRoute5.json")
        corridor = load_slice("Source/data/vermilionPreparation/UndergroundPathNorthSouth.json")
        ug6 = load_slice("Source/data/vermilionPreparation/UndergroundPathRoute6.json")
        self.assertEqual(slice_warps(ug5), self.helper.warps(
            (self.ref / "data/maps/objects/UndergroundPathRoute5.asm").read_text(encoding="utf-8")))
        self.assertEqual(slice_warps(ug6), self.helper.warps(
            (self.ref / "data/maps/objects/UndergroundPathRoute6.asm").read_text(encoding="utf-8")))
        self.assertEqual(slice_warps(corridor), self.helper.warps(
            (self.ref / "data/maps/objects/UndergroundPathNorthSouth.asm").read_text(encoding="utf-8")))
        self.assertIn((4, 4), walk_reach(ug5["collision"], (3, 7)))
        blk = (self.ref / "maps/UndergroundPathNorthSouth.blk").read_bytes()
        self.assertEqual(len(blk), 4 * 23)
        feet = self.helper.feet_from_blocks(blk, self.underground, 4, 23)
        self.assertEqual(len(corridor["collision"]), 48)
        self.assertEqual(feet_match(
            {"grids": corridor["grids"], "tile_ids": corridor["tile_ids"][:len(feet)],
             "collision": corridor["collision"][:len(feet)]},
            feet, self.underground_coll), [])
        self.assertIn((2, 41), walk_reach(corridor["collision"], (5, 4)))
        self.assertIn((4, 4), walk_reach(ug6["collision"], (3, 7)))
        south_road = walk_reach(route6["collision"], (17, 13))
        self.assertEqual(sorted(cell for cell in south_road if cell[1] == 35), [(8, 35), (9, 35)])
        self.assertIn((10, 7), south_road)
        self.assertNotIn((10, 1), south_road)
        link = next(row for row in route6["connections"] if row["direction"] == "south")
        self.assertEqual(link["entry_lateral_adjustment_cells"], 10)
        arrival = walk_reach(vermilion["collision"], (18, 0))
        self.assertIn((19, 0), arrival)
        self.assertIn((11, 3), arrival)
        self.assertIn((23, 13), arrival)
        self.assertNotIn((12, 19), arrival)
