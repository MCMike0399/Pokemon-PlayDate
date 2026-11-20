"""Move-learn box opens without the move name.

Charmander E4 clip: "CHARIZARD is trying to learn" and the name is empty.
pret/pokered af519899 data/text/text_4.asm _TryingToLearnText puts
wStringBuffer on the cont immediately after "trying to learn". The box
draw uses askPages[askPage], and page 1 stops before that name.
"""

import subprocess
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Source/game/learningState.lua"

PROBE = textwrap.dedent(r'''
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
      buttonJustPressed = function() return false end,
      buttonIsPressed = function() return false end,
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
    Class("Dialog")
    function Dialog:init() end
    moveData = { flareBlitz = { name = "FLARE BLITZ" } }
    dofile(arg[1])
    local learning = LearningState({})
    learning.active = true
    learning.pokemon = { name = "CHARIZARD", moves = {"a", "b", "c", "d"} }
    learning.pendingMove = "flareBlitz"
    learning:showAsk()
    local drawn = learning.askPages[learning.askPage]
    if not drawn:find("FLARE BLITZ", 1, true) then
      io.write("opened box omitted the move name: ")
      io.write((drawn:gsub("\n", "|")))
      io.write("\n")
      os.exit(1)
    end
    io.write("learn-name-shown\n")
''')


class LearnNameTests(unittest.TestCase):
    def test_opened_box_names_the_move(self):
        completed = subprocess.run(
            ["lua5.4", "-", str(SOURCE)],
            input=PROBE, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("learn-name-shown", completed.stdout)


if __name__ == "__main__":
    unittest.main()
