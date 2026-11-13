"""Route Pallet's five rooms onto the imported kanto maps.

Lane E has not applied this yet. tools/notes/lane-e-pallet-cutover.patch
retires the hand-authored tile rows and keeps a New Game walk: Red's
bedroom, down the stairs, out the door, and into Oak's Lab.
"""
import json
import shutil
import subprocess
import tempfile
import unittest
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-pallet-cutover.patch"

MAPS = {
    "RedsHouse2F": {"key": "kanto_reds_house_2f", "pad": 2, "width": 13, "tileset": "REDS_HOUSE_2"},
    "RedsHouse1F": {"key": "kanto_reds_house_1f", "pad": 2, "width": 13, "tileset": "REDS_HOUSE_1"},
    "PalletTown": {"key": "kanto_pallet_town", "pad": 0, "width": 20, "tileset": "OVERWORLD"},
    "OaksLab": {"key": "kanto_oaks_lab", "pad": 1, "width": 13, "tileset": "DOJO"},
}


def _load(root, name):
    return json.loads((root / "Source/data/zRemainder" / f"{name}.json").read_text())


def _surface(root, name):
    spec = MAPS[name]
    data = _load(root, name)
    rows = data["collision"]
    right = spec["width"] - len(rows[0]) - spec["pad"]
    grid = [[1] * spec["pad"] + row + [1] * right for row in rows]
    blocked = {(obj["x"] + spec["pad"], obj["y"]) for obj in data["events"]["objects"]}
    return grid, blocked, data


def _door_tiles(root):
    compact = json.loads((root / "Source/data/sourceMapCache/compact.json").read_text())
    return compact["door_tiles"], compact["maps"]


def _foot(root, name, x, y):
    spec = MAPS[name]
    data = _load(root, name)
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


def _landing(root, compact_maps, door_tiles, destination, warp_index):
    record = compact_maps[destination]
    warp = record["warps"][warp_index - 1]
    x, y = warp["x"], warp["y"]
    grid, _, _ = _surface(root, destination)
    tileset = record["tileset"]["constant"]
    door = _foot(root, destination, x, y) in door_tiles.get(tileset, [])
    if door and y + 1 < record["height"] and grid[y + 1][x] == 0:
        return x, y + 1
    return x, y


def _reaches(root, name, start, goal):
    grid, blocked, _ = _surface(root, name)
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


def assert_new_game_walk(root):
    context = (root / "Source/game/context.lua").read_text()
    maps = (root / "Source/data/maps.lua").read_text()
    story = (root / "Source/game/story.lua").read_text()
    if 'zone_id="pokered:REDS_HOUSE_2F",x=5,y=3,facing="up"' not in context:
        raise AssertionError("New Game does not spawn in the imported bedroom")
    if 'zone_id="pokered:PALLET_TOWN",x=5,y=6,facing="down"' not in context:
        raise AssertionError("checkpoint is not the imported Pallet door")
    for key in ("pallet_town", "oaks_lab", "reds_house", "reds_house_2f", "blues_house"):
        if f'registerZone("{key}"' in maps:
            raise AssertionError(f"authored {key} is still registered")
    if 'to = LAB_KEY, toX = 6, toY = 4' not in story:
        raise AssertionError("Oak's escort does not enter the imported lab")
    if "{ x = 7, y = 3, species = \"charmander\" }" not in story:
        raise AssertionError("starter balls are not on the imported table")
    door_tiles, compact_maps = _door_tiles(root)
    start = (5, 3)
    stairs = next(warp for warp in _warps(compact_maps, "RedsHouse2F") if not warp["edge"])
    if not _reaches(root, "RedsHouse2F", start, (stairs["x"], stairs["y"])):
        raise AssertionError("bedroom cannot reach the stairs")
    downstairs = _landing(root, compact_maps, door_tiles, "RedsHouse1F", stairs["destination"]["warp_index"])
    exits = [warp for warp in _warps(compact_maps, "RedsHouse1F") if warp["edge"] == "down"]
    if not any(_reaches(root, "RedsHouse1F", downstairs, (warp["x"], warp["y"])) for warp in exits):
        raise AssertionError("downstairs cannot reach the front door")
    outside = _landing(root, compact_maps, door_tiles, "PalletTown", exits[0]["destination"]["warp_index"])
    lab_door = next(warp for warp in _warps(compact_maps, "PalletTown")
                    if warp["destination"].get("map") == "OAKS_LAB")
    if not _reaches(root, "PalletTown", outside, (lab_door["x"], lab_door["y"])):
        raise AssertionError("Pallet door cannot reach Oak's Lab")
    lab = _landing(root, compact_maps, door_tiles, "OaksLab", lab_door["destination"]["warp_index"])
    grid, _, _ = _surface(root, "OaksLab")
    if grid[lab[1]][lab[0]] != 0:
        raise AssertionError("Oak's Lab arrival is blocked")


class LaneEPalletCutoverTests(unittest.TestCase):
    def test_pallet_cutover_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        scratch = Path(tempfile.mkdtemp(prefix="lane-e-pallet-cutover-"))
        try:
            completed = subprocess.run(
                ["git", "worktree", "add", "--detach", str(scratch), "HEAD"],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["git", "apply", str(PATCH)],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            assert_new_game_walk(scratch)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    @unittest.expectedFailure
    def test_new_game_walks_from_reds_room_into_oaks_lab(self):
        assert_new_game_walk(ROOT)


if __name__ == "__main__":
    unittest.main()
