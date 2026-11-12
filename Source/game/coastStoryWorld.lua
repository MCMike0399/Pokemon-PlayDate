-- Live calls into CoastStory. Map bodies stay Lane A's manifest.
import "game/coastStory"

CoastStoryWorld = {}

local STEP <const> = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
local OPEN <const> = 0x0e

local enteredMap
local buttons
local arrival

local function quest(session)
    return session:flags().quest
end

local function setCollision(zone, x, y, solid)
    if y < 0 or x < 0 or not zone.collision or not zone.collision[y + 1] or zone.collision[y + 1][x + 1] == nil then
        return
    end
    local row = {}
    for index = 1, #zone.collision[y + 1] do
        row[index] = zone.collision[y + 1][index]
    end
    row[x + 1] = solid and 1 or 0
    zone.collision[y + 1] = row
end

local function setBlock(zone, block, padding)
    for dy = 0, 1 do
        for dx = 0, 1 do
            setCollision(zone, block.x * 2 + dx + padding, block.y * 2 + dy, block.solid)
        end
    end
end

local function applyBlocks(game, map)
    local zone <const> = currentZone
    if not zone then
        return
    end
    local name <const> = SourceMaps.nameForID(map)
    local entry <const> = name and SourceMaps.entry(name)
    local padding <const> = entry and entry.padding or 0
    local flags <const> = quest(game.session)
    if map == "pokered:CINNABAR_GYM" then
        for _, block in ipairs(CoastStory.gymGates(flags)) do
            setBlock(zone, block, padding)
        end
    end
    local doors = CoastStory.mansionDoors(map, flags.EVENT_MANSION_SWITCH_ON == true)
    if doors then
        for _, block in ipairs(doors) do
            setBlock(zone, block, padding)
        end
    end
end

local function fall(game, map, x, y)
    local hole = CoastStory.boulderFall(map, x, y)
    if not hole or game.session:questFlag(hole.flag) then
        return
    end
    game.session:setQuestFlag(hole.flag, true)
end

local function holes(game, player, map)
    local hole = CoastStory.playerHole(map, player.gridX, player.gridY, false)
    if not hole then
        return false
    end
    local entry = SourceMaps.entry(hole.entry)
    if not entry then
        return false
    end
    arrival = { map = hole.map, x = hole.x, y = hole.y }
    player.pendingEdgeDoor = {
        to = entry.key,
        toX = hole.x,
        toY = hole.y,
        facing = "down",
    }
    return true
end

local function current(game, player, map)
    local landed = arrival and arrival.map == map and arrival.x == player.gridX and arrival.y == player.gridY
    if landed then
        arrival = nil
    end
    local row = CoastStory.current(map, player.gridX, player.gridY, quest(game.session), landed)
    if not row or not row.buttons or #row.buttons == 0 then
        return false
    end
    buttons = row.buttons
    return true
end

local function advance(player)
    local step = table.remove(buttons, 1)
    if not step or not STEP[step] then
        buttons = nil
        return false
    end
    local delta <const> = STEP[step]
    player:tryMove(delta[1], delta[2])
    if #buttons == 0 then
        buttons = nil
    end
    if not player.isMoving and not player.pendingEdgeDoor then
        buttons = nil
        return false
    end
    return true
end

local function gymDoor(game, player, map)
    if map ~= "pokered:CINNABAR_ISLAND" then
        return false
    end
    local locked = CoastStory.gymDoor(player.gridX, player.gridY, game.session:inventory():quantity("secretKey") > 0)
    if not locked then
        return false
    end
    player.facing = locked.facing
    player:updateSprite()
    game.machine:push("dialog", locked.text, function()
        if game.player and not game.player.isMoving then
            game.player:tryMove(0, 1)
        end
    end)
    return true
end

local connectionWrapped = false
local DIRECTION_STEP <const> = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }

local function nameForKey(key)
    for _, name in ipairs(SourceMaps.names()) do
        if SourceMaps.entry(name).key == key then
            return name
        end
    end
end

