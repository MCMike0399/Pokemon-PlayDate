"""Silph Co. 9F must not paint a solid panel on the plain facility floor.

Lane E has not applied this yet. The panel is the locked card-key door
pokered:SILPH_CO_9F:hidden_events:1003. tools/notes/lane-e-silph-9f-panel.patch
leaves that block as the floor cells already stored in SilphCo9F.json.
The same solid graphic on door 1002 is cleared with it.
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
PANEL = "pokered:FACILITY:cell:08-08-18-18"


def _doors(root):
    scenes = json.loads((root / "Source/data/silphStory/scenes.json").read_text())
    return {door["id"]: door for door in scenes["scenes"]["doors"]["pokered:SILPH_CO_9F"]}


def _floor_key(root, x, y):
    data = json.loads((root / "Source/data/midgameSaffron/SilphCo9F.json").read_text())
    tile = data["tile_ids"][y][x]
    return data["grids"][tile - 1]["stable_id"]


def assert_no_solid_panel(root):
    doors = _doors(root)
    door = doors["pokered:SILPH_CO_9F:hidden_events:1003"]
    if door["x"] != 9 or door["y"] != 5:
        raise AssertionError("9F door 3 moved")
    if door["closed_keys"] != [FLOOR, FLOOR, FLOOR, FLOOR]:
        raise AssertionError("door 3 still paints a panel")
    if PANEL in doors["pokered:SILPH_CO_9F:hidden_events:1002"]["closed_keys"]:
        raise AssertionError("door 2 still paints the same panel")
    for x, y in ((18, 10), (19, 10)):
        if _floor_key(root, x, y) != FLOOR:
            raise AssertionError(f"SilphCo9F cell {x},{y} is not the plain floor")


class LaneESilphPanelTests(unittest.TestCase):
    def test_silph_9f_panel_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
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
            assert_no_solid_panel(scratch)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    @unittest.expectedFailure
    def test_silph_9f_floor_has_no_solid_panel(self):
        assert_no_solid_panel(ROOT)


if __name__ == "__main__":
    unittest.main()
