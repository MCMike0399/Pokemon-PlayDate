-- Transient scene cancellation snapshot. No session traversal/checkpoint writes.
TutorialEscortPlayer = {}
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
