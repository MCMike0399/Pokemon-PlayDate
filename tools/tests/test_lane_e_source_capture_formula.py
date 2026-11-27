#!/usr/bin/env python3
"""Source-map balls use pokered ItemUseBall.

pret/pokered af519899 engine/items/item_effects.asm ItemUseBall redraws
Rand1 into a ball window (Poke 255, Great 200, Ultra/Safari 150), subtracts
12 for burn/paralysis/poison or 25 for freeze/sleep, fails when that
remainder is above the catch rate, then compares a second roll with
min(((MaxHP * 255) / BallFactor) / max(HP/4, 1), 255). BallFactor is 8 for
a Great Ball and 12 otherwise. A Master Ball skips the rolls.

GameSession:attemptSourceCapture still calls Capture.attempt. That is the
approved Gen V Q12 hybrid (Blue catch byte, Gen V HP/status/shakes). A
Mewtwo Ultra Ball at 229/229 paralyzed, catch rate 3, produced
modifiedRate4096 12288 and shakeThreshold 21583, which is that hybrid, and
three shakes under 21583 caught it. ItemUseBall would not. The handoff is
tools/notes/lane-e-source-capture-formula.patch. It is not applied here.
Ordinary Capture.attempt stays for non-source wilds. MallocPoolSize stays
16645684. No skip.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def function_body(text, name):
    start = text.split("function " + name, 1)[1]
    return start.split("\nfunction ", 1)[0]


class SourceCaptureFormulaTests(unittest.TestCase):
    def test_source_throws_use_item_use_ball(self):
        session = (ROOT / "Source/domain/gameSession.lua").read_text(encoding="utf-8")
        capture = (ROOT / "Source/domain/capture.lua").read_text(encoding="utf-8")
        body = function_body(session, "GameSession:attemptSourceCapture")
        self.assertIn(
            "Capture.itemUseBall(context, ballID, caughtCount, stream)",
            body,
        )
        item = function_body(capture, "Capture.itemUseBall(enemyContext, ballId, caughtCount, rng)")
        self.assertIn("pokered-item-use-ball", item)
        self.assertIn("ballId==\"pokeBall\" and 255", item)
        self.assertIn("ballId==\"greatBall\" and 200 or 150", item)
        self.assertIn("status==\"sleep\" or status==\"freeze\"", item)
        self.assertIn("ballId==\"greatBall\" and 8 or 12", item)
        self.assertIn("rand2<=result.shakeThreshold", item)


if __name__ == "__main__":
    unittest.main()
