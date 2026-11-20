"""Move name is the next learn page, before YES/NO.

pret/pokered af519899 data/text/text_4.asm _TryingToLearnText puts
wStringBuffer on the cont after "trying to learn". The two-row box cannot
carry that name on the opened page. tools/notes/lane-e-learn-box-name.patch
stays unapplied. E may keep this multi-page contract or widen the box.
"""

import subprocess
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Source/game/learningState.lua"

PROBE = textwrap.dedent(r'''
    local justPressed = false
    local held = false
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
      kButtonA = 1, kButtonB = 2,
      buttonJustPressed = function() return justPressed end,
      buttonIsPressed = function() return held end,
    }
    function import() end
    function Class(name)
      local cls = {}
      cls.__index = cls
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
    function BattleMenu:init() self.isActive = false end
    function BattleMenu:show() self.isActive = true end
    function BattleMenu:hide() self.isActive = false end
    function BattleMenu:handleInput() end
    Class("Dialog")
    function Dialog:init() end
    moveData = { flareBlitz = { name = "FLARE BLITZ" } }
    dofile(arg[1])
    local learning = LearningState({})
    learning.active = true
    learning.pokemon = { name = "CHARIZARD", moves = {"a", "b", "c", "d"} }
    learning.pendingMove = "flareBlitz"
    learning:showAsk()
    if learning.menu.isActive then
      io.write("YES/NO opened before a following page\n")
      os.exit(1)
    end
    local function tap()
      justPressed = false
      held = false
      for _ = 1, 11 do learning:handleInput() end
      justPressed = true
      held = true
      learning:handleInput()
      justPressed = false
      held = false
    end
    local named = false
    for _ = 1, 8 do
      if learning.menu.isActive then break end
      tap()
      local page = learning.askPages[learning.askPage]
      if not learning.menu.isActive and page:find("FLARE BLITZ", 1, true) then
        named = true
      end
    end
    if not named then
      local shown = learning.askPages[learning.askPage]:gsub("\n", "|")
      io.write("move name was not on a following page before YES/NO: ")
      io.write(shown)
      io.write(learning.menu.isActive and " menu-open\n" or " menu-closed\n")
      os.exit(1)
    end
    io.write("learn-name-on-next-page\n")
''')


class LearnNameTests(unittest.TestCase):
    def test_name_is_on_the_following_page_before_yes_no(self):
        completed = subprocess.run(
            ["lua5.4", "-", str(SOURCE)],
            input=PROBE, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("learn-name-on-next-page", completed.stdout)


if __name__ == "__main__":
    unittest.main()
