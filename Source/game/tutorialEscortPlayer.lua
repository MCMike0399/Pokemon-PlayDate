-- Transient scene cancellation snapshot. No session traversal/checkpoint writes.
TutorialEscortPlayer = {}
local intents = setmetatable({}, {__mode="k"})
local delta = {up={0,-1},down={0,1},left={-1,0},right={1,0},wait={0,0}}
-- Opaque permission for this source route only. It never moves an NPC or
-- changes ordinary Player collision policy. Source CollisionCheckOnLand skips
-- sprite collisions under simulated joypad; retain terrain and guide leases.
function TutorialEscortPlayer.claim(scene)
    local data = TutorialEscortData.get()
    assert(scene.id == data.actors.escort.id and scene:valid() and scene:isTop()
        and scene.phase == "escort-walk" and scene.token, "live escort required")
    local x,y = scene.initialPlayer.x,scene.initialPlayer.y
    local route = assert(data.escort.player_routes[x .. "," .. y], "source entry required")
    local cells = {}
    for index,direction in ipairs(route) do
        cells[index] = {x=x,y=y,direction=direction}
        local d = assert(delta[direction])
        x,y = x+d[1],y+d[2]
    end
    local intent = {}
    intents[intent] = {scene=scene,epoch=scene.epoch,session=scene.session,
        player=scene.player,zone=scene.zone,token=scene.token,cells=cells}
    return intent
end
function TutorialEscortPlayer.permits(intent,player,dx,dy)
    local lease = intents[intent]
    if not lease then return false end
    local s = lease.scene
    if not s:valid() or not s:isTop() or s.phase ~= "escort-walk"
        or s.game.machine:get("tutorial-escort") ~= s or s.epoch ~= lease.epoch
        or s.playerIntent ~= intent or s.token ~= lease.token or s.session ~= lease.session
        or s.player ~= player or player ~= lease.player or s.zone ~= lease.zone
        or not s.game.npcManager.motion:isScriptOwner(lease.token,s)
        or currentZone ~= lease.zone or currentZone.stableID ~= "pokered:PEWTER_CITY" then return false end
    local cell = lease.cells[s.playerIndex]
    if not cell or s.playerRoute[s.playerIndex] ~= cell.direction then return false end
    local d = delta[cell.direction]
    return cell.direction ~= "wait" and player.gridX == cell.x and player.gridY == cell.y
        and dx == d[1] and dy == d[2], s.actor
end
function TutorialEscortPlayer.release(intent) if intent then intents[intent] = nil end end
function TutorialEscortPlayer.capture(player)
    return {x=player.gridX, y=player.gridY, facing=player.facing, walkToggle=player.walkToggle,
        rustleFrames=player.rustleFrames, image=player:getImage()}
end
function TutorialEscortPlayer.restore(player, pose)
    player.gridX, player.gridY = pose.x, pose.y
    player.facing, player.walkToggle = pose.facing, pose.walkToggle
    player.rustleFrames = pose.rustleFrames
    player.isMoving, player.isJumping = false, false
    player.moveFrames, player.jumpOffset = 0, 0
    player.startPixelX, player.targetPixelX = pose.x*TILE_SIZE, pose.x*TILE_SIZE
    player.startPixelY, player.targetPixelY = pose.y*TILE_SIZE, pose.y*TILE_SIZE
    if player.groundPixelX ~= nil then player.groundPixelX = pose.x*TILE_SIZE end
    if player.groundPixelY ~= nil then player.groundPixelY = pose.y*TILE_SIZE end
    if player.jumpShadow then player.jumpShadow:setVisible(false) end
    player.pendingEdgeDoor, player.pendingConnection, player.stepJustFinished = nil, nil, false
    player:moveTo(pose.x*TILE_SIZE, pose.y*TILE_SIZE)
    player:updateSprite()
    player:setImage(pose.image)
end
