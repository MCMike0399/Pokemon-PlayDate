#!/usr/bin/env python3
"""A beaten Elite Four room still blocks the south door.

pret/pokered af519899 scripts/LoreleisRoom.asm LoreleisRoomDefaultScript
stands on LoreleiEntranceCoords and does not check EVENT_BEAT. A coord
index below 3, and index 3 or 4 once EVENT_AUTOWALKED_INTO_LORELEIS_ROOM
is set, prints Don't run away and forces one step up.
LoreleiShowOrHideExitBlock only replaces the north block at (0, 2).
Bruno and Agatha use the same entrance test. The first elite_four loop
in the file is exclamation(); it never dispatches the door. The
dont-run return is the loop inside EndgameStory.check.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-e4-door-lock.patch"


def door_loop(source):
    check = source.split("function EndgameStory.check(game)", 1)[1]
    check = check.split("\nlocal function ", 1)[0]
    found = []
    for part in check.split("for _, room in ipairs(data.elite_four) do")[1:]:
        if 'action == "dont-run"' in part:
            found.append(part)
    return found


def beaten_branch(source):
    action = source.split("function EndgameStory.entranceAction", 1)[1].split(
        "function EndgameStory.besideTrainer", 1)[0]
    return action.split("if flags[room.flag] then", 1)[1].split("end", 1)[0]


def story_text():
    live = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
    if 'return "dont-run"' in beaten_branch(live) and "south door stays shut after the win" in live:
        return live
    work = Path(tempfile.mkdtemp(prefix="e4-door-"))
    subprocess.run(["git", "init"], cwd=work, check=True, capture_output=True)
    for relative in ("Source/game/endgameStory.lua", "tools/tests/test_lane_d_endgame.py"):
        target = work / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((ROOT / relative).read_bytes())
    subprocess.run(["git", "add", "-A"], cwd=work, check=True, capture_output=True)
    applied = subprocess.run(["git", "apply", str(PATCH)], cwd=work, capture_output=True, text=True)
    if applied.returncode != 0:
        raise AssertionError(applied.stderr)
    return (work / "Source/game/endgameStory.lua").read_text(encoding="utf-8")


class E4DoorLockTests(unittest.TestCase):
    def test_beaten_room_still_blocks_the_south_door(self):
        self.assertTrue(PATCH.is_file(), PATCH)
        self.assertNotIn("MallocPoolSize", PATCH.read_text(encoding="utf-8"))
        source = story_text()
        self.assertIn('return "dont-run"', beaten_branch(source))
        loops = door_loop(source)
        self.assertEqual(len(loops), 1)
        loop = loops[0]
        self.assertIn("south door stays shut after the win", loop)
        self.assertIn('action == "dont-run"', loop)
        self.assertNotIn("elseif not game.session:questFlag(room.flag) then", loop)


if __name__ == "__main__":
    unittest.main()
