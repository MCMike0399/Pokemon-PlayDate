#!/usr/bin/env python3
"""A possessive is one pokered tile, not an apostrophe and a letter.

pret/pokered af519899 constants/charmap.asm:

    charmap "'d", $bb
    charmap "'l", $bc
    charmap "'s", $bd
    charmap "'t", $be
    charmap "'v", $bf
    charmap "'r", $e4
    charmap "'m", $e5
    charmap "'",  $e0

Drawing $e0 and then s is two full cells, which reads as "CHARIZARD' s"
on Crunch's DEFENSE line. $bd is the apostrophe and the s in one cell.
The battle box is 18 columns, so the ligature is one column there too.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

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


class LaneEPossessiveTest(unittest.TestCase):
    def test_apostrophe_s_is_one_tile(self):
        probe = Path("/tmp/lane_e_possessive_probe.lua")
        probe.write_text(PROBE)
        completed = subprocess.run(
            ["lua5.4", str(probe)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("possessive-ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
