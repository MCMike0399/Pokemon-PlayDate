#!/usr/bin/env python3
"""Wild, gift, starter, and level-up learning still read the B2W2 table.

pret/pokered af519899 is the learnset source. Battle rules stay Gen V.
Expected rows come from tools/generate_pokered_learnsets.py.
"""

import importlib.util
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_pokered_learnset_host.lua"
REFERENCE = Path(os.environ["POKERED_REFERENCE_DIR"])


def generator():
    spec = importlib.util.spec_from_file_location(
        "pokered_learnsets", ROOT / "tools/generate_pokered_learnsets.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required")


class PokeredLearnsetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.environ.get("POKERED_REFERENCE_DIR"):
            raise RuntimeError("POKERED_REFERENCE_DIR is required")
        if not REFERENCE.is_dir():
            raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
        cls.gen = generator()
        cls.data = cls.gen.load(REFERENCE, ROOT / "Source/battle/moves.lua")
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.lines = {}
        for line in completed.stdout.splitlines():
            if not line.startswith(("initial ", "constructed ", "entries ", "level ")):
                continue
            kind, species, level, payload = (line.split(" ", 3) + [""])[:4]
            cls.lines[(kind, species, level)] = payload

    def expected_initial(self, species, level):
        return ",".join(self.gen.moves_at_level(self.data, species, level))

    def test_wild_gift_and_starter_use_pokered_level_moves(self):
        # Charmander 15 is the starter line once Leer is due. Staryu 18 is a
        # wild shape of the same initialMovesFor path Pokemon() uses for gifts.
        self.assertEqual(self.lines[("initial", "charmander", "15")], self.expected_initial("charmander", 15))
        self.assertEqual(self.lines[("constructed", "charmander", "15")], self.expected_initial("charmander", 15))
        self.assertEqual(self.lines[("initial", "staryu", "18")], self.expected_initial("staryu", 18))

    def test_level_up_offers_the_pokered_move_at_that_level(self):
        entries = self.gen.entries_between(self.data, "charmander", 15, 15)
        rendered = ",".join("%s@%d#%d" % (row["move"], row["level"], row["id"]) for row in entries)
        self.assertEqual(self.lines[("entries", "charmander", "15")], rendered)
        self.assertEqual(self.lines[("level", "charmander", "15")], "leer@15")
        self.assertEqual(self.lines[("level", "staryu", "17")], "waterGun@17")
        daycare = (ROOT / "Source/game/daycare.lua").read_text(encoding="utf-8")
        evolution = (ROOT / "Source/domain/evolution.lua").read_text(encoding="utf-8")
        self.assertIn("Pokemon.learnsetEntriesFor(", daycare)
        self.assertIn("Pokemon.learnsetEntriesFor(", evolution)


if __name__ == "__main__":
    unittest.main()
