#!/usr/bin/env python3
"""Trainer send-out must follow pokered WriteMonMoves plus special moves.

pret/pokered af519899. Expected moves are parsed from that tree by
tools/generate_pokered_learnsets.py. The lists are not copied into this test.
"""

import importlib.util
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_trainer_moves_host.lua"
PATCH = ROOT / "tools/notes/lane-e-trainer-movesets.patch"
REFERENCE = Path(os.environ["POKERED_REFERENCE_DIR"])
CASES = (
    ("Misty", "OPP_MISTY"),
    ("Brock", "OPP_BROCK"),
    ("LtSurge", "OPP_LT_SURGE"),
    ("Lance", "OPP_LANCE"),
    ("Youngster", "OPP_YOUNGSTER"),
)


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


class TrainerMovesetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.environ.get("POKERED_REFERENCE_DIR"):
            raise RuntimeError("POKERED_REFERENCE_DIR is required")
        if not REFERENCE.is_dir():
            raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
        cls.gen = generator()
        cls.data = cls.gen.load(REFERENCE, ROOT / "Source/battle/moves.lua")
        request = []
        for label, class_name in CASES:
            for index, mon in enumerate(cls.data["parties"][label][0], start=1):
                request.append("|".join((
                    class_name, str(index), mon["species"], str(mon["level"]))))
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT), ";".join(request)],
            check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.actual = {}
        for line in completed.stdout.splitlines():
            if not line.startswith("moves "):
                continue
            _, class_name, index, species, level, moves = line.split(" ", 5)
            cls.actual[(class_name, int(index), species, int(level))] = moves.split(",")

    def test_patch_learnsets_match_the_generator(self):
        text = PATCH.read_text(encoding="utf-8")
        body = text.split("+++ b/Source/data/pokeredLearnsets.lua\n", 1)[1]
        lines = []
        for line in body.splitlines():
            if line.startswith("diff --git "):
                break
            if line.startswith("@@"):
                continue
            self.assertTrue(line.startswith("+"), line)
            lines.append(line[1:])
        rendered = self.gen.render(self.data)
        self.assertEqual("\n".join(lines) + "\n", rendered)

    def test_gym_leaders_and_one_youngster_match_pokered(self):
        for label, class_name in CASES:
            for index, mon in enumerate(self.data["parties"][label][0], start=1):
                expected = self.gen.trainer_moves(
                    self.data, mon["species"], mon["level"], class_name, index)
                key = (class_name, index, mon["species"], mon["level"])
                self.assertEqual(self.actual[key], expected, key)
        events = (ROOT / "Source/game/trainerEvents.lua").read_text(encoding="utf-8")
        self.assertIn(
            "Pokemon.trainerMovesFor(mon.species, mon.level, value.definition.class_source, index, intro and intro.starter)",
            events)


if __name__ == "__main__":
    unittest.main()
