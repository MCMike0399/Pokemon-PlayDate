-- Host driver for Full Heal and Paralyz Heal. Not part of the Playdate build.
-- Both items cure paralysis in the bag and through Battle:useItem.
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

playdate = {
    kButtonA = 1, kButtonB = 2, kButtonUp = 3, kButtonDown = 4,
    buttonJustPressed = function() return false end,
    buttonIsPressed = function() return false end,
    datastore = { read = function() return nil end, write = function() return true end },
    graphics = {
        sprite = { add = function() end, remove = function() end },
        setColor = function() end, fillRect = function() end, drawText = function() end,
        image = { new = function() return { draw = function() end } end },
    },
    getCurrentTimeMilliseconds = function() return 0 end,
    getSecondsSinceEpoch = function() return 0 end,
}

import "lib/oop"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "domain/party"
import "domain/storage"
import "data/items"
import "domain/inventory"
import "domain/items"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "domain/decimalInteger"
import "domain/worldMotion"
import "domain/itemStorage"
import "domain/coinWallet"
import "domain/safariGame"
import "domain/fieldTravel"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "game/daycare"
import "battle/battle"

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected " .. tostring(expected) .. " got " .. tostring(actual))
    end
end

local function paralyzed(species, level)
    local mon = Pokemon(species, level)
    mon.status = "paralyze"
    mon.hp = 5
    return mon
end

local function bagWith(id)
    local inventory = Inventory(ItemData.definitions)
    assert(inventory:add(id, 1))
    return inventory
end

-- Out of battle: the medicine planner itself.
for _, status in ipairs({"paralyze", "burn", "poison", "badPoison", "sleep", "freeze"}) do
    local mon = Pokemon("hypno", 41)
    mon.hp = 5
    mon.status = status
    if status == "sleep" then mon.statusTurns = 2; mon.sleepDuration = 3 end
    local inventory = bagWith("fullHeal")
    local ok, plan = Items.use(inventory, "fullHeal", mon)
    eq(ok, true, "full heal out of battle on " .. status)
    eq(mon.status, nil, "full heal clears " .. status)
    eq(mon.hp, 5, "full heal does not change HP")
    eq(plan.statusCured, status, "full heal reports " .. status)
end

local confused = Pokemon("hypno", 41)
confused.hp = 5
confused.confusion = 2
local confusionBag = bagWith("fullHeal")
eq(Items.use(confusionBag, "fullHeal", confused), true, "full heal clears confusion")
eq(confused.confusion, nil, "confusion is gone")

local specific = paralyzed("hypno", 41)
local specificBag = bagWith("parlyzHeal")
eq(Items.use(specificBag, "parlyzHeal", specific), true, "paralyz heal out of battle")
eq(specific.status, nil, "paralyz heal clears paralysis")
eq(specific.hp, 5, "paralyz heal does not change HP")

local wrong = Pokemon("hypno", 41)
wrong.status = "burn"
wrong.hp = 5
local wrongBag = bagWith("parlyzHeal")
local refused, reason = Items.use(wrongBag, "parlyzHeal", wrong)
eq(refused, false, "paralyz heal does not cure a burn")
eq(reason, "no-effect", "a healthy-for-this-item target is no-effect")
eq(wrong.status, "burn", "the burn stays")

-- In battle: Battle:useItem goes through the same planner on the party slot.
local function session()
    local created = GameSession.newSession({
        validateWorld = function(value) return value end,
        resolveLocation = function(value) return value end,
        itemDefinitions = ItemData.definitions,
    }, {
        world = {schema = 1, zones = {}, zone_count = 0},
        location = {zone_id = "pokered:PALLET_TOWN", x = 0, y = 0, facing = "down"},
        seed = 1,
    })
    assert(created:activateRNG())
    return created
end

local function drain(battle)
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 40 then error("battle script did not finish: " .. tostring(battle.message)) end
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
end

local function battleWith(item, apply)
    local owner = session()
    local player = Pokemon("hypno", 41)
    local enemy = Pokemon("hitmonchan", 55)
    apply(player)
    assert(owner:party():add(player))
    assert(owner:inventory():add(item, 1))
    local battle = Battle(player, enemy, "BRUNO", {party = owner:party(), session = owner})
    drain(battle)
    eq(battle:phase(), "command", "ready for an item")
    assert(battle:beginSelection("bag"))
    local ok, result = battle:useItem(item, 1)
    return ok, result, player, owner
end

local battleOk, battlePlan, battleMon = battleWith("fullHeal", function(mon)
    mon.status = "paralyze"
    mon.hp = 5
end)
eq(battleOk, true, "full heal in battle")
eq(battleMon.status, nil, "battle full heal clears paralysis")
eq(battleMon.hp, 5, "battle full heal keeps HP")
eq(battlePlan.statusCured, "paralyze", "battle full heal reports paralysis")

local parOk, _, parMon = battleWith("parlyzHeal", function(mon)
    mon.status = "paralyze"
    mon.hp = 5
end)
eq(parOk, true, "paralyz heal in battle")
eq(parMon.status, nil, "battle paralyz heal clears paralysis")
eq(parMon.hp, 5, "battle paralyz heal keeps HP")

print("status-cure-items-host ok")