-- KantoWorld and PewterWorld refuse a collision-1 origin, and location
-- resolution refuses a collision-1 arrival. Route 19's west bank is water
-- on both sides (foot $14). Allow that one case while surfing. Land edges
-- and every walking step still use the original connection.
local function surfConnection(game, zone, x, y, direction)
    local step = DIRECTION_STEP[direction]
    if not step or not game or not game.session or not zone then
        return nil
    end
    local travel = game.session:fieldTravelData()
    if not travel or travel.mode ~= "surfing" then
        return nil
    end
    local nextX, nextY = x + step[1], y + step[2]
    if nextX >= 0 and nextY >= 0 and nextX < zone.width and nextY < zone.height then
        return nil
    end
    local name = SourceMaps.nameForID(zone.stableID)
    if not name then
        return nil
    end
    local link = SourceMaps.connection(name, x, y, direction)
    if not link then
        return nil
    end
    local target = nameForKey(link.to)
    if not target then
        return nil
    end
    local origin = SourceMaps.cell(name, x, y).terrain
    local arrival = SourceMaps.cell(target, link.x, link.y).terrain
    local originSet = SourceMaps.descriptor(name).tileset.constant
    local arrivalSet = SourceMaps.descriptor(target).tileset.constant
    if not CoastStory.surfEdge(true, origin, arrival, true) then
        return nil
    end
    if not FieldTravel.surfSurface(origin, originSet) or not FieldTravel.surfSurface(arrival, arrivalSet) then
        return nil
    end
    return {
        to = link.to, toX = link.x, toY = link.y, facing = link.facing,
        connection = true, source = link.source,
    }
end

local function allowSurfConnections()
    if connectionWrapped or not KantoWorld or not KantoWorld.connection then
        return
    end
    local original = KantoWorld.connection
    function KantoWorld.connection(game, zone, x, y, direction)
        local door = surfConnection(game, zone, x, y, direction)
        if door then
            return door
        end
        return original(game, zone, x, y, direction)
    end
    connectionWrapped = true
end

function CoastStoryWorld.install()
    allowSurfConnections()
    SourceEvents.registerWorldHooks("pokered:ROUTE_19:script:coast", {
        onLeave = function()
            enteredMap = nil
            buttons = nil
            return false
        end,
        onEnter = function(game)
            local map <const> = currentZone.stableID
            if enteredMap == map then
                return false
            end
            enteredMap = map
            buttons = nil
            local plan = CoastStory.scriptFlags(map)
            if plan then
                for id in pairs(plan.set or {}) do
                    if not game.session:questFlag(id) then
                        game.session:setQuestFlag(id, true)
                    end
                end
                for id in pairs(plan.clear or {}) do
                    if game.session:questFlag(id) then
                        game.session:setQuestFlag(id, false)
                    end
                end
            end
            applyBlocks(game, map)
            return false
        end,
        explore = function(game)
            local player <const> = game.player
            local map <const> = currentZone.stableID
            if buttons then
                return advance(player)
            end
            local travel = game.lastFieldTravel
            if travel and travel.key == "strength" and travel.kind == "pushed" then
                for _, npc in ipairs(game.npcManager.npcs) do
                    if npc.def and npc.def.source_boulder then
                        fall(game, map, npc.gridX, npc.gridY)
                    end
                end
                game.lastFieldTravel = nil
            end
            if holes(game, player, map) then
                return true
            end
            if current(game, player, map) then
                return advance(player)
            end
            return gymDoor(game, player, map)
        end,
        interact = function(game)
            local key = CoastStory.secretKey()
            if currentZone.stableID ~= key.map then
                return false
            end
            local player <const> = game.player
            local x, y = player:getFacingTile()
            if x ~= key.x or y ~= key.y or game.session:questFlag(key.flag) then
                return false
            end
            local quantity = game.session:inventory():quantity(key.item)
            local ok = game.session:transact(
                { flags = { [key.flag] = false }, items = { [key.item] = quantity } },
                { flags = { [key.flag] = true }, items = { { op = "add", id = key.item, quantity = 1 } } }
            )
            game.machine:push("dialog", ok and { "Found the", "SECRET KEY!" } or { "The bag is full." })
            return true
        end,
    })
end
