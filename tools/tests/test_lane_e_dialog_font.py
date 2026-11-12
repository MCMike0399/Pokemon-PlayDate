"""Dialog boxes use pokered's tile font. Lane E has not applied this yet.

After applying tools/notes/lane-e-dialog-font.patch, run
`python3 tools/visual/compare.py <reviewed-baseline> <candidate> --protected-preservation`
and update baselines only for dialog-box pixels. Do not regenerate other catalog art.
The overworld, battle messages, and Oak's speech share the same glyphs.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-dialog-font.patch"


class LaneEDialogFontTests(unittest.TestCase):
    def test_dialog_font_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        patch = PATCH.read_text()
        self.assertIn("--protected-preservation", patch)
        self.assertIn("dialog-box pixels", patch)

    @unittest.expectedFailure
    def test_dialog_box_uses_the_tile_font(self):
        source = (ROOT / "Source/ui/dialog.lua").read_text()
        self.assertIn("GbFont.drawBox", source)
        self.assertIn("▼", source)
        self.assertIn("textBox(0, 12, 18, 4)", source)
        event = (ROOT / "Source/game/eventText.lua").read_text()
        self.assertIn('return line1 .. "\\n" .. line2', event)
        self.assertNotIn("reflow to Playdate words", event)


if __name__ == "__main__":
    unittest.main()
