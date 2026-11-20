#!/usr/bin/env python3
"""Champion slot 3 follows wRivalStarter, not the player's starter.

pret/pokered af519899 read_trainer_party.asm .ChampionRival loads
wRivalStarter. STARTER3 (Bulbasaur) writes MEGA_DRAIN, STARTER1
(Charmander) writes FIRE_BLAST, and Squirtle writes BLIZZARD, all into
the sixth Pokémon's third move. Pidgeot's third move is SKY_ATTACK.
The party itself is already chosen from the player's starter. The move
argument has to be the rival's starter.
"""

import importlib.util
import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_trainer_moves_host.lua"
LAUNCH = ROOT / "Source/game/trainerEvents.lua"
RIVAL = {"charmander": "squirtle", "squirtle": "bulbasaur", "bulbasaur": "charmander"}


def reference():
    raw = os.environ.get("POKERED_REFERENCE_DIR")
    if not raw:
        raise RuntimeError("POKERED_REFERENCE_DIR is required")
    path = Path(raw)
    if not path.is_dir():
        raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
    return path


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


def passed_starter(source):
    match = re.search(
        r"Pokemon\.trainerMovesFor\(\s*mon\.species,\s*mon\.level,\s*"
        r"value\.definition\.class_source,\s*index,\s*([^)]+)\)",
        source)
    if not match:
        raise AssertionError("trainer launch does not call trainerMovesFor")
    return match.group(1).strip()


class ChampionRivalStarterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gen = generator()
        cls.data = cls.gen.load(reference(), ROOT / "Source/battle/moves.lua")
        teams = {}
        for team in cls.data["parties"]["Rival3"]:
            teams[team[-1]["species"]] = team
        cls.teams = {
            "charmander": teams["blastoise"],
            "squirtle": teams["venusaur"],
            "bulbasaur": teams["charizard"],
        }
        argument = passed_starter(LAUNCH.read_text(encoding="utf-8"))
        request = []
        cls.asked = {}
        for player, rival in RIVAL.items():
            if argument == "intro and intro.rivalStarter":
                asked = rival
            elif argument == "intro and intro.starter":
                asked = player
            else:
                raise AssertionError("unexpected starter argument: " + argument)
            cls.asked[player] = asked
            for index, mon in enumerate(cls.teams[player], start=1):
                if index not in (1, 6):
                    continue
                request.append("|".join((
                    "OPP_RIVAL3", str(index), mon["species"], str(mon["level"]), asked)))
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT), ";".join(request)],
            check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.actual = {}
        for line in completed.stdout.splitlines():
            if not line.startswith("moves "):
                continue
            _, _class, index, species, level, moves = line.split(" ", 5)
            cls.actual[(int(index), species, int(level))] = moves.split(",")

    def test_final_team_specials_follow_the_rival_starter(self):
        for player, team in self.teams.items():
            rival = RIVAL[player]
            lead, ace = team[0], team[5]
            with self.subTest(player=player, rival=rival):
                expected_lead = self.gen.trainer_moves(
                    self.data, lead["species"], lead["level"], "OPP_RIVAL3", 1, rival)
                expected_ace = self.gen.trainer_moves(
                    self.data, ace["species"], ace["level"], "OPP_RIVAL3", 6, rival)
                self.assertEqual(
                    self.actual[(1, lead["species"], lead["level"])], expected_lead)
                self.assertEqual(
                    self.actual[(6, ace["species"], ace["level"])], expected_ace,
                    "player %s asked %s; wRivalStarter is %s" % (player, self.asked[player], rival))
