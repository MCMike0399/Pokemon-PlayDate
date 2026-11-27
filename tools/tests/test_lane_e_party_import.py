#!/usr/bin/env python3
"""The party list must not call import() after the pdz has loaded.

Playdate allows import() only while a pdx is loading. PartyState:drawPartyList
calls import "game/gbFont" on every paint. Opening the party menu from the
pause reorder after seq1869 (Victory Road, build e899cdde) raises
game/partyState.lua:374: import() called outside of pdz loading.
loadStatusScreen and PauseState:drawTrainer call the same import at runtime.
pauseState.lua already imports game/gbFont at file scope, which loads
TitleIdle before the update loop. The runtime calls have to go, and
partyState.lua has to import at file scope so the list still has the font
when it is loaded on its own.

Source/game/partyState.lua and Source/game/pauseState.lua are shared, so the
fix is tools/notes/lane-e-party-import.patch. This test fails until that
patch is in the shared files.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARTY = ROOT / "Source/game/partyState.lua"
PAUSE = ROOT / "Source/game/pauseState.lua"
PATCH = ROOT / "tools/notes/lane-e-party-import.patch"


def body(source, name, nxt):
    return source.split(f"function {name}", 1)[1].split(f"function {nxt}", 1)[0]


class PartyImportTests(unittest.TestCase):
    def test_party_list_does_not_import_after_load(self):
        party = PARTY.read_text(encoding="utf-8")
        pause = PAUSE.read_text(encoding="utf-8")
        self.assertTrue(PATCH.is_file(), "missing tools/notes/lane-e-party-import.patch")
        # File scope, before any function. A call indented inside draw is too late.
        head = party.split("function PartyState:", 1)[0]
        self.assertIn(
            'import "game/gbFont"',
            head,
            "Apply tools/notes/lane-e-party-import.patch",
        )
        for name, nxt, source in (
            ("PartyState:drawPartyList", "PartyState:draw", party),
            ("PartyState:loadStatusScreen", "PartyState:drawStatus", party),
            ("PauseState:drawTrainer", "PauseState:releaseTrainerScreen", pause),
        ):
            self.assertNotIn(
                'import "game/gbFont"',
                body(source, name, nxt),
                f"{name} calls import() after the pdx has loaded. "
                "Apply tools/notes/lane-e-party-import.patch",
            )


if __name__ == "__main__":
    unittest.main()
