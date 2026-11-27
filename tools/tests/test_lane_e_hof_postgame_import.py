#!/usr/bin/env python3
"""The postgame and fossil chunks have to be literal imports on main.

pokered data/maps/special_warps.asm sends a Hall continue to Pallet.
pokered scripts/CinnabarLabFossilRoom.asm is the fossil handover.
pdc 3.1.2 records a variable import and does not run the chunk, so
PostgameStory never exists. This fails on origin/main and passes once
tools/notes/lane-e-hof-postgame-import.patch is applied.

Lane E 79fbcba5 already file.runs game/postgameStory from loadHallContinue.
Do not apply this patch on that tip. A boot import OOM'd the Hall continue.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LATE = ROOT / "Source/game/lateKantoStory.lua"
FOSSIL = ROOT / "Source/game/fossilRevival.lua"


class PostgameImportTest(unittest.TestCase):
    def test_postgame_and_fossil_chunks_are_literal_imports(self):
        late = LATE.read_text(encoding="utf-8")
        fossil = FOSSIL.read_text(encoding="utf-8")
        self.assertIn('import "game/postgameStory"', late)
        self.assertIn('import "game/fossilRevival"', late)
        self.assertNotIn('importer "game/postgameStory"', late)
        self.assertNotIn('importer "game/fossilRevival"', fossil)
        self.assertNotIn('import "game/lateKantoStory"', fossil)


if __name__ == "__main__":
    unittest.main()
