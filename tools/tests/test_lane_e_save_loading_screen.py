#!/usr/bin/env python3
"""Pause Save must not replace the LCD with the boot trace.

pret/pokered af519899 prints the save inside the text box. GameSaves:save
calls GameBootstrap.withLoading("Save") with no draw callback, so
GameBootstrap.showLoading clears the LCD and draws "Pokemon Blue",
"Loading...", BootTrace.phase ("Save.begin"), and "Phase N".

badge-boulder.mp4 shows that screen (Save.begin, Phase 975) between the
pause menu and "RED saved the game!". The patch keeps the current frame.
Source/game/saves.lua is shared, so the fix is
tools/notes/lane-e-save-loading-screen.patch. This test fails until that
patch is in the shared file.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Source/game/saves.lua"
PATCH = ROOT / "tools/notes/lane-e-save-loading-screen.patch"


def save_function(source, name, nxt):
    body = source.split(f"function {name}", 1)[1]
    return body.split(f"function {nxt}", 1)[0]


class SaveLoadingScreenTest(unittest.TestCase):
    def test_save_does_not_paint_the_boot_trace(self):
        source = SOURCE.read_text(encoding="utf-8")
        added = " ".join(
            word
            for line in PATCH.read_text(encoding="utf-8").splitlines()
            if line.startswith("+") and not line.startswith("+++")
            for word in line[1:].split()
        )
        self.assertIn("return true", added)
        for name, nxt in (
            ("GameSaves:save", "GameSaves:saveFromHall"),
            ("GameSaves:saveFromHall", "GameSaves:_publishPayload"),
        ):
            body = save_function(source, name, nxt)
            self.assertIn(
                "return true",
                body,
                f"{name} must pass a draw callback that keeps the current frame. "
                "Apply tools/notes/lane-e-save-loading-screen.patch",
            )
            self.assertNotIn("showLoading", body)


if __name__ == "__main__":
    unittest.main()
