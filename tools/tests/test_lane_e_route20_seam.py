#!/usr/bin/env python3
"""Route 20's south channel is sealed, so Surf cannot reach Cinnabar.

Pokered map Route20.blk at af519899 is 50 by 9 blocks. Block row 7 is
water block 0x43 from the east shore through the west shore. The imported
cells are two per block, so that row is cells y=14 and y=15. Cell x=62 on
both rows is tile 11, which is not water, while x=61 and x=63 are water.
A flood of the east water stops at x=63. Opening those two cells reaches
the west edge. The Mansion and Blaine are past that shore. This test fails
until tools/notes/lane-e-route20-seam.patch is applied. The patch does not
grant Surf or a badge.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROUTE = ROOT / "Source/data/zCoast/Route20.json"
PATCH = ROOT / "tools/notes/lane-e-route20-seam.patch"


def water(data, x, y):
    tile = data["tile_ids"][y][x]
    return data["grids"][tile - 1]["terrain"].get("water_candidate") is True


class Route20SeamTest(unittest.TestCase):
    def test_patch_opens_the_two_seam_cells(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("Source/data/zCoast/Route20.json", patch)
        self.assertNotIn("MallocPoolSize", patch)
        self.assertIn("4,4,4,4,11,4,4,4,4", patch)
        self.assertIn("4,4,4,4,4,4,4,4,4", patch)

    def test_south_channel_is_water_across_the_seam(self):
        data = json.loads(ROUTE.read_text(encoding="utf-8"))
        for y in (14, 15):
            self.assertTrue(water(data, 61, y))
            self.assertTrue(water(data, 63, y))
            self.assertTrue(
                water(data, 62, y),
                "Route 20 cell (%s, %s) seals the south Surf channel. "
                "Apply tools/notes/lane-e-route20-seam.patch" % (62, y),
            )


if __name__ == "__main__":
    unittest.main()
