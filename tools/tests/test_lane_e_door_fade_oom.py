#!/usr/bin/env python3
"""The gym door fade allocates a bitmap the 16 MiB pool cannot spare.

Session f26ae99d459f46b58f4697f49ef04702 beat Koga, then stopped at
Fuchsia Gym (6, 17) with:

    game/overworldState.lua:346: image:drawFaded() failed: out of memory

Lua was 11720 KiB, under the door checkpoint's 12 MiB collect. The
working-image copy had already succeeded. A separate SDK 3.1.2 probe
filled the 16645684-byte pool with 1352 full-screen images. Dropping one
let image.new succeed and the next image.new fail, and drawFaded still
raised that same error. setStencilPattern of the sampled Bayer rows drew
with no error. On a mixed 32x32 source those rows matched drawFaded at
alpha 0.875 and 0.5 with zero mismatches:

    0.875 -> 0xFF,0xDD,0xFF,0x77,0xFF,0xDD,0xFF,0x77
    0.5   -> 0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55

The ffmpeg clip grab is outside the Playdate pool. This test fails until
tools/notes/lane-e-door-fade-oom.patch is applied. That patch does not
change MallocPoolSize or the 12 fade frames.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / "Source/game/overworldState.lua"
PATCH = ROOT / "tools/notes/lane-e-door-fade-oom.patch"
CALL = "image:drawFaded(0, 0, alpha, gfx.image.kDitherTypeBayer8x8)"
PATTERN_7_8 = "{0xFF, 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 0x77}"
PATTERN_1_2 = "{0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55}"


def draw_door_fade(source):
    return source.split("local function drawDoorFade(image, frame)", 1)[1].split("\nfunction ", 1)[0]


class DoorFadeOomTest(unittest.TestCase):
    def test_patch_uses_the_sampled_bayer_rows(self):
        patch = PATCH.read_text(encoding="utf-8")
        removed = [line[1:] for line in patch.splitlines() if line.startswith("-") and not line.startswith("---")]
        added = [line[1:] for line in patch.splitlines() if line.startswith("+") and not line.startswith("+++")]
        self.assertTrue(any(CALL in line for line in removed))
        self.assertFalse(any(CALL in line for line in added))
        added_text = "\n".join(added)
        self.assertIn(PATTERN_7_8, added_text)
        self.assertIn(PATTERN_1_2, added_text)
        self.assertIn("gfx.setStencilPattern(t < 1 / 3 and DOOR_FADE_7_8 or DOOR_FADE_1_2, 0, 0)", added_text)
        self.assertIn("image:draw(0, 0)", added_text)
        self.assertNotIn("MallocPoolSize", patch)
        self.assertFalse(any("DOOR_FADE_FRAMES" in line for line in removed))

    def test_door_fade_does_not_allocate_drawFaded(self):
        body = draw_door_fade(STATE.read_text(encoding="utf-8"))
        self.assertNotIn(
            "drawFaded",
            body,
            "drawFaded allocates a temporary the door copy just fit without. "
            "Apply tools/notes/lane-e-door-fade-oom.patch",
        )
        self.assertIn("gfx.setStencilPattern(t < 1 / 3 and DOOR_FADE_7_8 or DOOR_FADE_1_2, 0, 0)", body)
        self.assertIn(PATTERN_7_8, STATE.read_text(encoding="utf-8"))
        self.assertIn("gfx.clear(gfx.kColorBlack)", body)
        self.assertIn("image:draw(0, 0)", body)


if __name__ == "__main__":
    unittest.main()
