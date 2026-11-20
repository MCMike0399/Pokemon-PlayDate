"""Queued battle lines wait for a new A.

pokered home/print_text.asm PrintLetterDelay only shortens the per-letter
wait while A is held. home/joypad2.asm WaitForTextScrollButtonPress then
returns on hJoyPressed, a new edge. A hold that is already down must not
install the next say. tools/notes/lane-e-message-queue.patch.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-message-queue.patch"

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


def queue_probe(dialog_path):
    probe = Path("/tmp/lane_e_message_queue_probe.lua")
    probe.write_text(PROBE)
    return subprocess.run(
        ["lua5.4", str(probe), str(dialog_path)],
        cwd=ROOT, capture_output=True, text=True)


class LaneEMessageQueueTests(unittest.TestCase):
    def test_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertNotIn("MallocPoolSize", PATCH.read_text())

    def test_patched_tree_keeps_a_held_page(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for rel in ("Source/ui/dialog.lua", "Source/battle/battle.lua"):
                dest = root / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_text((ROOT / rel).read_text())
            completed = subprocess.run(
                ["patch", "-p1", "-d", str(root), "-i", str(PATCH)],
                capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            probe = queue_probe(root / "Source/ui/dialog.lua")
            self.assertEqual(probe.returncode, 0, probe.stdout + probe.stderr)
            self.assertIn("queue-held", probe.stdout)
            handler = (root / "Source/battle/battle.lua").read_text()
            handler = handler.split("function BattleScriptPhase:handleInput()", 1)[1]
            handler = handler.split("\nfunction ", 1)[0]
            self.assertIn("buttonJustPressed(playdate.kButtonA)", handler)
            self.assertNotIn("buttonIsPressed", handler)

    @unittest.expectedFailure
    def test_live_held_a_does_not_advance_the_queue(self):
        probe = queue_probe(ROOT / "Source/ui/dialog.lua")
        self.assertEqual(probe.returncode, 0, probe.stdout + probe.stderr)
        handler = (ROOT / "Source/battle/battle.lua").read_text()
        handler = handler.split("function BattleScriptPhase:handleInput()", 1)[1]
        handler = handler.split("\nfunction ", 1)[0]
        self.assertNotIn("buttonIsPressed", handler)


if __name__ == "__main__":
    unittest.main()
