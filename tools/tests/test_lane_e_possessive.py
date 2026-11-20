"""A possessive is one pokered tile.

pret/pokered af519899 constants/charmap.asm maps 's to $bd, one cell.
An ASCII apostrophe plus the letter is two cells, which reads as
"CHARIZARD' s". tools/notes/lane-e-possessive.patch.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-possessive.patch"

PROBE = r'''
function import() end
dofile("Source/game/titleIdle.lua")
local function tiles(text)
  local count, index = 0, 1
  while index <= #text do
    index = TitleIdle.nextTile(text, index)
    count = count + 1
  end
  return count
end
local sheet, index = TitleIdle.glyph("'s")
assert(sheet == "font" and index == 0xbd - 0x80, "s ligature")
local expected = {
  ["'d"] = 0xbb, ["'l"] = 0xbc, ["'s"] = 0xbd, ["'t"] = 0xbe, ["'v"] = 0xbf,
  ["'r"] = 0xe4, ["'m"] = 0xe5,
}
for pair, tile in pairs(expected) do
  local _, glyph = TitleIdle.glyph(pair)
  assert(glyph == tile - 0x80, pair)
  local nextIndex = TitleIdle.nextTile("X" .. pair, 2)
  assert(nextIndex == 2 + #pair, pair .. " width")
end
assert(tiles("CHARIZARD's") == 10, tiles("CHARIZARD's"))
assert(tiles("'") + tiles("s") == 2)
function Class(name)
  local cls = {}
  cls.__index = cls
  setmetatable(cls, { __call = function(_, ...)
    local instance = setmetatable({}, cls)
    if instance.init then instance:init(...) end
    return instance
  end })
  _G[name] = cls
  return cls
end
playdate = { graphics = {} }
dofile("Source/ui/dialog.lua")
local line = Dialog.wrapLine("CHARIZARD's DEFENSE", 18)
assert(#line == 1 and line[1] == "CHARIZARD's DEFENSE", table.concat(line, "|"))
local font = io.open("Source/game/gbFont.lua"):read("*a")
assert(font:find("TitleIdle.nextTile", 1, true), "draw still emits one tile per code")
print("possessive-ok")
'''


def possessive_probe(root):
    probe = Path("/tmp/lane_e_possessive_probe.lua")
    probe.write_text(PROBE)
    return subprocess.run(
        ["lua5.4", str(probe)], cwd=root, capture_output=True, text=True)


class LaneEPossessiveTests(unittest.TestCase):
    def test_patch_applies(self):
        patch = PATCH.read_text()
        self.assertIn('["\'s"] = 0xbd - 0x80', patch)
        self.assertNotIn("MallocPoolSize", patch)

    def test_patched_tree_draws_one_ligature(self):
        probe = possessive_probe(ROOT)
        self.assertEqual(probe.returncode, 0, probe.stdout + probe.stderr)
        self.assertIn("possessive-ok", probe.stdout)

    def test_live_apostrophe_s_is_one_tile(self):
        self.assertIn("function TitleIdle.nextTile", (ROOT / "Source/game/titleIdle.lua").read_text())


if __name__ == "__main__":
    unittest.main()
