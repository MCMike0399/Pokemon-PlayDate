"""A new catch shows the dex page, then asks for a nickname, on the battle field."""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PROBE = r"""
function import() end
function Class(name)
    local cls = {}
    cls.__index = cls
    function cls:extends(parent)
        cls.super = parent
        getmetatable(cls).__index = parent
        return cls
    end
    setmetatable(cls, {__call = function(_, ...)
        local instance = setmetatable({}, cls)
        if instance.init then instance:init(...) end
        return instance
    end})
    _G[name] = cls
    return cls
end
Class("State")
function State:init(name) self.name = name end
dofile("Source/game/battleState.lua")

local function run(newDex)
    local pushed = {}
    local asked = {}
    local mon = {species = "rattata", name = "RATTATA"}
    local battle = {
        pendingNickname = {mon = mon, speciesName = "RATTATA"},
        nicknameReady = true,
        caughtNewDex = newDex,
    }
    Story = {
        caughtDexPages = function(name)
            assert(name == "RATTATA", name)
            return {{text = "New DEX data", ending = "done"}}
        end,
        dialogLines = function(pages) return {pages[1].text} end,
        promptNickname = function(_, caught, species)
            asked.caught = caught
            asked.species = species
            return true
        end,
    }
    local state = BattleState({})
    state.battle = battle
    state.machine = {
        push = function(_, name, payload, callback)
            pushed[#pushed + 1] = {name = name, payload = payload, callback = callback}
        end,
    }
    state:openPendingNickname()
    return state, battle, pushed, asked
end

local state, battle, pushed, asked = run(true)
assert(#pushed == 1 and pushed[1].name == "dialog", "new dex starts on the caught text")
assert(asked.species == nil, "nickname waits until the dex page returns")
pushed[1].callback()
assert(pushed[2].name == "pokedex", "the dex page is the real pokedex state")
assert(pushed[2].payload.sourceSpecies == "rattata")
pushed[2].payload.onComplete()
assert(battle.caughtNewDex == nil, "returning from the dex page clears the flag")
state:openPendingNickname()
assert(asked.species == "RATTATA", "AskName follows the dex page")
assert(asked.caught.species == "rattata")

local _, knownBattle, knownPushed, knownAsked = run(false)
assert(#knownPushed == 0, "an owned species skips the dex page")
assert(knownAsked.species == "RATTATA", "AskName still runs")
assert(knownBattle.pendingNickname)
print("capture-followup-ok")
"""

CAMERA = r"""
function import() end
function Class(name)
    local cls = {}
    cls.__index = cls
    setmetatable(cls, {__call = function(_, ...)
        local instance = setmetatable({}, cls)
        if instance.init then instance:init(...) end
        return instance
    end})
    _G[name] = cls
    return cls
end
local offsets = {}
local ox, oy = 40, 18
playdate = {
    graphics = {
        kColorBlack = 0, kColorWhite = 1, kDrawModeCopy = 0,
        font = {new = function() return {} end},
        getDrawOffset = function() return ox, oy end,
        setDrawOffset = function(x, y)
            offsets[#offsets + 1] = {x, y}
            ox, oy = x, y
        end,
        image = {new = function() return {} end},
    },
    display = {setOffset = function() end},
}
dofile("Source/battle/battleScene.lua")
local scene = setmetatable({
    introTimer = 21, introDrawing = false, selectionOpen = true, battle = {},
}, {__index = BattleScene})
scene.drawBattleField = function(self)
    local x, y = playdate.graphics.getDrawOffset()
    assert(x == 0 and y == 0, "battle field left the origin")
    scene.drew = true
end
scene:draw()
assert(scene.drew, "field drew")
assert(offsets[1][1] == 0 and offsets[1][2] == 0, "draw starts at the origin")
assert(offsets[#offsets][1] == 40 and offsets[#offsets][2] == 18, "previous offset returns")
print("battle-origin-ok")
"""


class CaptureFollowupTests(unittest.TestCase):
    def test_new_dex_page_returns_to_the_nickname_prompt(self):
        completed = subprocess.run(
            ['lua5.4', '-e', PROBE], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('capture-followup-ok', completed.stdout)

    def test_owned_flag_is_read_before_recruit_and_the_field_draws_at_the_origin(self):
        text = (ROOT / 'Source/battle/battle.lua').read_text()
        body = text.split('function Battle:throwBall', 1)[1].split('function Battle:', 1)[0]
        new_dex = body.index('local newDex=dex.owned[self.enemy.species]~=true')
        recruit = body.index('GameSession.recruit(self.session,self.enemy)')
        caught = body.index('self:say("Gotcha! "')
        nickname = body.index('self.pendingNickname={mon=self.enemy, speciesName=self.enemy.name}')
        self.assertLess(new_dex, recruit)
        self.assertLess(caught, nickname)
        self.assertIn('wPokedexOwned', body)
        self.assertIn('engine/pokemon/add_mon.asm', body)
        completed = subprocess.run(
            ['lua5.4', '-e', CAMERA], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn('battle-origin-ok', completed.stdout)

    def test_there_is_no_invented_pause_before_the_nickname(self):
        text = (ROOT / 'Source/game/battleState.lua').read_text()
        self.assertNotIn('dexHold', text)


if __name__ == '__main__':
    unittest.main()
