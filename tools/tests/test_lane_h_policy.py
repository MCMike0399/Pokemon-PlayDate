"""Post-Hall-of-Fame Mew gift and LINK CABLE.

Miguel picked these on Nov 12, 2026 at 9:43 AM CST. Mew is a level 5 gift,
one per save. LINK CABLE is a stone. The bag row and the evolution rules are
the lane E patch, so using the cable is an expected failure until that patch
lands. The walk is the session and the map graph, not a simulator clip.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tools.tests.postgame_route import SPAWN, _World, build_journey, location_hash

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/policy_gift_host.lua"
STORY = json.loads((ROOT / "Source/data/postgame/story.json").read_text())
PLAY = json.loads((ROOT / "Source/data/postgame/play.json").read_text())
PATCH = ROOT / "tools/notes/lane-e-link-cable.patch"


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
    raise AssertionError("Lua 5.4 is required")


def talk_prefix():
    npc = STORY["deviations"]["mew"]["npc"]
    talk = npc["talk"]
    steps = []
    for step in build_journey()["steps"]:
        steps.append(step)
        if step["map"] == npc["map"] and step["x"] == talk["x"] and step["y"] == talk["y"]:
            return steps, npc
    raise AssertionError("the postgame path does not reach the gift tile")


class PolicyGiftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.steps, cls.npc = talk_prefix()
        talk = cls.npc["talk"]
        payload = {
            "quest_flags": ["TOGGLE_CERULEAN_CAVE_GUY"],
            "steps": cls.steps,
            "talk": {"zone": cls.npc["zone_id"], "x": talk["x"], "y": talk["y"], "facing": talk["facing"]},
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "gift.json"
            path.write_text(json.dumps(payload))
            completed = subprocess.run(
                [lua_binary(), str(HOST), str(ROOT), str(path)],
                check=False, capture_output=True, text=True)
        if completed.returncode != 0:
            raise AssertionError(completed.stderr or completed.stdout)
        cls.host = json.loads(completed.stdout)

    def test_deviations_are_the_level_5_gift_and_link_cable(self):
        mew = STORY["deviations"]["mew"]
        cable = STORY["deviations"]["link_cable"]
        self.assertEqual(STORY["deviations"]["approved_by"], "Miguel")
        self.assertEqual(STORY["deviations"]["approved_at"], "2026-11-12T09:43:00-06:00")
        self.assertEqual(mew["species"], "mew")
        self.assertEqual(mew["level"], 5)
        self.assertTrue(mew["once"])
        self.assertEqual(mew["flag"], "EVENT_GOT_MEW")
        self.assertEqual((self.npc["x"], self.npc["y"], self.npc["map"]), (23, 16, "CeruleanCave1F"))
        self.assertLessEqual(len(cable["name"]), 10)
        self.assertEqual(cable["name"], "LINK CABLE")
        self.assertEqual(cable["text"], "Use like a stone.")
        self.assertFalse(cable["once"])
        self.assertEqual(
            [(row["from"], row["to"]) for row in cable["evolves"]],
            [("kadabra", "alakazam"), ("machoke", "machamp"), ("graveler", "golem"), ("haunter", "gengar")])
        self.assertIn("Celadon Mart", cable["why"])
        for label in ("_PostgameMewGiftText", "_PostgameLinkCableText", "_PostgameGiftNotChampionText"):
            self.assertEqual(PLAY["texts"][label]["source"], "miguel-approved-deviation")

    def test_continue_walks_to_the_giver_and_receives_one_mew(self):
        host = self.host
        talk = self.npc["talk"]
        self.assertEqual(host["actor_snapshot"], "fixture-empty")
        self.assertEqual(host["before"]["mew"]["status"], "not-champion")
        self.assertEqual(host["before"]["cable"]["status"], "not-champion")
        self.assertEqual(host["continue"], {
            "zone": "pokered:PALLET_TOWN", "x": 5, "y": 6, "facing": "down"})
        self.assertGreaterEqual(host["hall_teams"], 1)
        world = _World()
        state = SPAWN
        for index, step in enumerate(self.steps):
            key = (step["map"], step["x"], step["y"], step["mode"], step["facing"], step["kind"])
            self.assertIn(key, world.steps(*state), f"step {index} leaves {state}")
            state = key[:4]
        self.assertEqual((state[0], state[1], state[2]), (self.npc["map"], talk["x"], talk["y"]))
        turned = dict(self.steps[-1], facing=talk["facing"])
        self.assertEqual(host["hash"], location_hash(self.steps + [turned]))
        self.assertEqual(host["stood"], {
            "zone": self.npc["zone_id"], "x": talk["x"], "y": talk["y"], "facing": talk["facing"]})
        self.assertTrue(host["mew"]["ok"])
        self.assertEqual(host["mew"]["species"], "mew")
        self.assertEqual(host["mew"]["level"], 5)
        self.assertEqual(host["mew"]["destination"], "party")
        self.assertEqual(host["again"]["status"], "already-complete")
        self.assertEqual(host["mew_count"], 1)
        self.assertEqual(host["mew_level"], 5)
        self.assertTrue(host["mew_seen"])
        self.assertTrue(host["mew_owned"])
        self.assertTrue(host["mew_flag"])
        self.assertTrue(host["cable"]["status"])
        self.assertTrue(host["kadabra"]["attempted"])
        self.assertTrue(host["squirtle"]["attempted"])
        if not host["cable"]["ok"]:
            self.assertEqual(host["cable"]["status"], "unknown-item")
        if not host["kadabra"]["ok"]:
            self.assertIn("invalid-stone", host["kadabra"]["error"])

    @unittest.expectedFailure
    def test_link_cable_evolves_kadabra_and_not_squirtle(self):
        host = self.host
        self.assertTrue(host["cable"]["ok"])
        self.assertEqual(host["cable"]["item"], "linkCable")
        self.assertTrue(host["kadabra"]["ok"])
        self.assertEqual(host["kadabra"]["species"], "alakazam")
        self.assertEqual(host["kadabra"]["quantity"], 0)
        self.assertFalse(host["squirtle"]["ok"])
        self.assertIn("no-evolution", host["squirtle"]["error"])
        self.assertEqual(host["squirtle"]["species"], "squirtle")

    def test_link_cable_patch_is_one_dry_run(self):
        patch = PATCH.read_text()
        self.assertIn("linkCable", patch)
        self.assertIn("LINK CABLE", patch)
        self.assertIn("Use like a stone.", patch)
        self.assertNotIn("celadonMart4FClerkText", patch)
        for species in ("kadabra", "machoke", "graveler", "haunter"):
            self.assertIn(species, patch)
        completed = subprocess.run(
            ["patch", "--dry-run", "--fuzz=0", "-p1"],
            input=patch, text=True, capture_output=True, cwd=ROOT)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
