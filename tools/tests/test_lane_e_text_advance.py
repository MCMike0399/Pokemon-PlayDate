"""Healing keeps the event state on top, and that state owns dialog().

Sequence 208 talks to the Fuchsia nurse. After the welcome text, the
event phase is heal-animation and KantoAudio.textAdvance reads
top.dialog. That field is the method, so indexing isActive crashes
the simulator before Surf. The guard is
tools/notes/lane-e-text-advance.patch. This test fails until the
patch is in Source/game/kantoAudio.lua.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "Source/game/kantoAudio.lua"
PATCH = ROOT / "tools/notes/lane-e-text-advance.patch"


class TextAdvanceTests(unittest.TestCase):
    def test_event_dialog_method_is_not_indexed(self):
        source = AUDIO.read_text(encoding="utf-8")
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("type(spoken) == \"table\"", patch)
        body = source.split("local function textAdvance", 1)[1].split("\nlocal function", 1)[0]
        self.assertIn(
            'type(spoken) == "table"',
            body,
            "Do not index EventState:dialog. Apply tools/notes/lane-e-text-advance.patch",
        )
        self.assertNotIn("top.dialog.isActive", body)


if __name__ == "__main__":
    unittest.main()
