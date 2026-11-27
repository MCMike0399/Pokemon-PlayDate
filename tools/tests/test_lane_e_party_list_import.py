#!/usr/bin/env python3
"""The party list must not import the font while the menu is drawing.

Sequence 472 stood on Route 24 (4, 31) facing the west channel and opened
the party menu to Surf. PartyState:drawPartyList called import "game/gbFont"
and the runtime aborted with import() called outside of pdz loading.
main.lua imports partyState while the pdx is loading, so the font import
belongs at the top of that file. The status page keeps its own reload.
tools/notes/lane-e-party-list-import.patch. This test fails until that
patch is applied. MallocPoolSize stays 16645684.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PartyListImportTests(unittest.TestCase):
    def test_party_list_imports_the_font_while_the_pdx_loads(self):
        source = (ROOT / "Source/game/partyState.lua").read_text(encoding="utf-8")
        head = source.split("function PartyState", 1)[0]
        draw = source.split("function PartyState:drawPartyList", 1)[1].split(
            "function PartyState", 1)[0]
        self.assertIn('import "game/gbFont"', head)
        self.assertNotIn("import ", draw)


if __name__ == "__main__":
    unittest.main()
