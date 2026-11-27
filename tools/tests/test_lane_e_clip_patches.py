"""The 18ee8c5c clip recheck.

The heal gap is still in this tree: test_lane_e_audio_fidelity.py fails on it
until tools/notes/lane-e-audio-heal-gap.patch is applied.

The move row and the receipt fanfare are already in this tree. Their notes
apply to main 18ee8c5c, where the clips showed tackle playing only "hit" and
the Route 1 potion receipt playing only the text blip.
"""
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = "18ee8c5c"


def show(path):
    return subprocess.check_output(
        ["git", "show", f"{MAIN}:{path}"], cwd=ROOT)


def apply_note(blob_name, blob, note):
    with tempfile.TemporaryDirectory() as tmp:
        tree = Path(tmp)
        destination = tree / blob_name
        destination.parent.mkdir(parents=True)
        destination.write_bytes(blob)
        subprocess.run(["git", "init", "-q"], cwd=tree, check=True)
        subprocess.run(["git", "add", "-A"], cwd=tree, check=True)
        subprocess.run(
            ["git", "apply", str(ROOT / "tools/notes" / note)],
            cwd=tree, check=True)
        return {
            path.relative_to(tree).as_posix(): path.read_text()
            for path in tree.rglob("*") if path.is_file() and ".git" not in path.parts
        }


class LaneEClipPatchTests(unittest.TestCase):
    def test_move_row_patch_applies_to_main_and_plays_the_move_before_hit(self):
        original = show("Source/game/kantoAudio.lua").decode()
        self.assertNotIn('playSequence({moveCue, "hit"})', original)
        text = apply_note(
            "Source/game/kantoAudio.lua",
            original.encode(),
            "lane-e-audio-move-row.patch")
        self.assertIn('playSequence({moveCue, "hit"})', text["Source/game/kantoAudio.lua"])

    def test_this_tree_already_plays_the_move_row_then_hit(self):
        text = (ROOT / "Source/game/kantoAudio.lua").read_text()
        self.assertIn('playSequence({moveCue, "hit"})', text)

    def test_receipt_patch_applies_to_main_and_fans_the_potion(self):
        original = show("Source/game/kantoAudio.lua").decode()
        self.assertNotIn('audio/fieldReceipts', original)
        patched = apply_note(
            "Source/game/kantoAudio.lua",
            original.encode(),
            "lane-e-audio-receipt-fanfare.patch")
        self.assertIn(
            'playdate.file.run("audio/fieldReceipts")',
            patched["Source/game/kantoAudio.lua"])
        self.assertIn(
            '["_Route1Youngster1GotPotionText"] = "item"',
            patched["Source/audio/fieldReceipts.lua"])
        receipts = (ROOT / "Source/audio/fieldReceipts.lua").read_text()
        self.assertIn('["_Route1Youngster1GotPotionText"] = "item"', receipts)

    def test_heal_gap_patch_inserts_the_fifteen_frame_wait(self):
        patched = apply_note(
            "Source/game/kantoAudio.lua",
            (ROOT / "Source/game/kantoAudio.lua").read_bytes(),
            "lane-e-audio-heal-gap.patch")
        text = patched["Source/game/kantoAudio.lua"]
        self.assertIn("enqueueSFX(names[index], 15)", text)
        self.assertIn("DelayFrames(30)", text)


if __name__ == "__main__":
    unittest.main()
