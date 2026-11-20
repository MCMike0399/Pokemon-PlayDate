"""Route 4's east exit reaches Cerulean on the same graph as pokered.

pret/pokered af519899. J's pause 5a428a2c98f5 stands at (59, 4) and presses
right into foot $27. That step is solid in maps/Route4.blk. The open walk
goes south around that column, then down a ledge onto the east road.
"""

import json
import os
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = "af519899719f0754965776faac0e836a3b906e6d"
FACING = {
    "SPRITE_FACING_DOWN": (0, 1),
    "SPRITE_FACING_LEFT": (-1, 0),
    "SPRITE_FACING_RIGHT": (1, 0),
    "SPRITE_FACING_UP": (0, -1),
}


def quadrant_ids(blockset, block_id, quadrant):
    qx, qy = quadrant % 2, quadrant // 2
    base = block_id * 16
    return [blockset[base + (2 * qy + row) * 4 + 2 * qx + col]
            for row in range(2) for col in range(2)]


def feet_from_blocks(blk, blockset, width, height):
    if len(blk) != width * height:
        raise AssertionError(f"block map is {len(blk)} bytes, expected {width * height}")
    rows = [[0] * (width * 2) for _ in range(height * 2)]
    for by in range(height):
        for bx in range(width):
            block = blk[by * width + bx]
            for quadrant in range(4):
                ids = quadrant_ids(blockset, block, quadrant)
                rows[by * 2 + quadrant // 2][bx * 2 + quadrant % 2] = ids[2]
    return rows


def coll_set(text, label):
    match = re.search(rf"{label}::\s*coll_tiles\s+(.+)", text)
    if not match:
        raise AssertionError(f"{label} missing")
    return {int(token, 16) for token in re.findall(r"\$([0-9a-fA-F]+)", match.group(1))}


def ledge_rules(text):
    rules = []
    for facing, stand, front, button in re.findall(
            r"db\s+(SPRITE_FACING_\w+),\s+\$([0-9A-Fa-f]+),\s+\$([0-9A-Fa-f]+),\s+(PAD_\w+)",
            text):
        rules.append((facing, int(stand, 16), int(front, 16), button))
    if len(rules) != 8:
        raise AssertionError(f"LedgeTiles has {len(rules)} rules")
    return rules


def map_blocks(text, name):
    match = re.search(rf"map_const\s+{name},\s+(\d+),\s+(\d+)", text)
    if not match:
        raise AssertionError(f"{name} size missing")
    return int(match.group(1)), int(match.group(2))


def warps(text):
    return [(int(x), int(y), dest, int(index)) for x, y, dest, index in re.findall(
        r"warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)", text)]


def edges(feet, allowed, rules):
    height, width = len(feet), len(feet[0])
    solid = [[feet[y][x] not in allowed for x in range(width)] for y in range(height)]
    result = set()
    for y in range(height):
        for x in range(width):
            if solid[y][x]:
                continue
            for facing, stand, front, _button in rules:
                dx, dy = FACING[facing]
                nx, ny = x + dx, y + dy
                lx, ly = x + 2 * dx, y + 2 * dy
                if feet[y][x] == stand and 0 <= nx < width and 0 <= ny < height and feet[ny][nx] == front:
                    if 0 <= lx < width and 0 <= ly < height and not solid[ly][lx]:
                        result.add((x, y, lx, ly))
            for dx, dy in FACING.values():
                nx, ny = x + dx, y + dy
                if not (0 <= nx < width and 0 <= ny < height) or solid[ny][nx]:
                    continue
                if any(feet[y][x] == stand and feet[ny][nx] == front and (dx, dy) == FACING[facing]
                       for facing, stand, front, _button in rules):
                    continue
                result.add((x, y, nx, ny))
    return result


def reachable(start, graph):
    neighbors = {}
    for x, y, nx, ny in graph:
        neighbors.setdefault((x, y), []).append((nx, ny))
    seen = {start}
    pending = [start]
    while pending:
        cell = pending.pop()
        for nxt in neighbors.get(cell, ()):
            if nxt not in seen:
                seen.add(nxt)
                pending.append(nxt)
    return seen


class Route4ExitTests(unittest.TestCase):
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

    def test_mt_moon_exit_reaches_cerulean_without_opening_the_cliff(self):
        ref = self.ref
        constants = (ref / "constants/map_constants.asm").read_text(encoding="utf-8")
        route_blocks = map_blocks(constants, "ROUTE_4")
        city_blocks = map_blocks(constants, "CERULEAN_CITY")
        blockset = (ref / "gfx/blocksets/overworld.bst").read_bytes()
        allowed = coll_set(
            (ref / "data/tilesets/collision_tile_ids.asm").read_text(encoding="utf-8"),
            "Overworld_Coll")
        rules = ledge_rules((ref / "data/tilesets/ledge_tiles.asm").read_text(encoding="utf-8"))
        route_feet = feet_from_blocks(
            (ref / "maps/Route4.blk").read_bytes(), blockset, *route_blocks)
        city_feet = feet_from_blocks(
            (ref / "maps/CeruleanCity.blk").read_bytes(), blockset, *city_blocks)
        route = json.loads((ROOT / "Source/data/sourceSlice/Route4.json").read_text(encoding="utf-8"))
        city = json.loads((ROOT / "Source/data/sourceSlice/CeruleanCity.json").read_text(encoding="utf-8"))
        self.assertEqual(route["directional_rules"]["forbidden_tile_pairs"], [])
        self.assertEqual(
            [(rule["facing"], rule["standing_foot_tile"], rule["target_foot_tile"], rule["input"])
             for rule in route["directional_rules"]["ledges"]],
            rules)
        mismatches = []
        for y, row in enumerate(route_feet):
            for x, foot in enumerate(row):
                grid = route["grids"][route["tile_ids"][y][x] - 1]
                committed = grid["source_tile_ids"][2]
                collision = route["collision"][y][x]
                if committed != foot or collision != (0 if foot in allowed else 1):
                    mismatches.append((x, y, foot, committed, collision))
        self.assertEqual(mismatches, [])
        pokered = edges(route_feet, allowed, rules)
        committed_feet = [[route["grids"][route["tile_ids"][y][x] - 1]["source_tile_ids"][2]
                           for x in range(len(route_feet[0]))] for y in range(len(route_feet))]
        committed = edges(committed_feet, allowed, rules)
        self.assertEqual(pokered, committed)
        self.assertEqual(warps((ref / "data/maps/objects/Route4.asm").read_text(encoding="utf-8")), [
            (11, 5, "MT_MOON_POKECENTER", 1),
            (18, 5, "MT_MOON_1F", 1),
            (24, 5, "MT_MOON_B1F", 8),
        ])
        moon = warps((ref / "data/maps/objects/MtMoonB1F.asm").read_text(encoding="utf-8"))
        self.assertEqual(moon[7], (27, 3, "LAST_MAP", 3))
        self.assertEqual(
            [(warp["x"], warp["y"], warp["destination"]["map"], warp["destination"]["warp_index"])
             for warp in route["events"]["warps"]],
            [(11, 5, "MT_MOON_POKECENTER", 1), (18, 5, "MT_MOON_1F", 1), (24, 5, "MT_MOON_B1F", 8)])
        self.assertEqual(route["collision"][6][24], 0)
        landed = reachable((24, 6), pokered)
        self.assertIn((59, 4), landed)
        self.assertNotIn((59, 4, 60, 4), pokered)
        self.assertEqual(route_feet[4][60], 0x27)
        self.assertNotIn(0x27, allowed)
        self.assertIn((59, 4, 59, 5), pokered)
        self.assertIn((60, 6), landed)
        self.assertNotIn((19, 6), landed)
        self.assertNotIn((11, 5), landed)
        self.assertEqual(route_feet[6][23], 0x24)
        self.assertNotIn(0x24, allowed)
        self.assertTrue(any((x, 8, x, 10) in pokered and (x, 8) in landed for x in range(64, 80)))
        self.assertIn((89, 10), landed)
        self.assertIn((89, 11), landed)
        adjustment = next(item["entry_lateral_adjustment_cells"]
                          for item in route["connections"] if item["direction"] == "east")
        self.assertEqual(adjustment, 8)
        for y, arrival in ((10, 18), (11, 19)):
            self.assertIn((89, y), landed)
            self.assertIn(city_feet[arrival][0], allowed)
            self.assertEqual(city["collision"][arrival][0], 0)


if __name__ == "__main__":
    unittest.main()
