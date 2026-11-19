"""Seafoam's two Route 20 doors do not meet.

pret/pokered crosses Route 20 through Seafoam Islands. The east door is
Route 20 (48, 5). The west door is Route 20 (58, 9), and the water beside
that door reaches Cinnabar. The cave stairs do not join those doors. Water
tile pairs block the walk, and removing every boulder still leaves the west
door out of reach. The boulder scripts are gaps in
Source/data/zCoast/scripts.json. This test fails until a real stair or
current path connects the doors. No source patch is applied here.
"""

import json
import unittest
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COAST = ROOT / "Source/data/zCoast"
FLOORS = [
    "SeafoamIslands1F",
    "SeafoamIslandsB1F",
    "SeafoamIslandsB2F",
    "SeafoamIslandsB3F",
    "SeafoamIslandsB4F",
]


def _connected(ignore_boulders):
    maps = {}
    for name in FLOORS:
        data = json.loads((COAST / f"{name}.json").read_text())
        collision = data["collision"]
        height, width = len(collision), len(collision[0])
        pairs = data["directional_rules"]["forbidden_tile_pairs"]
        feet = [
            [data["grids"][identity - 1]["terrain"]["foot_tile"] for identity in row]
            for row in data["tile_ids"]
        ]
        boulders = set()
        if not ignore_boulders:
            boulders = {
                (obj["x"], obj["y"])
                for obj in data["events"]["objects"]
                if "BOULDER" in obj["sprite"]
            }
        warps = []
        for index, warp in enumerate(data["events"]["warps"], 1):
            dest = warp["destination"]
            warps.append({
                "i": index,
                "xy": (warp["x"], warp["y"]),
                "map": dest.get("map"),
                "index": dest.get("warp_index"),
            })
        doors = {warp["xy"] for warp in warps}

        def reaches(start, goal, boulders=boulders, feet=feet, collision=collision,
                    width=width, height=height, doors=doors, pairs=pairs):
            if start == goal:
                return True
            queue, seen = deque([start]), {start}
            while queue:
                x, y = queue.popleft()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nxt = (x + dx, y + dy)
                    if nxt in seen or not (0 <= nxt[0] < width and 0 <= nxt[1] < height):
                        continue
                    if collision[nxt[1]][nxt[0]] or nxt in boulders:
                        continue
                    if nxt in doors and nxt != goal:
                        continue
                    pair = (feet[y][x], feet[nxt[1]][nxt[0]])
                    if any(pair == (a, b) or pair == (b, a) for a, b in pairs):
                        continue
                    if nxt == goal:
                        return True
                    seen.add(nxt)
                    queue.append(nxt)
            return False

        maps[name] = (warps, reaches)

    def floor_name(map_id):
        return map_id.replace("SEAFOAM_ISLANDS_", "SeafoamIslands") if map_id else None

    start = ("SeafoamIslands1F", 1)
    queue, seen = deque([start]), {start}
    while queue:
        name, index = queue.popleft()
        warps, reaches = maps[name]
        here = next(warp for warp in warps if warp["i"] == index)
        if name == "SeafoamIslands1F" and index in (3, 4):
            return True
        for other in warps:
            key = (name, other["i"])
            if key in seen or not other["map"]:
                continue
            if reaches(here["xy"], other["xy"]):
                seen.add(key)
                queue.append(key)
        if here["map"]:
            key = (floor_name(here["map"]), here["index"])
            if key not in seen and key[0] in maps and any(warp["i"] == here["index"] for warp in maps[key[0]][0]):
                seen.add(key)
                queue.append(key)
    return False


class SeafoamShoreTests(unittest.TestCase):
    def test_east_door_reaches_the_west_door(self):
        self.assertTrue(
            _connected(False),
            "Seafoam east door does not reach the west door",
        )

    def test_west_door_is_reachable_without_boulders(self):
        self.assertTrue(
            _connected(True),
            "removing every boulder still leaves the west door unreachable",
        )


if __name__ == "__main__":
    unittest.main()
