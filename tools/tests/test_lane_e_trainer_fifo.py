"""Trainer parties must not send a move id past pokered NUM_ATTACKS.

pret/pokered af519899 data/moves/moves.asm ends at STRUGGLE, const $a5
(165). Bruno's Hitmonlee is the known case: the B2W2 FIFO puts Wide Guard
and other later ids in the four slots, and the party row replaces them.
Every other trainer send-out uses the same learnset. Player encounters
still use initialMovesFor, which only skips Wide Guard.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_e_trainer_fifo_host.lua"


class TrainerFifoTests(unittest.TestCase):
    def test_trainer_sendout_drops_ids_above_165(self):
        pokemon = (ROOT / "Source/data/pokemon.lua").read_text(encoding="utf-8")
        trainer = pokemon.split("function Pokemon.trainerMovesFor", 1)[1].split(
            "\nfunction ", 1)[0]
        player = pokemon.split("function Pokemon.initialMovesFor", 1)[1].split(
            "\nfunction ", 1)[0]
        self.assertIn("entry.id <= POKERED_NUM_ATTACKS", trainer)
        self.assertIn("POKERED_NUM_ATTACKS <const> = 165", pokemon)
        self.assertNotIn("entry.id <= POKERED_NUM_ATTACKS", player)
        self.assertIn('entry.move ~= "wideGuard"', player)
        events = (ROOT / "Source/game/trainerEvents.lua").read_text(encoding="utf-8")
        self.assertIn(
            "created:usePartyMoves(Pokemon.trainerMovesFor(mon.species, mon.level))",
            events)
        self.assertIn("created:usePartyMoves(scripted)", events)
        completed = subprocess.run(
            ["lua5.4", str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("trainer-fifo-held", completed.stdout)


if __name__ == "__main__":
    unittest.main()
