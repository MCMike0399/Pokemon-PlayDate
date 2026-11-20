#!/usr/bin/env python3
"""The evolution animation still paints a cancel hint pokered never shows.

pret/pokered af519899 prints _IsEvolvingText and _StoppedEvolvingText
through the normal text box. EvolveMon cancels on PAD_B inside
Evolution_CheckForCancel and sets no on-screen prompt. This port already
uses the dialog for "What? <NAME> is evolving!" and for the result, and
B already calls cancel() during the animate substate. The extra line is
gfx.drawText("B: Stop evolution", 12, 157).

This test fails until tools/notes/lane-e-evolution-cancel-hint.patch
is applied. That patch deletes only the hint. B and the dialog stay.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED_TEXT = Path("/tmp/pokered/data/text/text_3.asm")
POKERED_EVO = Path("/tmp/pokered/engine/movie/evolution.asm")
STATE = ROOT / "Source/game/evolutionState.lua"
PATCH = ROOT / "tools/notes/lane-e-evolution-cancel-hint.patch"
HINT = 'gfx.drawText("B: Stop evolution",12,157)'


class EvolutionCancelHintTest(unittest.TestCase):
    def test_pokered_cancels_on_b_with_no_hint(self):
        text = POKERED_TEXT.read_text(encoding="utf-8")
        movie = POKERED_EVO.read_text(encoding="utf-8")
        evolving = text.split("_IsEvolvingText::", 1)[1].split("_FellAsleepText::", 1)[0]
        stopped = text.split("_StoppedEvolvingText::", 1)[1].split("_IsEvolvingText::", 1)[0]
        self.assertIn('text "What? @"', evolving)
        self.assertIn('line "is evolving!"', evolving)
        self.assertIn('text "Huh? @"', stopped)
        self.assertIn('line "stopped evolving!"', stopped)
        self.assertNotIn("Stop evolution", text)
        cancel = movie.split("Evolution_CheckForCancel:", 1)[1]
        self.assertIn("and PAD_B", cancel)
        self.assertIn("wForceEvolution", cancel)
        patch = PATCH.read_text(encoding="utf-8")
        removed = [line[1:] for line in patch.splitlines() if line.startswith("-") and not line.startswith("---")]
        added = [line[1:] for line in patch.splitlines() if line.startswith("+") and not line.startswith("+++")]
        self.assertTrue(any(HINT in line for line in removed))
        self.assertFalse(any(HINT in line for line in added))
        self.assertIn("buttonJustPressed(playdate.kButtonB)", STATE.read_text(encoding="utf-8"))

    def test_evolution_screen_has_no_cancel_hint(self):
        source = STATE.read_text(encoding="utf-8")
        draw = source.split("function EvolutionState:draw()", 1)[1].split("\nfunction ", 1)[0]
        self.assertNotIn(
            HINT,
            draw,
            "pokered shows no B hint. Apply tools/notes/lane-e-evolution-cancel-hint.patch",
        )
        self.assertNotIn("Stop evolution", draw)
        self.assertIn("self.dialog:draw()", draw)
        animate = source.split('self.sub:register("animate"', 1)[1].split("self.sub:register(", 1)[0]
        self.assertIn("buttonJustPressed(playdate.kButtonB) then self:cancel()", animate)


if __name__ == "__main__":
    unittest.main()
