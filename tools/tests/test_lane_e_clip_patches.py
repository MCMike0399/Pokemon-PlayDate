"""BlueBot's three notes, revised against main 906657a4.

Each test is red on that commit before its patch and green after. The notes
stay unapplied in this tree. Source/ui/dialog.lua and Source/game/eventState.lua
are outside Source/audio; they are in the receipt note for lane E because the
text engine has to play the jingle and wait for it.
"""
import math
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = "906657a46d8893f4281a4632333d175ec8f2f79f"
TICK = 70224 / 4194304
NOTES = {
    "heal": "lane-e-audio-heal-gap.patch",
    "move": "lane-e-audio-move-row.patch",
    "receipt": "lane-e-audio-receipt-fanfare.patch",
}
BASE_FILES = (
    "Source/game/kantoAudio.lua",
    "Source/audio/engine.lua",
    "Source/ui/dialog.lua",
    "Source/game/eventState.lua",
)


def show(path):
    return subprocess.check_output(["git", "show", f"{MAIN}:{path}"], cwd=ROOT)


def gb_frames(frames):
    return max(1, math.ceil(frames * TICK * 30))


def apply_notes(names):
    tree = Path(tempfile.mkdtemp(prefix="lane-e-note-"))
    for relative in BASE_FILES:
        destination = tree / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(show(relative))
    subprocess.run(["git", "init", "-q"], cwd=tree, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tree, check=True)
    for name in names:
        subprocess.run(
            ["git", "apply", str(ROOT / "tools/notes" / NOTES[name])],
            cwd=tree, check=True)
    return tree


def lua(path, chunk):
    program = f"dofile({str(path)!r})\n{chunk}"
    return subprocess.check_output(["lua5.4", "-e", program], text=True)


class LaneEClipPatchTests(unittest.TestCase):
    def test_heal_gap_is_red_before_and_matches_animate_healing_machine_after(self):
        original = show("Source/game/kantoAudio.lua").decode()
        self.assertIn("playSequence(names)", original)
        self.assertNotIn("KantoHeal.plan", original)
        tree = apply_notes(["heal"])
        try:
            text = (tree / "Source/game/kantoAudio.lua").read_text()
            self.assertIn("KantoHeal.plan(count)", text)
            self.assertIn("DelayFrames(30)", text)
            self.assertNotIn("\n            playSequence(names)\n", text)
            dumped = lua(tree / "Source/audio/healSchedule.lua", """
local function dump(count)
    local events, total = KantoHeal.plan(count)
    local parts = {}
    for _, event in ipairs(events) do
        parts[#parts + 1] = event.name .. "@" .. event.at
    end
    print(table.concat(parts, ",") .. " total=" .. total)
end
dump(1)
dump(6)
""")
            jingle = gb_frames(136)
            tail = gb_frames(32)
            one = ["healing_machine@0", "heal@15"]
            six = [f"healing_machine@{index * 15}" for index in range(6)] + ["heal@90"]
            lines = dumped.strip().splitlines()
            self.assertEqual(lines[0], ",".join(one) + f" total={15 + jingle + tail}")
            self.assertEqual(lines[1], ",".join(six) + f" total={90 + jingle + tail}")
            self.assertEqual(lines[0].count("healing_machine"), 1)
            self.assertEqual(lines[1].count("healing_machine"), 6)
            self.assertTrue(lines[0].endswith("heal@15 total=" + str(15 + jingle + tail)))
            self.assertIn("heal@90", lines[1])
        finally:
            subprocess.run(["rm", "-rf", str(tree)], check=True)



if __name__ == "__main__":
    unittest.main()
