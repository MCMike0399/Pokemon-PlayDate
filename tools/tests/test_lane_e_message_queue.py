#!/usr/bin/env python3
"""Queued battle lines wait until the current one has finished printing.

Rival 2 replaced the next say while the current page was still the one
on screen: EXP after Rhyhorn, EXP after Growlithe, Crunch's DEFENSE
drop, and Skull Bash's "lowered its head!" plus the DEFENSE rise.
Feather Dance and recoil were the same queue. This is not the
mid-reveal mash, which already keeps a finished line up for 10 frames.

pokered home/print_text.asm PrintLetterDelay only shortens the
per-letter wait while A is held. home/joypad2.asm
WaitForTextScrollButtonPress then returns on hJoyPressed, a new edge.
A button that is still down does not install the next say.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIALOG = ROOT / "Source/ui/dialog.lua"
BATTLE = ROOT / "Source/battle/battle.lua"

PROBE = r'''
justPressed = false
held = false
playdate = {
  graphics = { getFont = function() return {} end },
  kButtonA = 1,
  buttonJustPressed = function() return justPressed end,
  buttonIsPressed = function() return held end,
}
function import() end
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
GameOptions = { textSpeed = function() return "FAST" end }
SourceText = { nextBoundary = function(line, index) return index + 1 end }
dofile(arg[1])
local function page(text)
  local done = 0
  local finished = false
  local dialog = Dialog()
  dialog:show({text}, function() done = done + 1 end)
  justPressed = true
  held = true
  dialog:update()
  dialog:handleInput()
  justPressed = false
  held = true
  for _ = 1, 40 do
    dialog:update()
    dialog:handleInput()
    if dialog.isActive and dialog.charIndex >= #dialog.lines[1] then
      finished = true
    end
  end
  return done, finished
end
local cases = {
  "CHARIZARD gained 751 EXP!",
  "CHARIZARD's DEFENSE fell!",
  "BLASTOISE lowered its head!",
  "BLASTOISE's DEFENSE rose!",
  "VENUSAUR is damaged by recoil!",
}
for _, text in ipairs(cases) do
  local done, finished = page(text)
  assert(finished, "line never finished printing: " .. text)
  assert(done == 0, "held A advanced the queue: " .. text)
end
print("queue-held")
'''


class LaneEMessageQueueTest(unittest.TestCase):
    def test_held_a_does_not_advance_the_queue(self):
        probe = Path("/tmp/lane_e_message_queue_probe.lua")
        probe.write_text(PROBE)
        completed = subprocess.run(
            ["lua5.4", str(probe), str(DIALOG)],
            cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("queue-held", completed.stdout)

    def test_script_waits_for_a_new_press(self):
        handler = BATTLE.read_text().split("function BattleScriptPhase:handleInput()", 1)[1]
        handler = handler.split("\nfunction ", 1)[0]
        self.assertIn("buttonJustPressed(playdate.kButtonA)", handler)
        self.assertNotIn("buttonIsPressed", handler)
        self.assertIn("WaitForTextScrollButtonPress", handler)


if __name__ == "__main__":
    unittest.main()
