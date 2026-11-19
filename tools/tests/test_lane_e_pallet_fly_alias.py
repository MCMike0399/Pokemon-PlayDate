#!/usr/bin/env python3
"""Saves from before the Pallet cutover still name the authored fly city.

Sequence 577 visited Pallet as pallet_town. fieldTravel.json now allows
only pokered:PALLET_TOWN, so FieldTravel.normalize rejects the save and
the title menu has no CONTINUE. The alias belongs in normalize. It is
not applied here.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRAVEL = ROOT / "Source/domain/fieldTravel.lua"
TABLE = ROOT / "Source/data/fieldTravel.json"
PATCH = ROOT / "tools/notes/lane-e-pallet-fly-alias.patch"
SAVE = Path("/opt/cursor/artifacts/lane-b/seq577-adventure.b.json")


def visited():
    envelope = json.loads(SAVE.read_text())
    payload = json.loads(envelope["payload"])
    return payload["fieldTravel"]["visited"]


class PalletFlyAliasTests(unittest.TestCase):
    def test_seq577_names_the_authored_pallet_fly_city(self):
        allowed = {entry["id"] for entry in json.loads(TABLE.read_text())["fly"]}
        cities = visited()
        self.assertIn("pallet_town", cities)
        self.assertNotIn("pallet_town", allowed)
        self.assertIn("pokered:PALLET_TOWN", allowed)
        self.assertNotIn("pokered:PALLET_TOWN", cities)

    def test_live_normalize_rejects_that_id(self):
        text = TRAVEL.read_text()
        self.assertIn('assert(allowed[id] and not seen[id], "unknown or duplicate Fly city")', text)
        self.assertNotIn('id == "pallet_town"', text)

    def test_patch_rewrites_the_id_without_touching_source(self):
        before = TRAVEL.read_text()
        subprocess.check_call(["git", "apply", "--check", str(PATCH)], cwd=ROOT)
        patched = subprocess.check_output(["patch", "-o", "-", str(TRAVEL), str(PATCH)], cwd=ROOT, text=True)
        self.assertEqual(TRAVEL.read_text(), before)
        self.assertIn('id == "pallet_town"', patched)
        self.assertIn('id = "pokered:PALLET_TOWN"', patched)

    @unittest.expectedFailure
    def test_normalize_accepts_the_authored_pallet_fly_city(self):
        self.assertIn('id == "pallet_town"', TRAVEL.read_text())


if __name__ == "__main__":
    unittest.main()
