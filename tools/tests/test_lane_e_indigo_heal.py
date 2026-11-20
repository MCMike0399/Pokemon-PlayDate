#!/usr/bin/env python3
"""The Indigo lobby nurse uses the same machine tiles as a Pokémon Center.

HealingComposition.layout accepts only 14x8 POKECENTER maps, plus Viridian
and Pewter. The lobby is a 16x12 MART map, so the real nurse heal crashes
with "explicit healing-machine map required". The machine pair is MART
cell 28-3a-28-4a / 3b-28-4b-28 at cell (5, 4), the Center pair's offset
from a nurse two cells right and one down.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class IndigoHealTests(unittest.TestCase):
    def test_lobby_machine_is_explicit(self):
        source = (ROOT / "Source/game/healingComposition.lua").read_text(encoding="utf-8")
        layout = source.split("function HealingComposition.layout(zone)", 1)[1].split(
            "function HealingComposition.draw", 1)[0]
        lobby = layout.split('zone.stableID == "pokered:INDIGO_PLATEAU_LOBBY"', 1)
        self.assertEqual(len(lobby), 2, "lobby heal still requires a 14x8 POKECENTER map")
        branch = lobby[1].split("acceptedMachines", 1)[0]
        self.assertIn("5 * TILE_SIZE + 24", branch)
        self.assertIn("4 * TILE_SIZE + 8", branch)
        self.assertLess(layout.index("INDIGO_PLATEAU_LOBBY"), layout.index('tileset.constant == "POKECENTER"'))
        self.assertIn("definition.dimensions.cells[1] == 14", layout)
