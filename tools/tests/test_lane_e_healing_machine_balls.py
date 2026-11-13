#!/usr/bin/env python3
"""Healing-machine Poké Balls are drawn, then disappear into the cabinet.

pret/pokered af519899 AnimateHealingMachine sets rOBP1 to $e0 before it
copies OAM. Sprite color 0 stays transparent, color 1 becomes white,
color 2 stays dark, and color 3 stays black. The party loop then copies
one ball OAM per party member, plays SFX_HEALING_MACHINE, and waits 30
frames. The jingle flashes that palette. It does not hide the sprites.

This port places the same one-ball-at-a-time OAM in HealingComposition.
EventArt.healing renders the source grid's "1" through Shade.LIGHT. On
the black cabinet that dither is a few specks, so the Celadon heal clip
shows the monitor flash and no ball. SpriteFactory already paints "w"
as solid white for OBJ color 1. The heal tiles are only shown under
$e0, so "1" has to become "w" before makeSprite.

The source 2bpp grid in event-art.json stays the color indices. Ball
positions stay {{48,22},{64,22},{48,32},{64,32},{48,42},{64,42}}. This
test fails until tools/notes/lane-e-healing-machine-balls.patch is applied.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path("/tmp/pokered/engine/overworld/healing_machine.asm")
ART = ROOT / "Source/game/eventArt.lua"
CONTRACT = ROOT / "Source/dev/healingCompositionContracts.lua"
GRID = ROOT / "Source/data/event-art.json"
PATCH = ROOT / "tools/notes/lane-e-healing-machine-balls.patch"
REWRITE = 'rows[y]=cell:gsub("1","w")..string.rep(".",8)'
BALL_WHITE = "eq(ball:sample(6,10),gfx.kColorWhite)"
MONITOR_WHITE = "eq(monitor:sample(2,4),gfx.kColorWhite)"


class HealingMachineBallsTest(unittest.TestCase):
    def test_pokered_places_one_white_ball_per_party_mon(self):
        asm = POKERED.read_text(encoding="utf-8")
        body = asm.split("AnimateHealingMachine:", 1)[1].split("PokeCenterFlashingMonitorAndHealBall:", 1)[0]
        self.assertIn("ld a, $e0", body)
        self.assertIn("ldh [rOBP1], a", body)
        party = body.split(".partyLoop", 1)[1].split("ld a, [wAudioROMBank]", 1)[0]
        self.assertIn("call CopyHealingMachineOAM", party)
        self.assertIn("ld a, SFX_HEALING_MACHINE", party)
        self.assertIn("ld c, 30", party)
        self.assertIn("call DelayFrames", party)
        self.assertIn("call FlashSprite8Times", body)
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn(REWRITE, patch)
        self.assertIn(BALL_WHITE, patch)
        self.assertIn(MONITOR_WHITE, patch)
        self.assertNotIn("diff --git a/Source/data/event-art.json", patch)
        grid = GRID.read_text(encoding="utf-8")
        self.assertIn('"..#1221#"', grid)
        self.assertIn('".111111."', grid)

    def test_heal_ball_color_one_is_solid_white(self):
        art = ART.read_text(encoding="utf-8")
        small = art.split("local function small(first)", 1)[1].split("function EventArt.healing()", 1)[0]
        self.assertIn(
            REWRITE,
            small,
            "OBJ color 1 is white under rOBP1=$e0. Apply "
            "tools/notes/lane-e-healing-machine-balls.patch",
        )
        contract = CONTRACT.read_text(encoding="utf-8")
        self.assertIn(BALL_WHITE, contract)
        self.assertIn(MONITOR_WHITE, contract)
        self.assertIn("eq(layout.balls[i].x,p[1])", contract)


if __name__ == "__main__":
    unittest.main()
