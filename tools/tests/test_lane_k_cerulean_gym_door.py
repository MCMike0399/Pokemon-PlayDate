"""Cerulean Gym door is the pokered warp at (30, 19).

pret/pokered af519899. (12, 19) is Vermilion. The Center and the Mart
both walk onto (30, 20), and the entering step is north onto the door.
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


def walk_reach(collision, start):
    height, width = len(collision), len(collision[0])
    seen = {start}
    pending = [start]
    while pending:
        x, y = pending.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = (x + dx, y + dy)
            if nxt in seen:
                continue
            nx, ny = nxt
            if 0 <= nx < width and 0 <= ny < height and collision[ny][nx] == 0:
                seen.add(nxt)
                pending.append(nxt)
    return seen


class CeruleanGymDoorTests(unittest.TestCase):
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
        tiles = (cls.ref / "data/tilesets/collision_tile_ids.asm").read_text(encoding="utf-8")
        cls.overworld_coll = cls.helper.coll_set(tiles, "Overworld_Coll")
        cls.gym_coll = cls.helper.coll_set(tiles, "Gym_Coll")
        cls.sizes = (cls.ref / "constants/map_constants.asm").read_text(encoding="utf-8")

    def test_center_and_mart_step_onto_misty_door(self):
        helper = self.helper
        width, height = helper.map_blocks(self.sizes, "CERULEAN_CITY")
        feet = helper.feet_from_blocks(
            (self.ref / "maps/CeruleanCity.blk").read_bytes(),
            (self.ref / "gfx/blocksets/overworld.bst").read_bytes(), width, height)
        city = load_slice("Source/data/sourceSlice/CeruleanCity.json")
        self.assertEqual(city["source_revision"], REVISION)
        self.assertEqual(city["directional_rules"]["forbidden_tile_pairs"], [])
        mismatches = []
        for y, row in enumerate(feet):
            for x, foot in enumerate(row):
                grid = city["grids"][city["tile_ids"][y][x] - 1]
                collision = city["collision"][y][x]
                if grid["source_tile_ids"][2] != foot or collision != (0 if foot in self.overworld_coll else 1):
                    mismatches.append((x, y))
        self.assertEqual(mismatches, [])
        asm = (self.ref / "data/maps/objects/CeruleanCity.asm").read_text(encoding="utf-8")
        warps = helper.warps(asm)
        self.assertEqual(warps[3], (30, 19, "CERULEAN_GYM", 1))
        self.assertEqual(feet[19][30], 0x1B)
        self.assertIn(0x1B, self.overworld_coll)
        self.assertEqual(city["collision"][19][30], 0)
        self.assertEqual(city["collision"][20][30], 0)
        for neighbor in ((30, 18), (29, 19), (31, 19)):
            self.assertEqual(city["collision"][neighbor[1]][neighbor[0]], 1)
        center = walk_reach(city["collision"], (19, 17))
        mart = walk_reach(city["collision"], (25, 25))
        self.assertIn((30, 20), center)
        self.assertIn((30, 19), center)
        self.assertIn((30, 20), mart)
        self.assertIn((30, 19), mart)
        for x in range(19, 31):
            self.assertEqual(city["collision"][20][x], 0)
        for y in range(17, 21):
            self.assertEqual(city["collision"][y][19], 0)
        for x in range(25, 35):
            self.assertEqual(city["collision"][26][x], 0)
        for y in range(20, 27):
            self.assertEqual(city["collision"][y][34], 0)

        gym_w, gym_h = helper.map_blocks(self.sizes, "CERULEAN_GYM")
        gym_feet = helper.feet_from_blocks(
            (self.ref / "maps/CeruleanGym.blk").read_bytes(),
            (self.ref / "gfx/blocksets/gym.bst").read_bytes(), gym_w, gym_h)
        gym = load_slice("Source/data/sourceSlice/CeruleanGym.json")
        gym_asm = (self.ref / "data/maps/objects/CeruleanGym.asm").read_text(encoding="utf-8")
        self.assertEqual(helper.warps(gym_asm), [(4, 13, "LAST_MAP", 4), (5, 13, "LAST_MAP", 4)])
        gym_mismatches = []
        for y, row in enumerate(gym_feet):
            for x, foot in enumerate(row):
                grid = gym["grids"][gym["tile_ids"][y][x] - 1]
                collision = gym["collision"][y][x]
                if grid["source_tile_ids"][2] != foot or collision != (0 if foot in self.gym_coll else 1):
                    gym_mismatches.append((x, y))
        self.assertEqual(gym_mismatches, [])
        inside = walk_reach(gym["collision"], (4, 13))
        self.assertIn((5, 2), inside)
        self.assertIn((5, 3), inside)
        self.assertEqual(len(gym["collision"]), 14)
        manifest = json.loads((ROOT / "Source/data/sourceMaps.json").read_text(encoding="utf-8"))
        self.assertIsNone(manifest["maps"]["CeruleanCity"].get("blocked_events"))
        self.assertIsNone(manifest["maps"]["CeruleanGym"].get("blocked_events"))
        script = (self.ref / "scripts/CeruleanGym.asm").read_text(encoding="utf-8")
        self.assertIn("trainer EVENT_BEAT_CERULEAN_GYM_TRAINER_0, 3,", script)
        parties = (self.ref / "data/trainers/parties.asm").read_text(encoding="utf-8")
        self.assertIn("db $FF, 18, STARYU, 21, STARMIE, 0", parties.split("MistyData:", 1)[1].split("\n\n", 1)[0])
