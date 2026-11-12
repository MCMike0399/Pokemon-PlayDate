"""Headless post-Hall-of-Fame walk to Mewtwo and Zapdos.

Lane E applied tools/notes/lane-e-static-encounters.patch, so the battle
step prepares Mewtwo and Zapdos. Every step before that request has to
succeed. The Pallet actor snapshot is a fixture. The Simulator contracts
are a separate run.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tools.tests.postgame_route import MEWTWO, SPAWN, ZAPDOS, _World, build_journey, location_hash

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/postgame_journey_host.lua"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    built = Path("/tmp/lua-5.4.7/src/lua")
    if built.is_file() and os.access(built, os.X_OK):
        return str(built)
    raise AssertionError("Lua 5.4 is required for the postgame journey")


class PostgameJourneyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.journey = build_journey()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "journey.json"
            path.write_text(json.dumps(cls.journey))
            completed = subprocess.run(
                [lua_binary(), str(HOST), str(ROOT), str(path)],
                check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.host = json.loads(completed.stdout)

    def test_every_step_is_a_legal_walk_warp_ledge_surf_or_connection(self):
        journey = self.journey
        self.assertEqual(journey["spawn"], {
            "map": "PalletTown", "zone": "pokered:PALLET_TOWN",
            "x": 5, "y": 6, "facing": "down", "mode": "walk"})
        self.assertGreater(journey["mewtwo_index"], 0)
        self.assertGreater(journey["zapdos_index"], journey["mewtwo_index"])
        mewtwo = journey["steps"][journey["mewtwo_index"]]
        zapdos = journey["steps"][journey["zapdos_index"]]
        self.assertIn((mewtwo["map"], mewtwo["x"], mewtwo["y"]), MEWTWO)
        self.assertIn((zapdos["map"], zapdos["x"], zapdos["y"]), ZAPDOS)
        self.assertEqual(mewtwo["mode"], "walk")
        self.assertEqual(zapdos["mode"], "walk")
        maps = [step["map"] for step in journey["steps"]]
        self.assertIn("Route24", maps)
        self.assertIn("CeruleanCave1F", maps)
        self.assertIn("CeruleanCaveB1F", maps)
        self.assertIn("CeruleanTrashedHouse", maps)
        self.assertIn("PowerPlant", maps)
        self.assertFalse(any(name.startswith("Seafoam") for name in maps))
        self.assertTrue(any(step["map"] == "Route24" and step["kind"] == "surf" for step in journey["steps"]))
        kinds = {step["kind"] for step in journey["steps"]}
        self.assertTrue(kinds <= {"walk", "ledge", "warp", "connection", "surf", "surf-land"})
        # setLocation uses an identity resolver. This walk is what proves each
        # cell is a real successor on the compact collision graph.
        world = _World()
        state = SPAWN
        for index, step in enumerate(journey["steps"]):
            key = (step["map"], step["x"], step["y"], step["mode"], step["facing"], step["kind"])
            self.assertIn(key, world.steps(*state), f"step {index} leaves {state}")
            state = key[:4]

    def test_continue_lands_in_pallet_and_both_requests_are_reached(self):
        host = self.host
        journey = self.journey
        self.assertEqual(host["actor_snapshot"], "fixture-empty")
        self.assertEqual(host["continue"], {
            "zone": "pokered:PALLET_TOWN", "x": 5, "y": 6, "facing": "down"})
        self.assertGreaterEqual(host["hall_teams"], 1)
        self.assertTrue(host["rival_defeated"])
        for flag in journey["quest_flags"]:
            self.assertTrue(host["flags"][flag], flag)
        self.assertEqual(host["steps"], len(journey["steps"]))
        self.assertEqual(host["hash"], location_hash(journey["steps"]))
        mewtwo = journey["steps"][journey["mewtwo_index"]]
        zapdos = journey["steps"][journey["zapdos_index"]]
        self.assertEqual(host["mewtwo"], {
            "zone": mewtwo["zone"], "x": mewtwo["x"], "y": mewtwo["y"], "facing": mewtwo["facing"]})
        self.assertEqual(host["zapdos"], {
            "zone": zapdos["zone"], "x": zapdos["x"], "y": zapdos["y"], "facing": zapdos["facing"]})
        self.assertEqual(host["mewtwo_request"]["id"], "pokered:CERULEAN_CAVE_B1F:objects:1")
        self.assertEqual(host["mewtwo_request"]["species"], "mewtwo")
        self.assertEqual(host["mewtwo_request"]["level"], 70)
        self.assertEqual(host["mewtwo_request"]["zone_id"], "pokered:CERULEAN_CAVE_B1F")
        self.assertTrue(host["mewtwo_request"]["outcomes"]["run"]["flags"]["EVENT_BEAT_MEWTWO"])
        self.assertTrue(host["mewtwo_request"]["outcomes"]["victory"]["flags"]["EVENT_BEAT_MEWTWO"])
        self.assertTrue(host["mewtwo_request"]["outcomes"]["caught"]["flags"]["EVENT_BEAT_MEWTWO"])
        self.assertFalse(host["mewtwo_request"]["outcomes"]["defeat"]["flags"])
        self.assertEqual(host["zapdos_request"]["id"], "pokered:POWER_PLANT:objects:9")
        self.assertEqual(host["zapdos_request"]["species"], "zapdos")
        self.assertEqual(host["zapdos_request"]["level"], 50)
        self.assertEqual(host["zapdos_request"]["zone_id"], "pokered:POWER_PLANT")
        self.assertTrue(host["zapdos_request"]["outcomes"]["run"]["flags"]["EVENT_BEAT_ZAPDOS"])
        self.assertFalse(host["zapdos_request"]["outcomes"]["defeat"]["flags"])
        for name in ("mewtwo_battle", "zapdos_battle"):
            self.assertTrue(host[name]["attempted"])
            if not host[name]["ok"]:
                self.assertIn("unsupported source encounter", host[name]["error"])

    def test_battle_step_prepares_mewtwo_and_zapdos(self):
        self.assertTrue(self.host["mewtwo_battle"]["ok"])
        self.assertTrue(self.host["zapdos_battle"]["ok"])
        self.assertEqual(self.host["mewtwo_battle"]["species"], "mewtwo")
        self.assertEqual(self.host["zapdos_battle"]["species"], "zapdos")
