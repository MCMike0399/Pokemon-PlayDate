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

    def test_move_row_is_red_before_and_uses_effectiveness_after(self):
        original = show("Source/game/kantoAudio.lua").decode()
        self.assertIn('KantoAudio.playSFX("hit")', original)
        self.assertNotIn("KantoAttack.cue", original)
        self.assertNotIn("damage_super", original)
        moves = show("Source/audio/moveSfxData.lua").decode()
        self.assertIn('tackle = "move_tackle"', moves)
        self.assertIn('bite = "move_bite"', moves)
        tackle = show("Source/audio/score/move_tackle.lua").decode()
        bite = show("Source/audio/score/move_bite.lua").decode()
        self.assertIn("audio2:SFX_Super_Effective", tackle)
        self.assertIn("-- pitch modifier 16 tempo modifier 160", tackle)
        self.assertIn("audio2:SFX_Battle_1E", bite)
        self.assertNotEqual(tackle, bite)
        tree = apply_notes(["move"])
        try:
            text = (tree / "Source/game/kantoAudio.lua").read_text()
            self.assertNotIn('KantoAudio.playSFX("hit")', text)
            self.assertIn("local played = moveCue and KantoAudio.playSFX(moveCue)", text)
            self.assertIn("KantoAttack.cue(attackEffectiveness(battle, victim))", text)
            self.assertIn("playSequence({moveCue, damage})", text)
            self.assertIn('moveCue = moveKey and moveScore(moveKey)', text)
            engine = (tree / "Source/audio/engine.lua").read_text()
            for name in ("damage_normal", "damage_super", "damage_not_very"):
                self.assertIn(f"{name} = 2", engine)
            cues = lua(tree / "Source/audio/attackSound.lua", """
for _, value in ipairs({1, 2, 4, 0.5, 0.25, 0}) do
    print(tostring(KantoAttack.cue(value)))
end
""")
            self.assertEqual(
                cues.strip().splitlines(),
                ["damage_normal", "damage_super", "damage_super",
                 "damage_not_very", "damage_not_very", "nil"])
            normal = (tree / "Source/audio/score/damage_normal.lua").read_text()
            super_hit = (tree / "Source/audio/score/damage_super.lua").read_text()
            weak = (tree / "Source/audio/score/damage_not_very.lua").read_text()
            self.assertIn("audio2:SFX_Damage", normal)
            self.assertIn("-- pitch modifier 32 tempo modifier 48", normal)
            self.assertIn("audio2:SFX_Super_Effective", super_hit)
            self.assertIn("-- pitch modifier 224 tempo modifier 255", super_hit)
            self.assertIn("audio2:SFX_Not_Very_Effective", weak)
            self.assertIn("-- pitch modifier 80 tempo modifier 1", weak)
            self.assertNotIn("-- pitch modifier 16 tempo modifier 160", super_hit)
            self.assertTrue((tree / "Source/audio/score/damage_super.bin").stat().st_size > 0)
        finally:
            subprocess.run(["rm", "-rf", str(tree)], check=True)

    def test_receipt_fanfare_is_red_before_and_generated_after(self):
        original = show("Source/game/kantoAudio.lua").decode()
        dialog = show("Source/ui/dialog.lua").decode()
        event = show("Source/game/eventState.lua").decode()
        self.assertNotIn("audio/fieldReceipts", original)
        self.assertNotIn("beginReceipt", original)
        self.assertNotIn("textHold", dialog)
        self.assertNotIn("receiptCue", event)
        source = os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered")
        from tools.audio.events import emit_receipts, field_receipts
        from tools.audio.source import Source
        receipts = field_receipts(Source(source))
        generated = emit_receipts({"field_receipts": receipts}).decode()
        self.assertEqual(receipts["_Route1Youngster1GotPotionText"]["cue"], "item")
        self.assertEqual(receipts["_OaksLabOak1DeliverParcelText"]["cue"], "key_item")
        self.assertIn("item2", {row["cue"] for row in receipts.values()})
        tree = apply_notes(["receipt"])
        try:
            patched = (tree / "Source/audio/fieldReceipts.lua").read_text()
            self.assertEqual(patched, generated)
            self.assertIn('["_Route1Youngster1GotPotionText"] = "item"', patched)
            self.assertIn('["_OaksLabOak1DeliverParcelText"] = "key_item"', patched)
            audio = (tree / "Source/game/kantoAudio.lua").read_text()
            self.assertIn('playdate.file.run("audio/fieldReceipts")', audio)
            self.assertIn("KantoReceipt.holdFrames", audio)
            self.assertIn("observer.textHold", audio)
            dialog = (tree / "Source/ui/dialog.lua").read_text()
            self.assertIn("KantoAudio.textHold()", dialog)
            self.assertIn("KantoAudio.beginReceipt(fanfare)", dialog)
            event = (tree / "Source/game/eventState.lua").read_text()
            self.assertIn("KantoAudio.receiptCue(page.label)", event)
            holds = lua(tree / "Source/audio/receiptWait.lua", """
print(KantoReceipt.holdFrames(73))
print(KantoReceipt.holdFrames(121))
""")
            item, key = holds.strip().splitlines()
            self.assertEqual(int(item), gb_frames(73))
            self.assertEqual(int(key), gb_frames(121))
        finally:
            subprocess.run(["rm", "-rf", str(tree)], check=True)

    def test_the_three_notes_apply_together(self):
        tree = apply_notes(["heal", "move", "receipt"])
        try:
            audio = (tree / "Source/game/kantoAudio.lua").read_text()
            self.assertIn("KantoHeal.plan(count)", audio)
            self.assertIn("KantoAttack.cue", audio)
            self.assertIn("beginReceipt", audio)
            self.assertNotIn('playSFX("hit")', audio)
        finally:
            subprocess.run(["rm", "-rf", str(tree)], check=True)


if __name__ == "__main__":
    unittest.main()
