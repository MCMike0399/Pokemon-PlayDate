-- Scripted demonstration, not a Battle/Capture transaction. No GameContext,
-- session, Pokemon constructor or RNG is accepted by this isolated model.
import "battle/captureAnimation"
TutorialDemoArt = {}
local gfx <const> = playdate.graphics
local cache = {}
function TutorialDemoArt.image(name)
    if cache[name] then return cache[name] end
    local art = assert(TutorialEscortData.get().art[name])
    local image = gfx.image.new(art.width * 2, art.height * 2, gfx.kColorWhite)
    gfx.pushContext(image)
    for top = 0, art.height - 1, 16 do
        for left = 0, art.width - 1, 16 do
            local grid = {}
            for row = 1, 16 do
                local source = art.rows[top + row] or ""
                local part = source:sub(left + 1, left + 16)
                grid[row] = part .. string.rep(".", 16 - #part)
            end
            TileFactory.renderGrid(grid, nil, {0,0}):draw(left * 2, top * 2)
        end
    end
    gfx.popContext()
    cache[name] = image
    return image
end
-- New review art only; never installs/replaces shared SpriteFactory mappings.
function TutorialDemoArt.actorFrame(name, index)
    local art = assert(TutorialEscortData.get().art[name])
    assert(index % 1 == 0 and index >= 0 and (index + 1) * 16 <= art.height)
    local grid = {}
    for row = 1, 16 do grid[row] = art.rows[index * 16 + row] end
    return SpriteFactory.makeSprite(grid, {0,0})
end
Class("TutorialDemo")
function TutorialDemo:init()
    self.phase, self.tick, self.closed = "encounter", 0, false
    self.species, self.level = "weedle", 5
end
function TutorialDemo:update()
    if self.closed or self.phase == "caught" then return end
    self.tick = self.tick + 1
    if self.phase == "encounter" and self.tick >= 40 then
        self.phase, self.tick = "command", 0 -- source 80 ticks at 60 Hz
    elseif self.phase == "command" and self.tick >= 25 then
        self.phase, self.tick = "bag", 0 -- source 50 ticks at 60 Hz
    elseif self.phase == "bag" and self.tick >= 30 then
        -- Source item_effects jumps directly to .captured for OLD_MAN.
        -- This receipt drives presentation only; ordinary Gen V Capture is untouched.
        self.animation = CaptureAnimation({ caught=true, critical=false, ballId="pokeBall", displayShakes=3 })
        self.phase = "capture"
    elseif self.phase == "capture" then
        self.animation:update()
        if self.animation.done then self.phase = "caught" end
    end
end
function TutorialDemo:close()
    if self.animation then self.animation:cancel() end
    self.closed = true
end
function TutorialDemo:draw()
    gfx.pushContext()
    gfx.setDrawOffset(0,0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setFont(gfx.getSystemFont())
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    if not self.animation or self.animation:isEnemyVisible() then TutorialDemoArt.image("weedle"):draw(300,20) end
    TutorialDemoArt.image("oldmanBack"):draw(55,80)
    gfx.drawText("WEEDLE   Lv5", 225, 4)
    gfx.drawText("OLD MAN", 20, 145)
    gfx.drawRect(4,178,392,58)
    local text = "Wild WEEDLE appeared!"
    if self.phase == "command" then text = "FIGHT    POKEMON\n> ITEM    RUN"
    elseif self.phase == "bag" then text = "> POKE BALL    x50"
    elseif self.phase == "capture" then text = "OLD MAN used POKE BALL!"
    elseif self.phase == "caught" then text = "All right! WEEDLE was caught!\nA: Continue" end
    gfx.drawTextInRect(text,14,186,374,44)
    if self.animation then self.animation:draw() end
    gfx.popContext()
end
