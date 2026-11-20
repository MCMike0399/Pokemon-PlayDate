#!/usr/bin/env python3
"""Route 2's cave side reaches Pewter only after the tree at (5, 10).

pret/pokered af519899. Diglett's Cave Route 2 warp is (12, 9). The step
left of (11, 2) is foot $55. maps/Route2.blk has no four-direction path
from that door to the north edge until Cut replaces block $32 with $6D.
"""

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_lane_k_route4_exit as route4

ROOT = Path(__file__).resolve().parents[2]
REVISION = route4.REVISION
CAVE = (12, 9)
DEAD_END = (11, 2)
WALL = (10, 2)
TREE = (5, 10)
STAND = (5, 11)
NORTH = ((8, 0), (9, 0))


def reference():
    raw = os.environ.get("POKERED_REFERENCE_DIR")
    if not raw:
        raise RuntimeError("POKERED_REFERENCE_DIR is required")
    path = Path(raw)
    if not path.is_dir():
        raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
    return path


class Route2CaveSideTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ref = reference()
        revision = subprocess.check_output(
            ["git", "-C", str(cls.ref), "rev-parse", "HEAD"], text=True).strip()
        if revision != REVISION:
            raise AssertionError(revision)
        constants = (cls.ref / "constants/map_constants.asm").read_text(encoding="utf-8")
        cls.blocks = route4.map_blocks(constants, "ROUTE_2")
        cls.blockset = (cls.ref / "gfx/blocksets/overworld.bst").read_bytes()
        cls.allowed = route4.coll_set(
            (cls.ref / "data/tilesets/collision_tile_ids.asm").read_text(encoding="utf-8"),
            "Overworld_Coll")
        cls.rules = route4.ledge_rules(
            (cls.ref / "data/tilesets/ledge_tiles.asm").read_text(encoding="utf-8"))
        cls.feet = route4.feet_from_blocks(
            (cls.ref / "maps/Route2.blk").read_bytes(), cls.blockset, *cls.blocks)
        cls.route = json.loads(
            (ROOT / "Source/data/pewterSlice/Route2.json").read_text(encoding="utf-8"))
        cls.field = json.loads(
            (ROOT / "Source/data/fieldMoveMaps/Route2.json").read_text(encoding="utf-8"))

    def test_installed_route2_feet_match_pokered(self):
        route = self.route
        self.assertEqual(route["source_revision"], REVISION)
        self.assertEqual(route["directional_rules"]["forbidden_tile_pairs"], [])
        self.assertEqual(
            [(rule["facing"], rule["standing_foot_tile"], rule["target_foot_tile"], rule["input"])
             for rule in route["directional_rules"]["ledges"]],
            self.rules)
        mismatches = []
        for y, row in enumerate(self.feet):
            for x, foot in enumerate(row):
                grid = route["grids"][route["tile_ids"][y][x] - 1]
                committed = grid["source_tile_ids"][2]
                collision = route["collision"][y][x]
                if committed != foot or collision != (0 if foot in self.allowed else 1):
                    mismatches.append((x, y, foot, committed, collision))
        self.assertEqual(mismatches, [])
        self.assertEqual(
            route4.edges(self.feet, self.allowed, self.rules),
            route4.edges(
                [[route["grids"][route["tile_ids"][y][x] - 1]["source_tile_ids"][2]
                  for x in range(len(self.feet[0]))] for y in range(len(self.feet))],
                self.allowed, self.rules))

    def test_digletts_cave_reaches_pewter_only_after_the_route2_cut(self):
        objects = (self.ref / "data/maps/objects/Route2.asm").read_text(encoding="utf-8")
        self.assertIn((12, 9, "DIGLETTS_CAVE_ROUTE_2", 1), route4.warps(objects))
        self.assertEqual(
            [(warp["x"], warp["y"], warp["destination"]["map"], warp["destination"]["warp_index"])
             for warp in self.route["events"]["warps"] if warp["x"] == 12 and warp["y"] == 9],
            [(12, 9, "DIGLETTS_CAVE_ROUTE_2", 1)])
        header = (self.ref / "data/maps/headers/Route2.asm").read_text(encoding="utf-8")
        self.assertIn("connection north, PewterCity, PEWTER_CITY, -5", header)
        adjustment = next(item["entry_lateral_adjustment_cells"]
                          for item in self.route["connections"] if item["direction"] == "north")
        self.assertEqual(adjustment, 10)
        self.assertEqual(self.feet[WALL[1]][WALL[0]], 0x55)
        self.assertNotIn(0x55, self.allowed)
        self.assertEqual(self.route["collision"][WALL[1]][WALL[0]], 1)
        self.assertEqual(self.feet[DEAD_END[1]][DEAD_END[0]], 0x23)
        self.assertIn(0x23, self.allowed)
        closed = route4.edges(self.feet, self.allowed, self.rules)
        cave = route4.reachable(CAVE, closed)
        self.assertIn(DEAD_END, cave)
        self.assertIn(STAND, cave)
        self.assertNotIn((DEAD_END[0], DEAD_END[1], WALL[0], WALL[1]), closed)
        for edge in NORTH:
            self.assertNotIn(edge, cave)
            self.assertIn(self.feet[edge[1]][edge[0]], self.allowed)
        self.assertEqual(self.feet[TREE[1]][TREE[0]], 0x3d)
        self.assertNotIn(0x3d, self.allowed)
        block = (self.ref / "maps/Route2.blk").read_bytes()[5 * self.blocks[0] + 2]
        self.assertEqual(block, 0x32)
        swaps = (self.ref / "data/tilesets/cut_tree_blocks.asm").read_text(encoding="utf-8")
        self.assertIn("db $32, $6D", swaps)
        replacement = route4.quadrant_ids(self.blockset, 0x6D, 1)
        self.assertEqual(replacement, [0x2C, 0x2C, 0x2C, 0x2C])
        self.assertIn(0x2C, self.allowed)
        site = next(item for item in self.field["record"]["sites"]
                    if item["x"] == 4 and item["y"] == 10)
        self.assertEqual(site["block"], 0x32)
        self.assertEqual(site["replacement"], 0x6D)
        changed = [cell for cell in site["cells"] if cell["before"] != cell["after"]]
        self.assertEqual(
            [(cell["x"], cell["y"], cell["before"], cell["after"]) for cell in changed],
            [(5, 10, "pokered:OVERWORLD:cell:2d-2e-3d-3e", "pokered:OVERWORLD:cell:2c-2c-2c-2c")])
        self.assertEqual(site["targets"], [{"x": 5, "y": 10}])
        opened_feet = [row[:] for row in self.feet]
        opened_feet[TREE[1]][TREE[0]] = 0x2C
        opened = route4.reachable(CAVE, route4.edges(opened_feet, self.allowed, self.rules))
        for edge in NORTH:
            self.assertIn(edge, opened)
        self.assertIn(STAND, opened)
        self.assertNotIn(WALL, opened)


if __name__ == "__main__":
    unittest.main()
