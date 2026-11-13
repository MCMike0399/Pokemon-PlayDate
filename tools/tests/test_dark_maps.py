#!/usr/bin/env python3
"""Only Rock Tunnel 1F and B1F are dark. A cavern tileset is not enough.

home/overworld.asm WarpFound2 writes wMapPalOffset 6 only when an outside map
warps to ROCK_TUNNEL_1F. .goBackOutside clears it. MapEntryAfterBattle fades
from white when the offset is 0. Every Seafoam floor, Cerulean Cave floor,
Mt. Moon, Diglett's Cave, and Victory Road uses tileset CAVERN and stays lit.
FieldWorld.eligibleDarkMap reads fieldMoves.json dark_maps. It does not treat
every cave tileset as dark. coastStory.lua and coastStoryWorld.lua do not set
a darkness flag.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = Path(os.environ.get("POKERED_REFERENCE_DIR", "/tmp/pokered"))
HEADERS = REFERENCE / "data/maps/headers"
OVERWORLD = REFERENCE / "home/overworld.asm"
FIELD_MOVES = ROOT / "Source/data/fieldMoves.json"
FIELD_INDEX = ROOT / "Source/data/fieldMoveIndex.json"
COAST = (
    ROOT / "Source/game/coastStory.lua",
    ROOT / "Source/game/coastStoryWorld.lua",
)
DARK = ["pokered:ROCK_TUNNEL_1F", "pokered:ROCK_TUNNEL_B1F"]
LIT_CAVERN = (
    "SEAFOAM_ISLANDS_1F", "SEAFOAM_ISLANDS_B1F", "SEAFOAM_ISLANDS_B2F",
    "SEAFOAM_ISLANDS_B3F", "SEAFOAM_ISLANDS_B4F",
    "CERULEAN_CAVE_1F", "CERULEAN_CAVE_2F", "CERULEAN_CAVE_B1F",
    "MT_MOON_1F", "MT_MOON_B1F", "MT_MOON_B2F",
    "DIGLETTS_CAVE", "VICTORY_ROAD_1F", "VICTORY_ROAD_2F", "VICTORY_ROAD_3F",
)

PROBE = r"""
GameSession = { _copy = function(value) return value end }
FieldMoves = {
  same = function() return false end,
  darkMaps = function()
    return { "pokered:ROCK_TUNNEL_1F", "pokered:ROCK_TUNNEL_B1F" }
  end,
}
WorldDeltas = {
  definitionProvider = function()
    return {
      hasID = function() return true end,
      descriptor = function(_, id)
        return { id = id, revision = "af519899719f0754965776faac0e836a3b906e6d" }
      end,
    }
  end,
}
dofile(field_world_path)
local function dark(id) return FieldWorld.eligibleDarkMap(id) == true end
assert(dark("pokered:ROCK_TUNNEL_1F"))
assert(dark("pokered:ROCK_TUNNEL_B1F"))
for _, id in ipairs({
  "pokered:SEAFOAM_ISLANDS_1F", "pokered:SEAFOAM_ISLANDS_B1F",
  "pokered:SEAFOAM_ISLANDS_B2F", "pokered:SEAFOAM_ISLANDS_B3F",
  "pokered:SEAFOAM_ISLANDS_B4F", "pokered:CERULEAN_CAVE_1F",
  "pokered:CERULEAN_CAVE_2F", "pokered:CERULEAN_CAVE_B1F",
  "pokered:MT_MOON_1F", "pokered:DIGLETTS_CAVE", "pokered:VICTORY_ROAD_1F",
}) do
  assert(not dark(id), id)
  assert(FieldWorld.transitionOffset(0, "pokered:PALLET_TOWN", id, "map", FieldWorld.eligibleDarkMap) == 0, id)
end
assert(FieldWorld.transitionOffset(0, "pokered:ROUTE_10", "pokered:ROCK_TUNNEL_1F", "map", FieldWorld.eligibleDarkMap) == 6)
assert(FieldWorld.transitionOffset(6, "pokered:ROCK_TUNNEL_1F", "pokered:ROCK_TUNNEL_B1F", "map", FieldWorld.eligibleDarkMap) == 6)
assert(FieldWorld.transitionOffset(6, "pokered:ROCK_TUNNEL_B1F", "pokered:ROUTE_10", "map", FieldWorld.eligibleDarkMap) == 0)
"""


def cavern_maps():
    found = {}
    for path in HEADERS.glob("*.asm"):
        for line in path.read_text().splitlines():
            parts = line.split()
            if len(parts) >= 4 and parts[0] == "map_header" and parts[3] == "CAVERN":
                found[parts[2].rstrip(",")] = path.name
    return found


class DarkMapTests(unittest.TestCase):
    def test_only_rock_tunnel_is_dark(self):
        cavern = cavern_maps()
        for constant in LIT_CAVERN:
            self.assertIn(constant, cavern, constant)
        self.assertIn("ROCK_TUNNEL_1F", cavern)
        self.assertIn("ROCK_TUNNEL_B1F", cavern)
        overworld = OVERWORLD.read_text()
        warp = overworld.split("WarpFound2::", 1)[1].split("\n.indoorMaps", 1)[0]
        self.assertIn("cp ROCK_TUNNEL_1F", warp)
        self.assertIn("ld a, $06", warp)
        self.assertEqual(warp.count("ld [wMapPalOffset], a"), 1)
        self.assertNotIn("SEAFOAM", warp)
        self.assertNotIn("CERULEAN_CAVE", warp)
        for path in (FIELD_MOVES, FIELD_INDEX):
            self.assertEqual(json.loads(path.read_text())["dark_maps"], DARK)
        for path in COAST:
            text = path.read_text()
            self.assertNotIn("mapPalOffset", text)
            self.assertNotIn("dark_maps", text)
            self.assertNotIn("eligibleDarkMap", text)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.lua"
            path.write_text(
                "field_world_path = " + json.dumps(str(ROOT / "Source/domain/fieldWorld.lua"))
                + "\n" + PROBE)
            completed = subprocess.run(
                ["lua5.4", str(path)],
                check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)


if __name__ == "__main__":
    unittest.main()
