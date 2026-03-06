local gfx <const> = playdate.graphics

class("NPC").extends(gfx.sprite)

local TILE_SIZE <const> = 16

-- Pre-load NPC images
local npcImages = {
    oak = gfx.image.new("images/overworld/oak-down"),
    rival = gfx.image.new("images/overworld/rival-down"),
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
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE)
    self:setZIndex(90)
    self:add()
end

function NPC:getDialogLines()
    if self.interacted and self.postBattleLines then
        return self.postBattleLines
    end
    return self.dialogLines
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
