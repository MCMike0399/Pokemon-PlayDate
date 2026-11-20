#!/usr/bin/env python3
"""S.S. Anne rival for a Squirtle player matches pokered Rival2Data.

pret/pokered af519899. wRivalStarter Bulbasaur selects trainer $2:
Pidgeotto 19, Raticate 16, Kadabra 18, Ivysaur 20. Moves come from
the generator, not a hand-written list.
"""

import importlib.util
import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_trainer_moves_host.lua"
TRAINERS = ROOT / "Source/data/vermilionStory/trainers.json"
RIVAL = "pokered:SS_ANNE_2F:objects:2"
PLAYER_TO_TEAM = {"charmander": 0, "squirtle": 1, "bulbasaur": 2}


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


def reference():
    raw = os.environ.get("POKERED_REFERENCE_DIR")
    if not raw:
        raise RuntimeError("POKERED_REFERENCE_DIR is required")
    path = Path(raw)
    if not path.is_dir():
        raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
    return path


class AnneRivalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gen = generator()
        cls.data = cls.gen.load(reference(), ROOT / "Source/battle/moves.lua")
        cls.anne = cls.data["parties"]["Rival2"][:3]
        cls.story = json.loads(TRAINERS.read_text(encoding="utf-8"))["trainers"][RIVAL]
        request = []
        for team in cls.anne:
            for index, mon in enumerate(team, start=1):
                request.append("|".join((
                    "OPP_RIVAL2", str(index), mon["species"], str(mon["level"]))))
        for index, mon in enumerate(cls.data["parties"]["LtSurge"][0], start=1):
            request.append("|".join((
                "OPP_LT_SURGE", str(index), mon["species"], str(mon["level"]))))
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

    def test_each_player_starter_matches_the_anne_row(self):
        for player, team_index in PLAYER_TO_TEAM.items():
            expected = [
                {"species": mon["species"], "level": mon["level"]}
                for mon in self.anne[team_index]]
            got = self.story["rival_parties"][player]["party"]
            with self.subTest(player=player):
                self.assertEqual(got, expected)

    def test_squirtle_moves_match_pokered_level_up(self):
        team = self.anne[PLAYER_TO_TEAM["squirtle"]]
        self.assertEqual(team[-1]["species"], "ivysaur")
        for index, mon in enumerate(team, start=1):
            expected = self.gen.moves_at_level(self.data, mon["species"], mon["level"])
            actual = self.actual[("OPP_RIVAL2", index, mon["species"], mon["level"])]
            with self.subTest(species=mon["species"], level=mon["level"]):
                self.assertEqual(actual, expected)
        kadabra = self.actual[("OPP_RIVAL2", 3, "kadabra", 18)]
        ivysaur = self.actual[("OPP_RIVAL2", 4, "ivysaur", 20)]
        self.assertIn("disable", kadabra)
        self.assertIn("leechSeed", ivysaur)
        self.assertIn("vineWhip", ivysaur)
        self.assertNotIn("poisonPowder", ivysaur)

    def test_raichu_moves_match_pokered(self):
        team = self.data["parties"]["LtSurge"][0]
        story = json.loads(TRAINERS.read_text(encoding="utf-8"))
        surge = story["trainers"]["pokered:VERMILION_GYM:objects:1"]["party"]
        self.assertEqual(
            [{"species": mon["species"], "level": mon["level"]} for mon in team],
            surge)
        raichu = self.actual[("OPP_LT_SURGE", 3, "raichu", 24)]
        expected = self.gen.trainer_moves(self.data, "raichu", 24, "OPP_LT_SURGE", 3)
        self.assertEqual(raichu, expected)
        self.assertIn("thunderbolt", raichu)
