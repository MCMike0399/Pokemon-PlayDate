"""Wild and trainer moves come from pret/pokered WriteMonMoves.

The B2W2 table stays in the species records for saves that already
queued one of its choices. New moves use PokeredLearnsets.
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
        self.assertIn("return PokeredLearnsets.movesAtLevel(species, level)", player)
        self.assertIn("return PokeredLearnsets.trainerMoves(species, level, class, index, starter)", trainer)
        events = (ROOT / "Source/game/trainerEvents.lua").read_text(encoding="utf-8")
        self.assertIn(
            "Pokemon.trainerMovesFor(mon.species, mon.level, value.definition.class_source, index, intro and intro.starter)",
            events)
        self.assertIn("created:usePartyMoves(scripted)", events)
        completed = subprocess.run(
            ["lua5.4", str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("trainer-fifo-held", completed.stdout)


if __name__ == "__main__":
    unittest.main()
