#!/usr/bin/env python3
"""A on the Viridian nurse must not index EventState:dialog.

EventState:dialog is the method that pushes the welcome pages. Pokered's
Pokémon Center nurse (script_pokecenter_nurse) shows that text, then YES/NO.
The heal leaves the event on top for the frame A is still just-pressed, both
when the talk starts and when the text box closes. textAdvance used to read
top.dialog.isActive. The field is a function, so the runtime died at
kantoAudio.lua and the party was never healed. A real Dialog table still
plays the text cue.
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
        self.assertIn('self.machine:push("dialog",lines,self:guard(callback))', text)

    def test_text_advance_ignores_a_dialog_method(self):
        advance = AUDIO.read_text().split("local function textAdvance(top, menu)", 1)[1]
        advance = advance.split("local function noteCries", 1)[0]
        self.assertIn('top.name == "dialog"', advance)
        self.assertIn('type(dialog) == "table" and dialog.isActive', advance)
        self.assertNotIn("if top.dialog and top.dialog.isActive then", advance)
        self.assertIn("scene.messageDialog and scene.messageDialog.isActive", advance)

    def test_the_handoff_patch_is_the_landed_guard(self):
        check = subprocess.run(
            ["git", "apply", "--reverse", "--check", str(PATCH)], cwd=ROOT,
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        note = PATCH.read_text()
        self.assertIn('type(dialog) == "table" and dialog.isActive', note)


if __name__ == "__main__":
    unittest.main()
