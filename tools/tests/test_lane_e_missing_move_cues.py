"""Every battle move cue must resolve to a generated score.

A faint with Bite asks for move_bite. On main b7cdc96e that score file does
not exist, and KantoSynth.sfx asserts "unknown Kanto SFX" before the cry, so
the battle aborts. This test is red on that tree. The scores in
tools/notes/lane-e-missing-move-cues.patch are the tools/audio/scores.py
output for pokered af519899; they are not applied on this branch's commit of
the patch itself when the tree is b7cdc96e.

No skip and no expectedFailure.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _move_keys():
    text = (ROOT / "Source/battle/moves.lua").read_text(encoding="utf-8")
    return re.findall(r"\n    ([A-Za-z][A-Za-z0-9]*) = function\(\)", text)


def _move_cues():
    text = (ROOT / "Source/audio/moveSfxData.lua").read_text(encoding="utf-8")
    return dict(re.findall(r'\n    ([A-Za-z][A-Za-z0-9]*) = "([^"]+)"', text))


def _cue_scores():
    text = (ROOT / "Source/audio/events.lua").read_text(encoding="utf-8")
    return dict(re.findall(r'\["([^"]+)"\] = \{score="([^"]+)"', text))


def requestable_scores():
    """Score names the battle can ask the synth to play.

    A move is requestable when it is in the battle move table and the cue
    lookup returns a score. Field moves that are only in the lookup are
    included too, because playSFX receives that score name. Literal battle
    cues in the observer resolve through the cue table.
    """
    keys = set(_move_keys())
    mapping = _move_cues()
    # Score names, not cue keys. "cut" is both a field SFX and the move row
    # move_cut; a dict keyed by the cue name would keep only one of them.
    scores = set()
    for key, score in mapping.items():
        scores.add(score)
        if key not in keys and key not in ("cut", "flash", "fly", "strength", "surf"):
            raise AssertionError(f"cue lookup {key} is not a battle move")
    audio = (ROOT / "Source/game/kantoAudio.lua").read_text(encoding="utf-8")
    cue_scores = _cue_scores()
    for literal in re.findall(r'play(?:SFX|Cue|Jingle)\(\s*"([^"]+)"', audio):
        scores.add(cue_scores.get(literal, literal))
    # engine/battle/core.asm victory beds, via KantoEvents.victoryScore.
    scores.update(("defeated_wild", "defeated_trainer", "defeated_gym"))
    return scores


def _score_file(name):
    path = ROOT / "Source/audio/score" / f"{name}.lua"
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8")
    if f"KantoScores.{name}" not in text and f'KantoScores["{name}"]' not in text:
        return None
    for relative in re.findall(r'bin="(audio/score/[^"]+\.bin)"', text):
        if not (ROOT / "Source" / relative).is_file():
            return None
    return path


class MissingMoveCueTests(unittest.TestCase):
    def test_every_requestable_cue_resolves_to_a_score(self):
        requested = requestable_scores()
        missing = sorted(score for score in requested if _score_file(score) is None)
        self.assertEqual(
            missing,
            [],
            "requestable cues with no score file:\n" + "\n".join(missing),
        )

    def test_faint_plays_bite(self):
        # GetMoveSound's BITE row. The faint path plays that score, then the cry.
        self.assertEqual(_move_cues()["bite"], "move_bite")
        self.assertIsNotNone(
            _score_file("move_bite"),
            "a faint requested move_bite and aborted because the score file is missing",
        )
        audio = (ROOT / "Source/game/kantoAudio.lua").read_text(encoding="utf-8")
        faint = audio.split("if faint then", 1)[1].split("elseif hit then", 1)[0]
        self.assertIn("moveCue", faint)
        self.assertTrue(
            "playSFX(moveCue)" in faint or "playSequence({moveCue" in faint,
            "the faint path must play the move cue before the cry or the thud",
        )
        engine = (ROOT / "Source/audio/engine.lua").read_text(encoding="utf-8")
        sfx = engine.split("function KantoSynth.sfx(name)", 1)[1].split(
            "function KantoSynth.cry", 1
        )[0]
        self.assertNotIn('assert(priorities[name], "unknown Kanto SFX")', sfx)
        self.assertIn('name:sub(1, 5) == "move_"', engine)
        self.assertIn("faint_fall_agility", engine)
        advance = engine.split("local function advance", 1)[1].split("local function choose", 1)[0]
        self.assertNotIn("score.notes[", advance)
        self.assertIn("noteAt(score", advance)
        packed = (ROOT / "Source/audio/packed.lua").read_text(encoding="utf-8")
        self.assertIn("function KantoPacked.noteAt", packed)
        self.assertIn("function KantoPacked.bind", packed)


if __name__ == "__main__":
    unittest.main()
