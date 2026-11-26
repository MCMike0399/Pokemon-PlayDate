-- Lorelei/Bruno clips: the next queued battle line replaces the one on
-- screen on the same A that finishes the typewriter confirm.
-- pret/pokered af519899 home/print_text.asm PrintLetterDelay and
-- home/joypad.asm WaitForTextScrollButtonPress: the button that
-- acknowledges a page does not also start the next page.
local ROOT = assert(arg[1], "repo path required")
local SOURCE = ROOT .. "/Source/"

local loaded = {}
local function loadPlaydate(path)
    local handle = assert(io.open(path, "r"))
    local source = assert(handle:read("a"))
    handle:close()
    source = source:gsub("([%w_%.]+)%s*([%+%-])=%s*", "%1 = %1 %2 ")
    local chunk, err = load(source, "@" .. path)
    if not chunk then error(err) end
    return chunk
end
function import(name)
    if loaded[name] then return end
    loaded[name] = true
    local ok, problem = pcall(loadPlaydate, SOURCE .. name .. ".lua")
    if not ok then loaded[name] = nil; error(problem) end
    ok, problem = pcall(problem)
    if not ok then loaded[name] = nil; error(problem) end
end

local pressedA, heldA = false, false
playdate = {
    kButtonA = 1, kButtonB = 2, kButtonUp = 3, kButtonDown = 4, kButtonLeft = 5, kButtonRight = 6,
    buttonJustPressed = function(button) return pressedA and button == 1 end,
    buttonIsPressed = function(button) return heldA and button == 1 end,
    datastore = { read = function() return nil end },
    getCrankChange = function() return 0 end,
    display = { setOffset = function() end },
    graphics = setmetatable({
        kColorBlack = 0, kColorWhite = 1, kDrawModeCopy = 0, kImageUnflipped = 0,
        font = { new = function()
            return {
                getHeight = function() return 16 end,
                getLeading = function() return 0 end,
                getTextWidth = function() return 40 end,
            }
        end },
        getFont = function()
            return { getHeight = function() return 16 end, getTextWidth = function() return 40 end }
        end,
        getSystemFont = function()
            return {
                getHeight = function() return 16 end,
                getLeading = function() return 0 end,
                getTextWidth = function(_, text) return #(text or "") * 8 end,
            }
        end,
        image = { new = function()
            return { draw = function() end, getSize = function() return 16, 16 end }
        end },
    }, { __index = function() return function() end end }),
}
import "lib/oop"
import "ui/dialog"
import "ui/crankScroll"
import "ui/menu"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "domain/party"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "domain/decimalInteger"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "battle/battle"
import "game/gameOptions"
import "battle/battleScene"

SourceText = { nextBoundary = function(_, index) return index + 1 end }

local lead = Pokemon("charizard", 50)
local roster = Party()
assert(roster:add(lead))
local battle = Battle(lead, Pokemon("dewgong", 54), "LORELEI", {party = roster})
local first = "LORELEI: You will lose!"
local queued = "BRUNO is about to use ONIX!"
battle:runScript(function()
    battle:say(first)
    battle:say(queued)
end)
local scene = BattleScene(battle)
scene.introPhase = "ready"
scene.introDrawing = false
scene.introTimer = 21

local function tick()
    pressedA, heldA = true, true
    battle:update()
    scene:update()
    scene:handleInput()
end

for frame = 1, 40 do
    tick()
    if battle.message ~= first then
        error("queued say replaced the line on the confirm press at frame " .. frame
            .. ": " .. tostring(battle.message))
    end
    local dialog = scene.messageDialog
    if dialog and not dialog.isActive and scene.messageReady then
        print("queue-held")
        os.exit(0)
    end
end
error("the Lorelei line never finished its confirm")
