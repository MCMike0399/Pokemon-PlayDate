#!/usr/bin/env python3
"""Vermilion Gym cans, Surge, Rock Tunnel, and Erika against pokered af519899.

The trash-can bytes are GymTrashCans plus the and-$e first lock. Parties are
the object roster numbers in parties.asm. Moves are level-1 plus evos_moves,
then LoneMoves for the gym leaders.
"""

import importlib.util
import json
import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/lane_k_trash_can_host.lua"
MOVES = ROOT / "tools/tests/lane_k_trainer_moves_host.lua"
INTENT = ROOT / "Source/game/vermilionStoryIntent.lua"
HOOKS = ROOT / "Source/game/vermilionStoryHooks.lua"
SCENES = ROOT / "Source/data/vermilionStory/scenes.json"
TRAINER_FILES = (
    ROOT / "Source/data/vermilionStory/trainers.json",
    ROOT / "Source/data/vermilionPreparation/trainers.json",
    ROOT / "Source/data/midgameEast/trainers.json",
)
MAPS = {
    "VermilionGym": ROOT / "Source/data/sourceMapCache/runtime-VermilionGym.json",
    "RockTunnel1F": ROOT / "Source/data/sourceMapCache/runtime-RockTunnel1F.json",
    "RockTunnelB1F": ROOT / "Source/data/sourceMapCache/runtime-RockTunnelB1F.json",
    "CeladonGym": ROOT / "Source/data/sourceMapCache/runtime-CeladonGym.json",
}
CLASS_TO_PARTY = {
    "OPP_LT_SURGE": "LtSurge",
    "OPP_GENTLEMAN": "Gentleman",
    "OPP_ROCKER": "Rocker",
    "OPP_SAILOR": "Sailor",
    "OPP_HIKER": "Hiker",
    "OPP_POKEMANIAC": "Pokemaniac",
    "OPP_JR_TRAINER_F": "JrTrainerF",
    "OPP_ERIKA": "Erika",
    "OPP_LASS": "Lass",
    "OPP_BEAUTY": "Beauty",
    "OPP_COOLTRAINER_F": "CooltrainerF",
}


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


def asm_cans(path):
    text = path.read_text(encoding="utf-8")
    block = text.split("GymTrashCans:", 1)[1].split("VermilionGymTrashSuccessText1", 1)[0]
    rows = []
    for raw in block.splitlines():
        line = raw.split(";", 1)[0]
        if "db" not in line:
            continue
        nums = [int(part) for part in re.findall(r"-?\d+", line)]
        if len(nums) == 5:
            rows.append(nums)
    return rows


def second_can(table, first, byte):
    """swap(byte) & mask, then dec. A zero underflows to can 0."""
    row = table[first]
    swapped = ((byte & 15) << 4) | (byte >> 4)
    picked = (swapped & row[0]) - 1
    if picked < 0:
        return 0
    return row[picked + 1] & 15


def installed_trainers():
    found = {}
    for path in TRAINER_FILES:
        for key, row in json.loads(path.read_text(encoding="utf-8"))["trainers"].items():
            found[key] = row
    return found


class VermilionToCeladonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ref = reference()
        cls.gen = generator()
        cls.data = cls.gen.load(ref, ROOT / "Source/battle/moves.lua")
        cls.asm = asm_cans(ref / "engine/events/hidden_events/vermilion_gym_trash.asm")
        cls.scenes = json.loads(SCENES.read_text(encoding="utf-8"))["scenes"]["trash"]
        cls.trainers = installed_trainers()
        table = ";".join(",".join(str(cell) for cell in row) for row in cls.scenes["table"])
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT), table],
            check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.engine = {}
        for line in completed.stdout.splitlines():
            if not line.startswith("second "):
                continue
            _, first, byte, can = line.split()
            cls.engine[(int(first), int(byte))] = int(can)
        request = []
        cls.expected_moves = {}
        for map_name in MAPS:
            for obj in json.loads(MAPS[map_name].read_text(encoding="utf-8"))["definition"]["events"]["objects"]:
                extra = obj.get("extra") or []
                if len(extra) < 2 or extra[0] not in CLASS_TO_PARTY:
                    continue
                label = CLASS_TO_PARTY[extra[0]]
                team = cls.data["parties"][label][int(extra[1]) - 1]
                for index, mon in enumerate(team, start=1):
                    request.append("|".join((
                        extra[0], str(index), mon["species"], str(mon["level"]))))
                    cls.expected_moves[(extra[0], index, mon["species"], mon["level"])] = (
                        cls.gen.trainer_moves(
                            cls.data, mon["species"], mon["level"], extra[0], index))
        completed = subprocess.run(
            [lua_binary(), str(MOVES), str(ROOT), ";".join(request)],
            check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.actual_moves = {}
        for line in completed.stdout.splitlines():
            if not line.startswith("moves "):
                continue
            _, class_name, index, species, level, moves = line.split(" ", 5)
            cls.actual_moves[(class_name, int(index), species, int(level))] = moves.split(",")

    def test_trash_table_matches_gym_trash_cans(self):
        self.assertEqual(len(self.asm), 15)
        self.assertEqual(self.scenes["table"], self.asm)
        self.assertEqual(self.scenes["first_mask"], 14)
        cans = {(row["index"], row["x"], row["y"]) for row in self.scenes["cans"]}
        hidden = (reference() / "data/events/hidden_events.asm").read_text(encoding="utf-8")
        found = re.findall(
            r"hidden_event\s+(\d+),\s+(\d+),\s+GymTrashScript,\s+(\d+)",
            hidden)
        self.assertEqual({(int(index), int(x), int(y)) for x, y, index in found}, cans)

    def test_second_can_matches_the_engine(self):
        self.assertEqual(len(self.engine), 15 * 256)
        for first in range(15):
            for byte in range(256):
                expected = second_can(self.asm, first, byte)
                self.assertEqual(self.engine[(first, byte)], expected, (first, byte))
        # Can 0's mask is 2, so half the bytes underflow to can 0 and the
        # other half select the second listed can. The first listed can is skipped.
        zeroes = [byte for byte in range(256) if self.engine[(0, byte)] == 0]
        thirds = [byte for byte in range(256) if self.engine[(0, byte)] == 3]
        self.assertEqual(len(zeroes), 128)
        self.assertEqual(len(thirds), 128)
        self.assertEqual(self.engine[(4, 0)], 0)
        self.assertEqual(self.engine[(4, 64)], 7)

    def test_first_can_is_the_even_mask(self):
        intent = INTENT.read_text(encoding="utf-8")
        hooks = HOOKS.read_text(encoding="utf-8")
        # City door entry, the first trash check before that entry, and a wrong second can.
        self.assertEqual(intent.count("random:random(0, 255) & 14"), 3)
        self.assertIn('changes.flags[firstFlag] = false', intent)
        self.assertIn("options and options.fromDoor", hooks)
        for byte in range(256):
            can = byte & 14
            self.assertEqual(can % 2, 0)
            self.assertLessEqual(can, 14)

    def test_parties_match_the_roster_numbers(self):
        for map_name, path in MAPS.items():
            objects = json.loads(path.read_text(encoding="utf-8"))["definition"]["events"]["objects"]
            for obj in objects:
                extra = obj.get("extra") or []
                if len(extra) < 2 or extra[0] not in CLASS_TO_PARTY:
                    continue
                label = CLASS_TO_PARTY[extra[0]]
                expected = [
                    {"level": mon["level"], "species": mon["species"]}
                    for mon in self.data["parties"][label][int(extra[1]) - 1]]
                got = self.trainers[obj["id"]]["party"]
                with self.subTest(map=map_name, trainer=obj["id"]):
                    self.assertEqual(
                        [{"level": mon["level"], "species": mon["species"]} for mon in got],
                        expected)

    def test_moves_match_level_up_and_lone_moves(self):
        for key, expected in self.expected_moves.items():
            with self.subTest(trainer=key):
                self.assertEqual(self.actual_moves[key], expected)
        raichu = self.actual_moves[("OPP_LT_SURGE", 3, "raichu", 24)]
        vileplume = self.actual_moves[("OPP_ERIKA", 3, "vileplume", 29)]
        self.assertEqual(raichu, ["thunderShock", "growl", "thunderbolt"])
        self.assertIn("megaDrain", vileplume)
        self.assertNotIn("stunSpore", vileplume)


if __name__ == "__main__":
    unittest.main()
