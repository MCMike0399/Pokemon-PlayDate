#!/usr/bin/env python3
"""The no-argument contracts catalog drops a finished suite before the next one.

world, traversal, event-ui and pewterProviderContracts leave suite tables
live. On clean main 247d60a9 the catalog reached individual-stats-v1 at
13805.133 KiB and died in pd_readcompressed while publishing that score.
The overlay nils the finished suite module and its contract_ zones.
MallocPoolSize stays 16645684.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OVERLAY = ROOT / "tools/harness/dev_imports.lua"


class CatalogReleaseTest(unittest.TestCase):
    def test_overlay_releases_resident_maps_between_suites(self):
        text = OVERLAY.read_text(encoding="utf-8")
        body = text.split("local function releaseResidentCatalog", 1)[1].split(
            "function Contracts.register", 1
        )[0]
        self.assertIn('key:sub(1, 9) == "contract_"', body)
        self.assertNotIn("releaseRetainedRuntime", body)
        self.assertNotIn("disposeImportedCache", body)
        self.assertNotIn("_releaseSharedCompact", body)
        self.assertNotIn("_releaseTileGrids", body)
        self.assertIn("run = nil", text)
        self.assertNotIn("MallocPoolSize", text)
        for kept in (
            "KantoServicesContracts",
            "PartyBattleContracts",
            "SessionContracts",
            "CeruleanSceneContracts",
            "CeruleanRoutesContracts",
        ):
            self.assertIn(kept, text)


if __name__ == "__main__":
    unittest.main()
