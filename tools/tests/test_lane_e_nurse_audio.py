#!/usr/bin/env python3
"""A on the Viridian nurse crashes before the YES menu.

EventState:dialog is the method that pushes the welcome pages. The
pokecenter heal leaves that event on top for the frame after A closes
the text. textAdvance then reads top.dialog.isActive. The field is a
function, so the runtime errors at kantoAudio.lua and the party is
never healed. Dialog states still store a Dialog table and should keep
the text cue.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "Source/game/kantoAudio.lua"
EVENTS = ROOT / "Source/game/eventState.lua"
PATCH = ROOT / "tools/notes/lane-e-nurse-audio.patch"


class NurseAudioTests(unittest.TestCase):
    def test_the_nurse_event_exposes_dialog_as_a_method(self):
        text = EVENTS.read_text()
        self.assertIn("function EventState:dialog(pages,callback,receipt)", text)
        self.assertIn("function EventState:heal(step)", text)
        self.assertIn('self.menu:show({"YES","NO"},selected', text)

    def test_live_text_advance_indexes_the_dialog_field(self):
        advance = AUDIO.read_text().split("local function textAdvance(top, menu)", 1)[1]
        advance = advance.split("local function noteCries", 1)[0]
        self.assertIn("if top.dialog and top.dialog.isActive then", advance)
        self.assertNotIn('type(dialog) == "table"', advance)

    @unittest.expectedFailure
    def test_text_advance_ignores_a_dialog_method(self):
        advance = AUDIO.read_text().split("local function textAdvance(top, menu)", 1)[1]
        advance = advance.split("local function noteCries", 1)[0]
        self.assertIn('type(dialog) == "table" and dialog.isActive', advance)
        self.assertNotIn("if top.dialog and top.dialog.isActive then", advance)

    def test_patch_guards_the_dialog_field(self):
        check = subprocess.run(
            ["git", "apply", "--check", str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        output = Path("/tmp/lane-e-nurse-audio.lua")
        applied = subprocess.run(
            ["patch", "-o", str(output), str(AUDIO), str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        advance = output.read_text().split("local function textAdvance(top, menu)", 1)[1]
        advance = advance.split("local function noteCries", 1)[0]
        self.assertIn('type(dialog) == "table" and dialog.isActive', advance)
        self.assertNotIn("if top.dialog and top.dialog.isActive then", advance)


if __name__ == "__main__":
    unittest.main()
