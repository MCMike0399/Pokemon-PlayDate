local gfx <const> = playdate.graphics

class("NPC").extends(gfx.sprite)

-- Pre-load NPC images, scaled 2x for native feel
local npcImages = {
    oak = gfx.image.new("images/overworld/oak-down"):scaledImage(2),
    rival = gfx.image.new("images/overworld/rival-down"):scaledImage(2),
    mom = gfx.image.new("images/overworld/mom-down"):scaledImage(2),
    daisy = gfx.image.new("images/overworld/daisy-down"):scaledImage(2),
}

function NPC:init(gridX, gridY, name, dialogLines, battleData, spriteKey)
    NPC.super.init(self)

    self.gridX = gridX
    self.gridY = gridY
    self.name = name
    self.dialogLines = dialogLines
    self.battleData = battleData
    self.interacted = false
    self.postBattleLines = nil

    local img = npcImages[spriteKey or "oak"]
    self:setImage(img)
    self:setCenter(0, 0)
    -- Drawn 8px above the tile, matching the player's visual offset
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE - 8)
    self:setZIndex(90)
    self:add()
end

function NPC:getDialogLines()
    if self.interacted and self.postBattleLines then
        return self.postBattleLines
    end
    return self.dialogLines
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

function NPCManager:clear()
    for _, npc in ipairs(self.npcs) do
        npc:remove()
    end
    self.npcs = {}
end
