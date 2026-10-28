import "data/kantoJump"
local gfx <const> = playdate.graphics

class("Player").extends(gfx.sprite)

local MOVE_FRAMES <const> = 8

-- Characters draw 8px above their tile (GB drew sprites 4px up): the head
-- pokes over the tile above and tall grass covers just the legs
local SPRITE_Y_OFFSET <const> = -8

-- Player frames are generated at runtime by SpriteFactory from the same
-- grids the retired PNGs used; the autopilot "atlas" command pixel-diffs
-- them to guarantee parity (down/up/left + right-flip, two walk strides).
local playerImages = SpriteFactory.playerStand
local playerWalk1Images = SpriteFactory.playerWalk1
local playerWalk2Images = SpriteFactory.playerWalk2

-- Tall grass overlay: drawn over the player's legs while in grass (Gen 1
-- style). A splayed rustle variant shows briefly when a step lands in
-- grass (FRLG-style), then settles to the normal overlay.
---@type _Image
local grassOverlayImage
---@type _Image
local grassRustleImage
local function buildOverlayHalf(tile)
    local img = playdate.graphics.image.new(TILE_SIZE, TILE_SIZE // 2)
    gfx.pushContext(img)
    tile:draw(0, -TILE_SIZE // 2)
    gfx.popContext()
    return img
end
local function getGrassOverlay()
    if not grassOverlayImage then
        grassOverlayImage = buildOverlayHalf(TileFactory.tallGrass())
        grassRustleImage = buildOverlayHalf(TileFactory.tallGrassRustle())
    end
    return grassOverlayImage
end

-- Exit arrow (Gen 2/3): a chunky bobbing arrow that appears in the void
-- beside an exit mat, pointing the way out. Authored as a 16x16 silhouette
-- (block shaft + triangular head) and rendered at TILE_SIZE with a 1px
-- black outline so it reads on both the black void and lighter tiles.
local exitArrowImages
local function inArrowRight(x, y)
    if x >= 1 and x <= 7 and y >= 5 and y <= 10 then return true end   -- shaft
    if x >= 7 and x <= 13 then                                         -- head
        local half = 13 - x
        return y >= 7 - half and y <= 7 + half
    end
    return false
end
-- The other three are coordinate transforms of the right-pointing arrow:
-- mirror x for left, transpose for down, transpose+mirror for up
local function inArrowLeft(x, y) return inArrowRight(15 - x, y) end
local function inArrowDown(x, y) return inArrowRight(y, x) end
local function inArrowUp(x, y)   return inArrowRight(15 - y, x) end

local function buildArrow(inFn)
    local scale = TILE_SIZE // 16
    local img = gfx.image.new(TILE_SIZE, TILE_SIZE, gfx.kColorClear)
    gfx.pushContext(img)
    for y = 0, 15 do
        for x = 0, 15 do
            if inFn(x, y) then
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(x * scale, y * scale, scale, scale)
            elseif inFn(x - 1, y) or inFn(x + 1, y) or inFn(x, y - 1) or inFn(x, y + 1) then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(x * scale, y * scale, scale, scale)
            end
        end
    end
    gfx.popContext()
    return img
end

local function getExitArrows()
    if not exitArrowImages then
        exitArrowImages = {
            up = buildArrow(inArrowUp),
            down = buildArrow(inArrowDown),
            left = buildArrow(inArrowLeft),
            right = buildArrow(inArrowRight),
        }
    end
    return exitArrowImages
end

-- Shared read-only images for the visual catalog; uses the gameplay renderer.
Player.getExitArrowImages = getExitArrows

function Player:init(gridX, gridY, collisionMap, npcManager)
    Player.super.init(self)

    self.gridX = gridX
    self.gridY = gridY
    self.facing = "down"
    self.isMoving = false
    self.moveFrames = 0
    self.startPixelX = 0
    self.startPixelY = 0
    self.targetPixelX = 0
    self.targetPixelY = 0
    self.collisionMap = collisionMap
    self.npcManager = npcManager
    self.walkToggle = false  -- alternates lead foot between steps
    self.stepJustFinished = false
    self.rustleFrames = 0    -- grass splay countdown after landing in grass
    self.pendingEdgeDoor = nil  -- edge doors and validated map connections share one queue
    self.isJumping, self.jumpOffset = false, 0
    self.jumpShadow = nil
    self.lastTraversalBlock = nil

    self:setImage(playerImages.down)
    self:setCenter(0, 0)
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE)
    self:setZIndex(100)
    self:add()

    self.grassOverlay = gfx.sprite.new(getGrassOverlay())
    self.grassOverlay:setCenter(0, 0)
    self.grassOverlay:setZIndex(101)
    self.grassOverlay:setVisible(false)
    self.grassOverlay:add()

    self.exitArrow = gfx.sprite.new()
    self.exitArrow:setCenter(0, 0)
    self.exitArrow:setZIndex(102)
    self.exitArrow:setVisible(false)
    self.exitArrow:add()
    self.arrowTimer = 0
end

-- Show the bobbing exit arrow when standing still on an exit-mat tile,
-- in the void tile just past the door, pointing the way out
local ARROW_DELTA <const> = { up = {0,-1}, down = {0,1}, left = {-1,0}, right = {1,0} }

function Player:updateExitArrow()
    local door = (not self.isMoving) and currentZone
        and currentZone:getEdgeDoorAt(self.gridX, self.gridY)
    if not door then
        self.exitArrow:setVisible(false)
        self.arrowTimer = 0
        return
    end

    self.arrowTimer = self.arrowTimer + 1
    local dir = door.edge
    local d = ARROW_DELTA[dir]
    self.exitArrow:setImage(getExitArrows()[dir])
    -- Two-state bob: nudge a few px toward the exit every ~8 frames
    local bob = (math.floor(self.arrowTimer / 8) % 2 == 0) and 0 or 3
    local ax = (self.gridX + d[1]) * TILE_SIZE + d[1] * bob
    local ay = (self.gridY + d[2]) * TILE_SIZE + d[2] * bob
    self.exitArrow:moveTo(ax, ay)
    self.exitArrow:setVisible(true)
end

-- Show the grass overlay on the player's tile when standing in tall grass
function Player:updateGrassOverlay()
    if self.isJumping then self.grassOverlay:setVisible(false); return end
    local onGrass = currentZone and currentZone:isTallGrass(self.gridX, self.gridY)
    self.grassOverlay:setVisible(onGrass or false)
    if onGrass then
        local id = currentZone.tiles[self.gridY + 1][self.gridX + 1]
        if id > 37 then
            local tile = currentZone.registry:renderImported(id, TileFactory.renderGrid)
            if self.importedGrassTile ~= tile then
                self.importedGrassTile = tile
                self.importedGrassOverlay = buildOverlayHalf(tile)
            end
            self.grassOverlay:setImage(self.importedGrassOverlay)
            -- Imported animation needs an explicit source binding; do not
            -- replace its source grass with the authored Pallet rustle.
            self.rustleFrames = 0
        elseif self.rustleFrames > 0 then
            self.rustleFrames = self.rustleFrames - 1
            self.grassOverlay:setImage(grassRustleImage)
        else
            self.grassOverlay:setImage(grassOverlayImage)
        end
        self.grassOverlay:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE + TILE_SIZE // 2)
    end
end

-- All position updates go through here, so the visual offset applies to
-- init, walking interpolation, and debug/autopilot warps alike
function Player:moveTo(x, y)
    Player.super.moveTo(self, x, y + SPRITE_Y_OFFSET)
end

function Player:updateSprite()
    if self.isMoving then
        self:setImage(playerWalk1Images[self.facing])
    else
        self:setImage(playerImages[self.facing])
    end
end

function Player:canMoveTo(gx, gy)
    -- Debug noclip: walk through everything
    if DEBUG_FLAGS and DEBUG_FLAGS.noclip then return true end
    if gx < 0 or gy < 0 then return false end
    if gy + 1 > #self.collisionMap or gx + 1 > #self.collisionMap[1] then return false end
    return self.collisionMap[gy + 1][gx + 1] == 0
end

local jumpShadowImage
local function getJumpShadowImage()
    if not jumpShadowImage then jumpShadowImage=SpriteFactory.makeSprite(KantoJumpData.shadowGrid,{0,0}) end
    return jumpShadowImage
end
Player.getJumpShadowImage=getJumpShadowImage
local function startMove(player,gx,gy,jumping)
    player.isMoving=true;player.moveFrames=0
    player.walkToggle=not player.walkToggle
    player.startPixelX=player.gridX*TILE_SIZE;player.startPixelY=player.gridY*TILE_SIZE
    player.gridX,player.gridY=gx,gy
    player.targetPixelX=gx*TILE_SIZE;player.targetPixelY=gy*TILE_SIZE
    player.isJumping,player.jumpOffset=jumping or false,0
    if jumping then
        player.groundPixelX,player.groundPixelY=player.startPixelX,player.startPixelY
        local image=getJumpShadowImage()
        if not player.jumpShadow then
            player.jumpShadow=gfx.sprite.new(image)
            player.jumpShadow:setCenter(0,0);player.jumpShadow:setZIndex(89);player.jumpShadow:add()
        end
        player.jumpShadow:moveTo(player.startPixelX,player.startPixelY+SPRITE_Y_OFFSET+KantoJumpData.shadowOffsetFromStandingTop)
        player.jumpShadow:setVisible(true)
    end
    player:updateSprite()
end

function Player:tryMove(dx, dy, scriptIntent)
    if self.isMoving then return end
    -- Only the exact, live source escort intent may overlap ambient sprites.
    -- All ordinary callers retain NPC collision, terrain and traversal checks.
    local scripted, guide = false, nil
    if scriptIntent ~= nil then
        if not TutorialEscortPlayer then return end
        scripted, guide = TutorialEscortPlayer.permits(scriptIntent,self,dx,dy)
        if not scripted then return end
    end

    if dy == -1 then self.facing = "up"
    elseif dy == 1 then self.facing = "down"
    elseif dx == -1 then self.facing = "left"
    elseif dx == 1 then self.facing = "right"
    end

    self:updateSprite()

    local targetGX = self.gridX + dx
    local targetGY = self.gridY + dy
    self.lastTraversalBlock=nil
    local noclip=DEBUG_FLAGS and DEBUG_FLAGS.noclip
    -- The explicit mat exit always wins over any boundary connection.
    if not noclip and not self:canMoveTo(targetGX,targetGY) and currentZone then
        local edge=currentZone:getEdgeDoorAt(self.gridX,self.gridY,self.facing)
        if edge then self.pendingEdgeDoor=edge;return end
        local outside=targetGX<0 or targetGY<0 or targetGX>=currentZone.width or targetGY>=currentZone.height
        if outside and KantoWorld then
            local door,reason=KantoWorld.connection(self.npcManager.game,currentZone,self.gridX,self.gridY,self.facing)
            if door then self.pendingEdgeDoor=door;return end
            if reason then self.lastTraversalBlock={kind="connection",id=reason} end
            return
        end
    end

    -- Check for NPC at target position (skip during noclip)
    if not (DEBUG_FLAGS and DEBUG_FLAGS.noclip) then
        local occupant = self.npcManager:getNPCAt(targetGX, targetGY)
        if occupant and (not scripted or occupant == guide) then
            if currentZone and currentZone:isSliceReady() then self.lastTraversalBlock={kind="npc",id="occupied-next-cell"} end
            return
        end
    end

    if not noclip and currentZone and currentZone:isSliceReady() then
        local rule=currentZone:movementRule(self.gridX,self.gridY,self.facing)
        if rule.kind=="ledge" then
            if self.npcManager:getNPCAt(rule.x,rule.y) then
                self.lastTraversalBlock={kind="ledge",id="occupied-landing"};return
            end
            startMove(self,rule.x,rule.y,true);return
        elseif rule.kind=="blocked" then
            self.lastTraversalBlock={kind="terrain",id=rule.reason or "source-collision"};return
        end
    end
    if self:canMoveTo(targetGX, targetGY) then
        startMove(self,targetGX,targetGY,false)
    elseif currentZone then
        -- Walking into the room edge from an exit mat (Gen 2/3 gates):
        -- explore picks this up and starts the door warp
        local door = currentZone:getEdgeDoorAt(self.gridX, self.gridY, self.facing)
        if door then
            self.pendingEdgeDoor = door
        end
    end
end

function Player:update()
    self.stepJustFinished = false

    if self.isMoving then
        self.moveFrames = self.moveFrames + 1
        local jumping=self.isJumping
        local duration=jumping and #KantoJumpData.nativeOffsets or MOVE_FRAMES
        local t = self.moveFrames / duration
        if t >= 1 then
            t = 1
            self.isMoving = false
            self.stepJustFinished = true
            if currentZone and currentZone:isTallGrass(self.gridX, self.gridY) then
                self.rustleFrames = 6
            end
        end

        -- Even Gen 1 cadence: stride for the first half of the step,
        -- standing for the second half. walkToggle alternates the lead
        -- leg between steps: stride A -> stand -> stride B -> stand
        local walkImages = self.walkToggle and playerWalk1Images or playerWalk2Images
        if self.moveFrames <= MOVE_FRAMES // 2 then
            self:setImage(walkImages[self.facing])
        else
            self:setImage(playerImages[self.facing])
        end

        local px = self.startPixelX + (self.targetPixelX - self.startPixelX) * t
        local py = self.startPixelY + (self.targetPixelY - self.startPixelY) * t
        if jumping then
            self.groundPixelX,self.groundPixelY=px,py
            self.jumpOffset=KantoJumpData.nativeOffsets[self.moveFrames]
            self:moveTo(px,py+self.jumpOffset)
            self.jumpShadow:moveTo(px,py+SPRITE_Y_OFFSET+KantoJumpData.shadowOffsetFromStandingTop)
            if not self.isMoving then
                self.isJumping,self.jumpOffset=false,0
                self.jumpShadow:setVisible(false)
            end
        else
            self:moveTo(px, py)
        end
    else
        self:setImage(playerImages[self.facing])
        if self.jumpShadow then self.jumpShadow:setVisible(false) end
    end

    self:updateGrassOverlay()
    self:updateExitArrow()
end

function Player:getFacingTile()
    local dx, dy = 0, 0
    if self.facing == "up" then dy = -1
    elseif self.facing == "down" then dy = 1
    elseif self.facing == "left" then dx = -1
    elseif self.facing == "right" then dx = 1
    end
    return self.gridX + dx, self.gridY + dy
end

function Player:getPixelCenter()
    -- Use actual sprite position (smoothly interpolated during movement)
    if self.isJumping and self.groundPixelX then
        return self.groundPixelX+TILE_SIZE/2,self.groundPixelY+SPRITE_Y_OFFSET+TILE_SIZE/2
    end
    return self.x + TILE_SIZE / 2, self.y + TILE_SIZE / 2
end
function Player:remove()
    if self.jumpShadow then self.jumpShadow:remove(); self.jumpShadow=nil end
    Player.super.remove(self)
end
