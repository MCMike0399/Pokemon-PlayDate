#!/usr/bin/env python3
"""A move row with no score file must not abort the battle.

KantoMoveSfx maps bite to move_bite. Source/audio/score has no move_bite
file, and KantoSynth.sfx used to assert "unknown Kanto SFX" the moment the
player's Pokémon fainted. The cue returns false, and the faint cry plays
without asking scoreTicks for the missing score.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MoveSfxCrashTests(unittest.TestCase):
    def test_unknown_move_cue_does_not_assert(self):
        engine = (ROOT / "Source/audio/engine.lua").read_text(encoding="utf-8")
        sfx = engine.split("function KantoSynth.sfx(name)", 1)[1].split(
            "function KantoSynth.cry", 1)[0]
        self.assertNotIn('assert(priorities[name], "unknown Kanto SFX")', sfx)
        self.assertIn("if not priority then", sfx)
        self.assertIn("return false", sfx)

        audio = (ROOT / "Source/game/kantoAudio.lua").read_text(encoding="utf-8")
        faint = audio.split("local moveCue = moveKey and moveScore(moveKey)", 1)[1].split(
            "else", 1)[0]
        self.assertIn("local played = moveCue and KantoAudio.playSFX(moveCue)", faint)
        self.assertIn("if played then", faint)
        self.assertLess(faint.index("if played then"), faint.index("sfxFrames(moveCue)"))

    def test_pause_menu_can_release_the_trainer_card(self):
        pause = (ROOT / "Source/game/pauseState.lua").read_text(encoding="utf-8")
        self.assertIn("function PauseState:releaseTrainerScreen()", pause)
        self.assertIn("function PauseState:drawTrainer()", pause)
        draw = pause.split("function PauseState:draw()", 1)[1].split(
            "function PauseState:resume()", 1)[0]
        self.assertLess(draw.index("self:releaseTrainerScreen()"), draw.index("function PauseState:releaseTrainerScreen()"))


if __name__ == "__main__":
    unittest.main()
