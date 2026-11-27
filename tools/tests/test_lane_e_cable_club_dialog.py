#!/usr/bin/env python3
"""Pokémon Center link receptionists swallow A.

scripts/ViridianPokecenter.asm (af519899) ViridianPokecenterLinkReceptionistText
is script_cable_club_receptionist. The same macro is on the other center
receptionists. The approved policy keeps the welcome line and the save line,
and leaves TRADE_CENTER and COLOSSEUM closed. Indigo Plateau lobby object 5
already has those two lines and no warp. The other eleven are not registered,
so KantoWorld.tryInteract blocks them as unimplemented-source-event.

The handoff is tools/notes/lane-e-cable-club-dialog.patch. It is not applied
here. This test fails on the current tree. MallocPoolSize stays 16645684.
No skip.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORY = ROOT / "Source/game/endgameStory.lua"

RECEPTIONISTS = (
    "pokered:VIRIDIAN_POKECENTER:objects:4",
    "pokered:PEWTER_POKECENTER:objects:4",
    "pokered:CERULEAN_POKECENTER:objects:4",
    "pokered:VERMILION_POKECENTER:objects:4",
    "pokered:LAVENDER_POKECENTER:objects:4",
    "pokered:CELADON_POKECENTER:objects:4",
    "pokered:FUCHSIA_POKECENTER:objects:4",
    "pokered:SAFFRON_POKECENTER:objects:4",
    "pokered:CINNABAR_POKECENTER:objects:4",
    "pokered:ROCK_TUNNEL_POKECENTER:objects:4",
    "pokered:MT_MOON_POKECENTER:objects:6",
)


class CableClubDialogTest(unittest.TestCase):
    def test_center_receptionists_say_the_two_lines_and_do_not_warp(self):
        text = STORY.read_text()
        start = text.find("local cableClub")
        self.assertGreater(start, 0, "center link receptionists are not registered")
        block = text[start:text.find("pokered:INDIGO_PLATEAU_LOBBY:objects:5", start)]
        self.assertIn("_CableClubNPCWelcomeText", block)
        self.assertIn("_CableClubNPCPleaseApplyHereHaveToSaveText", block)
        self.assertNotIn("warp", block)
        self.assertNotIn("TRADE_CENTER", block)
        self.assertNotIn("COLOSSEUM", block)
        for receptionist in RECEPTIONISTS:
            self.assertIn(receptionist, block)


if __name__ == "__main__":
    unittest.main()
