local gfx <const> = playdate.graphics

camera = {
    x = 0,
    y = 0
}

function camera.follow(targetX, targetY, mapPixelW, mapPixelH)
    local screenW = 400
    local screenH = 240

    camera.x = targetX - screenW / 2
    camera.y = targetY - screenH / 2

    -- Clamp to map bounds
    if camera.x < 0 then camera.x = 0 end
    if camera.y < 0 then camera.y = 0 end
    if camera.x > mapPixelW - screenW then camera.x = mapPixelW - screenW end
    if camera.y > mapPixelH - screenH then camera.y = mapPixelH - screenH end
end

function camera.apply()
    gfx.setDrawOffset(-camera.x, -camera.y)
end

function camera.reset()
    gfx.setDrawOffset(0, 0)
end
