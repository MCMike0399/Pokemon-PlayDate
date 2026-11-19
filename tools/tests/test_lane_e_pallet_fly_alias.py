#!/usr/bin/env python3
"""Pre-cutover saves visited Pallet as pallet_town.

fieldTravel.json allows only pokered:PALLET_TOWN. FieldTravel.normalize
rewrites that one saved id onto the existing Fly slot. It does not add a
destination, and Fly still refuses the authored id.
"""

import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools/tests/pallet_fly_alias_host.lua"
TRAVEL = ROOT / "Source/domain/fieldTravel.lua"
TABLE = ROOT / "Source/data/fieldTravel.json"


def lua_binary():
    override = os.environ.get("LUA")
    if override:
        return override
    for name in ("lua5.4", "lua"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required to call FieldTravel.normalize")


class PalletFlyAliasTests(unittest.TestCase):
    def test_fly_table_keeps_the_source_pallet_slot(self):
        rows = json.loads(TABLE.read_text())["fly"]
        pallet = [row for row in rows if row["source_map"] == "PALLET_TOWN"]
        self.assertEqual(len(pallet), 1)
        self.assertEqual(pallet[0]["id"], "pokered:PALLET_TOWN")
        self.assertEqual((pallet[0]["x"], pallet[0]["y"]), (5, 6))
        self.assertNotIn("pallet_town", {row["id"] for row in rows})
        text = TRAVEL.read_text()
        rewrite = text.index('id == "pallet_town"')
        replacement = text.index('id = "pokered:PALLET_TOWN"', rewrite)
        guard = text.index('unknown or duplicate Fly city', replacement)
        self.assertLess(rewrite, replacement)
        self.assertLess(replacement, guard)

    def test_normalize_aliases_the_authored_visit_onto_the_existing_slot(self):
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT)],
            check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        lines = completed.stdout.splitlines()
        self.assertIn("caller pallet_town,pokered:VIRIDIAN_CITY", lines)
        self.assertIn("alias pokered:PALLET_TOWN,pokered:VIRIDIAN_CITY", lines)
        self.assertIn("destination-count 2", lines)
        self.assertIn("destination pokered:PALLET_TOWN PALLET_TOWN 5 6 PalletTown", lines)
        self.assertIn("destination pokered:VIRIDIAN_CITY VIRIDIAN_CITY 23 26 ViridianCity", lines)
        self.assertIn("fly pokered:PALLET_TOWN 5 6 walking", lines)
        self.assertIn("old-id unvisited-fly-destination", lines)
        self.assertIn("canonical pokered:PALLET_TOWN", lines)
        self.assertIn("empty 0 0", lines)
        self.assertIn("other pokered:VIRIDIAN_CITY 1", lines)
        self.assertIn("duplicate rejected", lines)
        self.assertIn("unknown rejected", lines)


if __name__ == "__main__":
    unittest.main()
