#!/usr/bin/env python3
"""Route 22 clip 20261112T214238Z, about 0:17.

After "VENUSAUR grew to Lv53!" the box shows "VENUSAUR is" / "trying to
learn" with YES/NO already open. SOLAR BEAM, "can't learn more than 4
moves!", and "Delete an older move to make room for SOLAR BEAM?" never
appear, and NO goes straight to "Abandon learning".

That is not the harness skipping pages. decline_learn only presses Down
and A once the snapshot phase is already "ask", and the engine opens
that menu inside showAsk. pokered PrintText pages _TryingToLearnText
through a two-line box (<LINE>, <CONT>, <PARA>) and TryingToLearn opens
YES/NO only after PrintText returns on the last page.

The ask path does not use Dialog, so lane-e-battle-message.patch does
not cover it. The same 10-frame hold is in this patch so a mash cannot
turn a page that has not been shown. The patch is not applied here.
Solar Beam at level 53 is the B2W2 learnset; the move name in the data
is "SOLAR BEAM".
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/learningState.lua'
PATCH = ROOT / 'tools/notes/lane-e-learn-pages.patch'

PROBE = r'''
justPressed = false
held = false
down = false
playdate = {
  graphics = {
    kColorWhite = 1, kColorBlack = 0,
    getFont = function() return {} end,
    getSystemFont = function() return { getHeight = function() return 16 end, getLeading = function() return 0 end } end,
    setFont = function() end, setColor = function() end, setDrawOffset = function() end,
    getDrawOffset = function() return 0, 0 end,
    fillRect = function() end, drawRect = function() end, clear = function() end,
    sprite = { addDirtyRect = function() end },
  },
  kButtonA = 1, kButtonB = 2, kButtonDown = 3,
  buttonJustPressed = function(button)
    if button == 3 then return down end
    return justPressed
  end,
  buttonIsPressed = function(button)
    if button == 3 then return down end
    return held
  end,
}
function import() end
function Class(name)
  local cls = {}
  cls.__index = cls
  cls.__name = name
  function cls:extends(parent)
    cls.super = parent
    return cls
  end
  setmetatable(cls, { __call = function(_, ...)
    local instance = setmetatable({}, cls)
    if instance.init then instance:init(...) end
    return instance
  end })
  _G[name] = cls
  return cls
end
Class("State")
function State:init(name) self.name = name end
Class("BattleMenu")
function BattleMenu:init()
  self.options = {}
  self.selectedIndex = 1
  self.isActive = false
end
function BattleMenu:show(options, onSelect, onCancel)
  self.options = options
  self.selectedIndex = 1
  self.isActive = true
  self.onSelect = onSelect
  self.onCancel = onCancel
end
function BattleMenu:hide() self.isActive = false end
function BattleMenu:handleInput()
  if not self.isActive then return end
  if down then self.selectedIndex = math.min(#self.options, self.selectedIndex + 1) end
  if justPressed and self.onSelect then self.onSelect(self.selectedIndex) end
end
function BattleMenu:draw() end
Class("Dialog")
function Dialog:init() self.isActive = false; self.lines = {""}; self.currentLine = 1; self.charIndex = 0 end
function Dialog:show() end
function Dialog:hide() end
function Dialog:update() end
function Dialog:handleInput() end
function Dialog:draw() end
moveData = { solarBeam = { name = "SOLAR BEAM" } }
dofile(arg[1])
local learning = LearningState({})
learning.active = true
learning.pokemon = { name = "VENUSAUR", moves = {"a", "b", "c", "d"} }
learning.pendingMove = "solarBeam"
learning.choiceId = 1
learning:showAsk()
local function line(text)
  io.write((text:gsub("\n", "|")))
  io.write("\n")
end
if not learning.askPages then
  local rows = {}
  for hard in (learning.prompt .. "\n"):gmatch("(.-)\n") do
    rows[#rows + 1] = hard
    if #rows == 2 then break end
  end
  io.write(learning.menu.isActive and "menu-open\n" or "menu-closed\n")
  io.write("page ")
  line(table.concat(rows, "\n"))
  os.exit(0)
end
io.write(learning.menu.isActive and "menu-open\n" or "menu-closed\n")
io.write("page ")
line(learning.askPages[learning.askPage])
local function tap()
  justPressed = false
  held = false
  down = false
  for _ = 1, 11 do learning:handleInput() end
  justPressed = true
  held = true
  learning:handleInput()
  justPressed = false
  held = false
end
local seen = {}
for _ = 1, 8 do
  if learning.menu.isActive then break end
  seen[#seen + 1] = learning.askPages[learning.askPage]
  tap()
end
for _, page in ipairs(seen) do
  io.write("seen ")
  line(page)
end
io.write("final " .. learning.askPage .. " " .. (learning.menu.isActive and "open" or "closed") .. "\n")
io.write("finalpage ")
line(learning.askPages[learning.askPage])
justPressed = false
held = false
down = true
learning:handleInput()
down = false
justPressed = true
learning:handleInput()
io.write("after-no " .. learning.phase .. " ")
line(learning.prompt)
learning:showAsk()
for _ = 1, 40 do
  justPressed = true
  held = true
  down = false
  learning:handleInput()
end
io.write("mash " .. learning.askPage .. " " .. (learning.menu.isActive and "open" or "closed") .. "\n")
'''


def run_probe(source):
    probe = Path('/tmp/lane_e_learn_pages_probe.lua')
    probe.write_text(PROBE)
    return subprocess.run(
        ['lua5.4', str(probe), str(source)], cwd=ROOT, capture_output=True, text=True)


class LearnPageTests(unittest.TestCase):
    def test_current_box_opens_yes_no_on_the_first_two_lines(self):
        completed = run_probe(SOURCE)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('menu-open', completed.stdout)
        self.assertIn('page VENUSAUR is|trying to learn', completed.stdout)
        self.assertNotIn('SOLAR BEAM', completed.stdout.split('page ', 1)[1].split('\n', 1)[0])

    @unittest.expectedFailure
    def test_unpatched_source_reaches_every_page_before_yes_no(self):
        completed = run_probe(SOURCE)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('final 6 open', completed.stdout)
        self.assertIn('finalpage move to make room|for SOLAR BEAM?', completed.stdout)

    def test_patch_pages_the_prompt_and_holds_a_mash(self):
        check = subprocess.run(
            ['git', 'apply', '--check', str(PATCH)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertNotIn('askPages', SOURCE.read_text())
        output = Path('/tmp/lane-e-learning-patched.lua')
        applied = subprocess.run(
            ['patch', '-o', str(output), str(SOURCE), str(PATCH)],
            capture_output=True, text=True)
        self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
        completed = run_probe(output)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        text = completed.stdout
        self.assertIn('menu-closed', text)
        self.assertIn('page VENUSAUR is|trying to learn', text)
        self.assertIn('mash ', text)
        mash = next(line for line in text.splitlines() if line.startswith('mash '))
        page, menu = mash.split()[1:]
        self.assertLess(int(page), 6)
        self.assertEqual(menu, 'closed')
        self.assertIn('seen trying to learn|SOLAR BEAM!', text)
        self.assertIn("seen can't learn more|than 4 moves!", text)
        self.assertIn('seen Delete an older|move to make room', text)
        self.assertIn('final 6 open', text)
        self.assertIn('finalpage move to make room|for SOLAR BEAM?', text)
        self.assertIn('after-no stop Abandon learning|SOLAR BEAM?', text)
        self.assertNotIn('askPages', SOURCE.read_text())


if __name__ == '__main__':
    unittest.main()
