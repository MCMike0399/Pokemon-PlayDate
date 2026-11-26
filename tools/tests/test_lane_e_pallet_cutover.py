"""Imported Pallet Town is the town a new game walks, and Fly lands there.

The hand-authored tile rows are gone. New Game starts in reds_house_2f
and heals at pallet_town (5, 6); both zones are the padded pokered
collision. The south connection is Route 21. Fly's visited entry keeps
the source id pokered:PALLET_TOWN.
"""
import json
import unittest
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = {
    "RedsHouse2F": {"key": "kanto_reds_house_2f", "pad": 2, "width": 13, "tileset": "REDS_HOUSE_2"},
    "RedsHouse1F": {"key": "kanto_reds_house_1f", "pad": 2, "width": 13, "tileset": "REDS_HOUSE_1"},
    "PalletTown": {"key": "kanto_pallet_town", "pad": 0, "width": 20, "tileset": "OVERWORLD"},
    "OaksLab": {"key": "kanto_oaks_lab", "pad": 1, "width": 13, "tileset": "DOJO"},
}


def _load(name):
    return json.loads((ROOT / "Source/data/zRemainder" / f"{name}.json").read_text())


def _surface(name):
    spec = MAPS[name]
    data = _load(name)
    rows = data["collision"]
    right = spec["width"] - len(rows[0]) - spec["pad"]
    grid = [[1] * spec["pad"] + row + [1] * right for row in rows]
    blocked = {(obj["x"] + spec["pad"], obj["y"]) for obj in data["events"]["objects"]}
    return grid, blocked, data


def _door_tiles():
    compact = json.loads((ROOT / "Source/data/sourceMapCache/compact.json").read_text())
    return compact["door_tiles"], compact["maps"]


def _foot(name, x, y):
    spec = MAPS[name]
    data = _load(name)
    tile = data["tile_ids"][y][x - spec["pad"]]
    return data["grids"][tile - 1]["terrain"]["foot_tile"]


def _warps(compact_maps, name):
    record = compact_maps[name]
    interior = record["tileset"]["constant"] not in ("OVERWORLD", "FOREST")
    found = []
    for warp in record["warps"]:
        edge = "down" if interior and warp["y"] == record["height"] - 1 else None
        found.append({**warp, "edge": edge})
    return found


def _landing(compact_maps, door_tiles, destination, warp_index):
    record = compact_maps[destination]
    warp = record["warps"][warp_index - 1]
    x, y = warp["x"], warp["y"]
    grid, _, _ = _surface(destination)
    tileset = record["tileset"]["constant"]
    door = _foot(destination, x, y) in door_tiles.get(tileset, [])
    if door and y + 1 < record["height"] and grid[y + 1][x] == 0:
        return x, y + 1
    return x, y


def _reaches(name, start, goal):
    grid, blocked, _ = _surface(name)
    height, width = len(grid), len(grid[0])
    pending = deque([start])
    seen = {start}
    while pending:
        x, y = pending.popleft()
        if (x, y) == goal:
            return True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            step = (nx, ny)
            if (0 <= nx < width and 0 <= ny < height and grid[ny][nx] == 0
                    and step not in blocked and step not in seen):
                seen.add(step)
                pending.append(step)
    return False


class PalletCutoverTests(unittest.TestCase):
    def test_new_game_walks_from_reds_room_into_oaks_lab(self):
        context = (ROOT / "Source/game/context.lua").read_text()
        maps = (ROOT / "Source/data/maps.lua").read_text()
        story = (ROOT / "Source/game/story.lua").read_text()
        self.assertIn('zone_id="reds_house_2f",x=5,y=3,facing="up"', context)
        self.assertIn('zone_id="pallet_town",x=5,y=6,facing="down"', context)
        for key, filename in (
            ("reds_house_2f", "RedsHouse2F"),
            ("reds_house", "RedsHouse1F"),
            ("blues_house", "BluesHouse"),
            ("oaks_lab", "OaksLab"),
            ("pallet_town", "PalletTown"),
        ):
            self.assertIn(f'"{key}"', maps)
            self.assertIn(filename, maps)
        self.assertIn('to = LAB_KEY, toX = 6, toY = 4', story)
        self.assertIn('{ x = 7, y = 3, species = "charmander" }', story)
        door_tiles, compact_maps = _door_tiles()
        stairs = next(warp for warp in _warps(compact_maps, "RedsHouse2F") if not warp["edge"])
        self.assertTrue(_reaches("RedsHouse2F", (5, 3), (stairs["x"], stairs["y"])))
        downstairs = _landing(compact_maps, door_tiles, "RedsHouse1F", stairs["destination"]["warp_index"])
        exits = [warp for warp in _warps(compact_maps, "RedsHouse1F") if warp["edge"] == "down"]
        self.assertTrue(any(_reaches("RedsHouse1F", downstairs, (warp["x"], warp["y"])) for warp in exits))
        outside = _landing(compact_maps, door_tiles, "PalletTown", exits[0]["destination"]["warp_index"])
        lab_door = next(warp for warp in _warps(compact_maps, "PalletTown")
                        if warp["destination"].get("map") == "OAKS_LAB")
        self.assertTrue(_reaches("PalletTown", outside, (lab_door["x"], lab_door["y"])))
        lab = _landing(compact_maps, door_tiles, "OaksLab", lab_door["destination"]["warp_index"])
        grid, _, _ = _surface("OaksLab")
        self.assertEqual(grid[lab[1]][lab[0]], 0)

    def test_south_exit_is_route_21_and_fly_uses_the_source_map(self):
        compact = json.loads((ROOT / "Source/data/sourceMapCache/compact.json").read_text())
        pallet = compact["maps"]["PalletTown"]
        south = next(row for row in pallet["connections"] if row["direction"] == "south")
        self.assertEqual(south["target_map"], "ROUTE_21")
        self.assertEqual(pallet["id"], "pokered:PALLET_TOWN")
        manifest = json.loads((ROOT / "Source/data/sourceMaps.json").read_text())
        route = next(entry for entry in manifest["maps"].values() if entry["id"] == "pokered:ROUTE_21")
        self.assertEqual(route["key"], "kanto_route_21")
        fly = json.loads((ROOT / "Source/data/fieldTravel.json").read_text())["fly"]
        entry = next(row for row in fly if row["name"] == "PalletTown")
        self.assertEqual(entry["id"], "pokered:PALLET_TOWN")
        self.assertEqual(entry["source_map"], "PALLET_TOWN")
        self.assertEqual((entry["x"], entry["y"]), (5, 6))
        runtime = (ROOT / "Source/game/fieldTravelRuntime.lua").read_text()
        self.assertNotIn('zone_id == "pallet_town"', runtime)


if __name__ == "__main__":
    unittest.main()
