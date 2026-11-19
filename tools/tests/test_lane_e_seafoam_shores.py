"""Route 20's two Seafoam doors meet by surfing the cave.

pret/pokered af519899 enters at Route 20 (48, 5), which is SeafoamIslands1F
warp 1, and leaves at Route 20 (58, 9), which is warp 3. Cavern water is
foot $14. data/tilesets/collision_tile_ids.asm leaves that tile out of
Cavern_Coll, so the stored grid is solid, and FieldTravel.surfStep still
crosses it. Tile-pair collisions stay closed. The east exits are LAST_MAP,
so the walk counts them even though they have no interior destination.
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
# fieldTravel.lua surfSurface: cavern water plus the two non-port shore feet.
SURF_FEET = {0x14, 0x32, 0x48}


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
        surf = [
            [
                data["grids"][identity - 1]["terrain"]["water_candidate"]
                and data["grids"][identity - 1]["terrain"]["foot_tile"] in SURF_FEET
                for identity in row
            ]
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
                    width=width, height=height, doors=doors, pairs=pairs, surf=surf):
            if start == goal:
                return True
            queue, seen = deque([start]), {start}
            while queue:
                x, y = queue.popleft()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nxt = (x + dx, y + dy)
                    if nxt in seen or not (0 <= nxt[0] < width and 0 <= nxt[1] < height):
                        continue
                    solid = collision[nxt[1]][nxt[0]] and not surf[nxt[1]][nxt[0]]
                    if solid or nxt in boulders:
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
            # objects/SeafoamIslands1F.asm warps 3 and 4 are LAST_MAP, 2.
            return here["index"] == 2
        for other in warps:
            key = (name, other["i"])
            if key in seen:
                continue
            # LAST_MAP exits have no interior map. They are still the Route 20 doors.
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
    def test_route_20_doors_match_the_cave_exits(self):
        route = json.loads((COAST / "Route20.json").read_text())
        warps = route["events"]["warps"]
        self.assertEqual((warps[0]["x"], warps[0]["y"], warps[0]["destination"]["warp_index"]), (48, 5, 1))
        self.assertEqual((warps[1]["x"], warps[1]["y"], warps[1]["destination"]["warp_index"]), (58, 9, 3))
        self.assertEqual(warps[0]["destination"]["map"], "SEAFOAM_ISLANDS_1F")
        self.assertEqual(warps[1]["destination"]["map"], "SEAFOAM_ISLANDS_1F")

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
