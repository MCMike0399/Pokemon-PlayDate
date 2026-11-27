#!/usr/bin/env python3
"""Buy LINK CABLE on Celadon 4F and evolve Kadabra before the Elite Four.

The shelf change lives in tools/notes/lane-e-link-cable-celadon-4f.patch.
This journey fails until that patch is applied: the 4F clerk does not stock
the cable, so Kadabra never becomes Alakazam. The cable is ¥2100, the same
as the stones, and it sells for ¥1050.
"""

import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.harness.run import sdk_path

PATCH = ROOT / "tools/notes/lane-e-link-cable-celadon-4f.patch"
SCENARIO = ROOT / "tools/harness/scenarios/link-cable-celadon.json"
POKERED = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered"))
CAVE = POKERED / "data/maps/objects/CeruleanCave1F.asm"
BALLS = (
    "object_event  7, 13, SPRITE_POKE_BALL, STAY, NONE, TEXT_CERULEANCAVE1F_FULL_RESTORE, FULL_RESTORE",
    "object_event 19,  3, SPRITE_POKE_BALL, STAY, NONE, TEXT_CERULEANCAVE1F_MAX_ELIXER, MAX_ELIXER",
    "object_event  5,  0, SPRITE_POKE_BALL, STAY, NONE, TEXT_CERULEANCAVE1F_NUGGET, NUGGET",
)


def run_journey(output):
    sdk = sdk_path(os.environ.get("PLAYDATE_SDK_PATH"))
    output = Path(output)
    if output.exists():
        shutil.rmtree(output)
    proc = subprocess.run(
        [
            sys.executable, "tools/harness/run.py",
            "--sdk", str(sdk),
            "--scenario", str(SCENARIO),
            "--output", str(output),
            "--timeout", "240",
            "--ready-timeout", "90",
        ],
        cwd=ROOT,
        check=False,
        text=True,
        capture_output=True,
    )
    summary_path = output / "journey-summary.json"
    summary = json.loads(summary_path.read_text()) if summary_path.is_file() else {
        "ok": False, "error": proc.stderr or proc.stdout or "no journey summary",
    }
    return proc, summary


class CeladonLinkCableTests(unittest.TestCase):
    def test_patch_keeps_the_scientist_and_the_three_cave_balls(self):
        text = PATCH.read_text()
        added = "\n".join(
            line[1:] for line in text.splitlines()
            if line.startswith("+") and not line.startswith("+++"))
        self.assertIn('celadonMart4FClerkText = { "pokeDoll", "fireStone", "thunderStone", "waterStone", "leafStone", "linkCable" }', text)
        self.assertIn("a7347868", text)
        self.assertIn("Use like a stone.", text)
        self.assertIn('["price"] = 2100', added)
        self.assertIn('["sellPrice"] = 1050', added)
        self.assertNotIn("MallocPoolSize", text)
        self.assertNotIn("CeruleanCave1F", text)
        self.assertNotIn("FULL_RESTORE", added)
        cave = CAVE.read_text()
        for ball in BALLS:
            self.assertIn(ball, cave)
        self.assertEqual(cave.count("SPRITE_POKE_BALL"), 3)
        story = (ROOT / "Source/data/postgame/story.json").read_text()
        self.assertIn("postgame:CERULEAN_CAVE_1F:mew-gift", story)
        items = (ROOT / "Source/data/items.lua").read_text()
        self.assertIn('["text"] = "Use like a stone."', items)

    def test_link_cable_is_priced_with_the_stones(self):
        items = (ROOT / "Source/data/items.lua").read_text()
        cable = items.split("linkCable = ", 1)[1].split("},", 1)[0]
        self.assertIn('["price"] = 2100', cable)
        self.assertIn('["sellPrice"] = 1050', cable)
        for stone in ("fireStone", "thunderStone", "waterStone", "leafStone"):
            row = items.split(stone + " = ", 1)[1].split("},", 1)[0]
            self.assertIn('["price"] = 2100', row, stone)
            self.assertIn('["sellPrice"] = 1050', row, stone)

    def test_walk_buy_and_evolve_kadabra_before_the_elite_four(self):
        output = Path(os.environ.get("LINK_CABLE_JOURNEY_OUTPUT", "/tmp/link-cable-celadon"))
        _proc, summary = run_journey(output)
        self.assertTrue(summary.get("ok"), summary.get("error"))
        species = ((summary.get("last_snapshot") or {}).get("pokemon") or {}).get("species")
        self.assertEqual(species, "alakazam")
        money = ((summary.get("last_snapshot") or {}).get("inventory") or {}).get("money")
        self.assertEqual(money, 900)
        bought = summary.get("link_cable") or {}
        self.assertEqual(bought.get("price"), 2100)
        self.assertEqual(bought.get("spent"), 2100)
        self.assertEqual(bought.get("sell"), 1050)
        self.assertEqual(bought.get("money"), 900)
        checkpoints = [item.get("name") for item in summary.get("checkpoints") or []]
        self.assertIn("celadon-4f", checkpoints)
        self.assertIn("alakazam", checkpoints)


if __name__ == "__main__":
    unittest.main()
