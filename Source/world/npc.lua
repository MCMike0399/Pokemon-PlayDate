local gfx <const> = playdate.graphics

class("NPC").extends(gfx.sprite)

function NPC:init(gridX, gridY, name, dialogLines, battleData, spriteKey, facing)
    NPC.super.init(self)

    self.gridX = gridX
    self.gridY = gridY
    self.name = name
    self.dialogLines = dialogLines
    self.battleData = battleData
    self.interacted = false
    self.postBattleLines = nil

    -- Directional frames generated at runtime by SpriteFactory (down/up/
    -- left/right). NPCs default to facing down and turn to the player when
    -- talked to (see faceTowards), Gen 1 style.
    self.images = SpriteFactory.npc[spriteKey or "oak"] or SpriteFactory.npc.oak
    self.facing = facing or "down"
    self:setImage(self.images[self.facing])
    self:setCenter(0, 0)
    -- Drawn 8px above the tile, matching the player's visual offset
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE - 8)
    self:setZIndex(90)
    self:add()
end

-- Turn to face a direction (down/up/left/right)
function NPC:setFacing(dir)
    if self.images[dir] then
        self.facing = dir
        self:setImage(self.images[dir])
    end
end

-- Turn to look at a grid tile (the player's), favoring the larger axis
function NPC:faceTowards(gx, gy)
    local dx, dy = gx - self.gridX, gy - self.gridY
    if math.abs(dx) > math.abs(dy) then
        self:setFacing(dx < 0 and "left" or "right")
    elseif dy ~= 0 or dx ~= 0 then
        self:setFacing(dy < 0 and "up" or "down")
    end
end

-- Dialog defs may be a function (story-stage-dependent lines)
function NPC:getDialogLines()
    local lines = self.dialogLines
    if self.interacted and self.postBattleLines then
        lines = self.postBattleLines
    end
    if type(lines) == "function" then lines = lines() end
    return lines
end

-- Battle defs may be a function too (BLUE's rematch uses the story's
-- counter-pick starter)
function NPC:getBattleData()
    local data = self.battleData
    if type(data) == "function" then data = data() end
    return data
end

-- Interacted state is mirrored onto the zone's npc def so it survives the
-- sprite teardown/respawn that happens when re-entering the overworld
function NPC:markInteracted()
    self.interacted = true
    if self.def then self.def.interacted = true end
end

function NPC:resetInteracted()
    self.interacted = false
    if self.def then self.def.interacted = false end
end

-- NPC manager
Class("NPCManager")

function NPCManager:init()
    self.npcs = {}
end

function NPCManager:addNPC(npc)
    table.insert(self.npcs, npc)
end

function NPCManager:getNPCAt(gx, gy)
    for _, npc in ipairs(self.npcs) do
        if npc.gridX == gx and npc.gridY == gy then
            return npc
        end
    end
    return nil
end

function NPCManager:findByName(name)
    for _, npc in ipairs(self.npcs) do
        if npc.name == name then
            return npc
        end
    end
    return nil
end

-- Remove a single NPC mid-scene (BLUE storming out of the lab)
function NPCManager:removeNPC(npc)
    for i, candidate in ipairs(self.npcs) do
        if candidate == npc then
            table.remove(self.npcs, i)
            npc:remove()
            return
        end
    end
end

function NPCManager:clear()
    for _, npc in ipairs(self.npcs) do
        npc:remove()
    end
    self.npcs = {}
end
