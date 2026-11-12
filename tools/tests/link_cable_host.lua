-- Press USE on LINK CABLE through the bag and the party, then let the
-- evolution animation finish. Kadabra becomes Alakazam and the cable is gone.
local ROOT = assert(arg[1], "repo path required")
local SOURCE = ROOT .. "/Source/"

local loaded = {}
local function loadPlaydate(path)
    local handle = assert(io.open(path, "r"))
    local source = assert(handle:read("a"))
    handle:close()
    source = source:gsub("([%w_%.]+)%s*([%+%-])=%s*", "%1 = %1 %2 ")
    return assert(load(source, "@" .. path))
end
function import(name)
    if loaded[name] then return end
    loaded[name] = true
    local ok, problem = pcall(loadPlaydate, SOURCE .. name .. ".lua")
    if not ok then loaded[name] = nil; error(problem) end
    local chunk = problem
    ok, problem = pcall(chunk)
    if not ok then loaded[name] = nil; error(problem) end
end

local just, held = {}, {}
local image = {
    getSize = function() return 40, 40 end,
    sample = function() return 0 end,
    draw = function() end,
    drawScaled = function() end,
}
playdate = {
    kButtonA = 1, kButtonB = 2, kButtonUp = 3, kButtonDown = 4,
    kColorWhite = 0, kColorBlack = 1,
    buttonJustPressed = function(button) return just[button] == true end,
    buttonIsPressed = function(button) return held[button] == true end,
    getCrankChange = function() return 0 end,
    isCrankDocked = function() return true end,
    datastore = {read = function() return nil end, write = function() return true end},
    graphics = {
        kColorWhite = 0, kColorBlack = 1,
        font = {new = function() return {} end},
        image = {new = function() return image end},
        getFont = function() return {} end,
        setFont = function() end,
        getTextSizeForMaxWidth = function() return 80, 14 end,
        setDrawOffset = function() end,
        getDrawOffset = function() return 0, 0 end,
        clear = function() end,
        setColor = function() end,
        fillRect = function() end,
        drawRect = function() end,
        drawText = function() end,
        drawPixel = function() end,
        pushContext = function() end,
        popContext = function() end,
        sprite = {addDirtyRect = function() end},
    },
}
SourceText = {nextBoundary = function(_, index) return index + 1 end}
SourceTextFont = {
    paginate = function(text) return {text} end,
    width = function(text) return #text end,
}

import "lib/oop"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "data/items"
import "data/evolutionData"
import "domain/party"
import "domain/inventory"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "domain/decimalInteger"
import "domain/fieldTravel"
import "domain/safariGame"
import "domain/coinWallet"
import "domain/worldMotion"
import "domain/storage"
import "domain/itemStorage"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "domain/gameSession"
import "game/daycare"
import "domain/evolution"
import "domain/teaching"
import "ui/menu"
import "ui/dialog"
import "game/partyState"
import "game/bagState"
import "game/evolutionState"

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected " .. tostring(expected) .. " got " .. tostring(actual))
    end
end
local function samePlace(location)
    return {zone_id = location.zone_id, x = location.x, y = location.y, facing = location.facing}
end
local session = GameSession.newSession({
    itemDefinitions = ItemData.definitions,
    validateWorld = function(world) return world end,
    resolveLocation = samePlace,
    resolvePlayerLocation = samePlace,
}, {location = {zone_id = "reds_house_2f", x = 5, y = 3, facing = "up"}})
local mon = Pokemon("kadabra", 16)
assert(session:recruit(mon), "recruit kadabra")
assert(session:inventory():add("linkCable", 1), "add the cable")
eq(session:inventory():quantity("linkCable"), 1, "one cable")

PokemonArt = PokemonArt or {path = function(species, view) return "images/pokemon/" .. species .. "-" .. view end}
local game = {session = session, machine = StateMachine()}
function game:offerPartyProgression() return true end
game.machine:register("overworld", State("overworld"))
game.machine:register("party", PartyState(game))
game.machine:register("bag", BagState(game))
game.machine:register("evolution", EvolutionState(game))
game.machine:change("overworld")
game.machine:push("bag")

local function press(button)
    just, held = {[button] = true}, {[button] = true}
    game.machine:update()
    game.machine:handleInput()
    just, held = {}, {}
end
local function frames(count)
    for _ = 1, count do
        just, held = {}, {}
        game.machine:update()
        game.machine:handleInput()
    end
end

eq(game.machine:current().name, "bag", "bag is open")
press(playdate.kButtonA) -- the only stack
press(playdate.kButtonA) -- USE
eq(game.machine:current().name, "party", "party asks which Pokemon")
press(playdate.kButtonA) -- Kadabra, the lead
eq(game.machine:current().name, "evolution", "the stone opens the evolution")
-- Dialog:handleInput finishes a line on A, then keeps the complete page up
-- for 10 frames before a later A can turn it. home/text.asm PrintLetterDelay
-- and home/joypad2.asm WaitForTextScrollButtonPress.
press(playdate.kButtonA) -- finish the "is evolving" line
frames(12)
press(playdate.kButtonA) -- leave that box; the 120-frame animation starts
frames(120)
eq(mon.species, "alakazam", "Kadabra evolved")
eq(session:inventory():quantity("linkCable"), 0, "the cable was consumed")
press(playdate.kButtonA) -- finish the result line
frames(12)
press(playdate.kButtonA) -- leave that box
eq(game.machine:current().name, "bag", "the bag returns after the evolution")
print("link-cable-host ok")
