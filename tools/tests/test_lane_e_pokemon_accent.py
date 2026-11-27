"""The # macro expands to POKé, so #MON is POKéMON.

constants/charmap.asm:16
    charmap "#", $54 ; "POKé"

The live expander still writes POKE. The patch is
tools/notes/lane-e-pokemon-accent.patch.
"""

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-pokemon-accent.patch"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)


class PokemonAccentTests(unittest.TestCase):
    def test_patch_applies_and_cites_the_charmap(self):
        text = PATCH.read_text()
        self.assertIn("constants/charmap.asm:16", text)
        self.assertIn('result[#result + 1] = "POKé"', text)
        self.assertNotIn("MallocPoolSize", text)
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        line = (Path(reference) / "constants/charmap.asm").read_text().splitlines()[15]
        self.assertIn('charmap "#"', line)
        self.assertIn('"POKé"', line)
        checked = git("apply", "--check", str(PATCH))
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_hash_macro_expands_to_poke_with_acute_e(self):
        source = (ROOT / "Source/game/sourceText.lua").read_text()
        expand = source.split("function SourceText.expand", 1)[1]
        self.assertIn('result[#result + 1] = "POKé"', expand)
        self.assertNotIn('= "POKE"', expand)


if __name__ == "__main__":
    unittest.main()
