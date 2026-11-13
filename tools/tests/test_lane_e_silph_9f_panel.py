"""Silph Co. 9F locked card-key doors must keep blocking.

Lane E has not applied this yet. The r16 note replaced doors 1002 and
1003 with the floor cell, which is how those locked doors became
walkable. Pokered's SilphCo9F.blk stores floor at block (9, 2) and
(9, 5). SilphCo9FGateCallbackScript writes block $54 there while the
door is locked, and card_key.asm opens a door only when tile $18 or
$24 is in front of the player. tools/notes/lane-e-silph-9f-panel.patch
leaves those closed keys in place.
"""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-silph-9f-panel.patch"
FLOOR = "pokered:FACILITY:cell:01-01-01-01"
DOOR = "pokered:FACILITY:cell:08-08-18-18"
DOORS = (
    ("pokered:SILPH_CO_9F:hidden_events:1002", 9, 2),
    ("pokered:SILPH_CO_9F:hidden_events:1003", 9, 5),
)


def _doors(root):
    scenes = json.loads((root / "Source/data/silphStory/scenes.json").read_text())
    return {door["id"]: door for door in scenes["scenes"]["doors"]["pokered:SILPH_CO_9F"]}


def _map_key(root, x, y):
    data = json.loads((root / "Source/data/midgameSaffron/SilphCo9F.json").read_text())
    tile = data["tile_ids"][y][x]
    return data["grids"][tile - 1]["stable_id"]


def _collision(root, key):
    tiles = json.loads((root / "Source/data/sourceMapCache/tile-grids.json").read_text())["tiles"]
    entry = tiles[key]
    blocked = entry["collision"] == 1 and entry["terrain"]["land_passable"] is False
    return blocked


def assert_locked_doors_block(root):
    doors = _doors(root)
    for door_id, x, y in DOORS:
        door = doors[door_id]
        if (door["x"], door["y"], door["closed_block"]) != (x, y, 0x54):
            raise AssertionError(f"{door_id} is not pokered block $54 at ({x}, {y})")
        if door["closed_keys"] != [DOOR, DOOR, FLOOR, FLOOR]:
            raise AssertionError(f"{door_id} closed graphic is not the card-key door")
        if door["open_keys"] != [FLOOR, FLOOR, FLOOR, FLOOR]:
            raise AssertionError(f"{door_id} no longer opens onto floor")
        for quadrant, key in enumerate(door["closed_keys"]):
            cell_x = x * 2 + quadrant % 2
            cell_y = y * 2 + quadrant // 2
            blocked = _collision(root, key)
            if key == DOOR and not blocked:
                raise AssertionError(f"locked door cell {cell_x},{cell_y} does not block")
            if key == FLOOR and blocked:
                raise AssertionError(f"floor cell {cell_x},{cell_y} blocks")
    if not _collision(root, DOOR) or _collision(root, FLOOR):
        raise AssertionError("door and floor passability are reversed")
    for x, y in ((18, 10), (19, 10)):
        if _map_key(root, x, y) != FLOOR:
            raise AssertionError(f"SilphCo9F static cell {x},{y} is not pokered floor")


class LaneESilphPanelTests(unittest.TestCase):
    def test_silph_9f_panel_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        text = PATCH.read_text()
        self.assertNotIn("closed_keys", text)
        scratch = Path(tempfile.mkdtemp(prefix="lane-e-silph-panel-"))
        try:
            completed = subprocess.run(
                ["git", "worktree", "add", "--detach", str(scratch), "HEAD"],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["git", "apply", str(PATCH)],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            assert_locked_doors_block(scratch)
            source = (scratch / "Source/game/silphStoryWorld.lua").read_text()
            self.assertIn("block $54", source)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    def test_locked_doors_block_and_panel_cells_match_pokered_floor(self):
        assert_locked_doors_block(ROOT)

    @unittest.expectedFailure
    def test_reconcile_records_the_pokered_card_key_block(self):
        source = (ROOT / "Source/game/silphStoryWorld.lua").read_text()
        if "block $54" not in source:
            raise AssertionError("locked-door placement is not recorded")


if __name__ == "__main__":
    unittest.main()
