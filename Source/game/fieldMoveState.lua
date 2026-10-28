local gfx <const> = playdate.graphics
Class("FieldMoveState"):extends(State)

function FieldMoveState:init(game)
    FieldMoveState.super.init(self, "fieldMove")
    self.game = game
    self.menu = BattleMenu()
end

local function failure(reason)
    if reason == "badge-required" then
        return "A new BADGE is required."
    end
    if reason == "nothing-to-cut" or reason == "changed-source-block" then
        return "There isn't anything to CUT!"
    end
    if reason == "already-light" or reason == "darkness-not-installed" then
        return "It's already bright here."
    end
    return "That move can't be used here."
end

function FieldMoveState.open(game, party, mon, key)
    if key == "surf" or key == "strength" or key == "fly" then
        if not FieldTravelState or not game.machine:get("fieldTravel") then
            party.message = "That move can't be used here."
            return false, "field-travel-state-not-installed"
        end
        return FieldTravelState.open(game, party, mon, key)
    end
    local state = game.machine:get("fieldMove")
    if not state then
        party.message = "That move can't be used here."
        return false, "field-state-not-installed"
    end
    local token, reason = FieldMoves.prepare(game, party, mon, key)
    if not token then
        party.message = failure(reason)
        return false, reason
    end
    party.phase = "field-wait"
    party.menu:hide()
    game.machine:push("fieldMove", token, party)
    return true
end

function FieldMoveState:enter(token, party)
    self.visit = (self.visit or 0) + 1
    self.token, self.party, self.session = token, party, self.game.session
    self.phase, self.frame, self.active = "confirm", 0, true
    self.preview = assert(FieldMoves.preview(token))
    self.effect = FieldMoves.effectData()
    self.ground, self.grassPresentation = nil, nil
    if self.preview.kind == "grass" then
        self.grassPresentation = FieldMoveState.prepareGrassPresentation(self.effect, self.preview)
    end
    local visit = self.visit
    local function current()
        return self.active and self.visit == visit and self:isTop() and self.game.session == self.session
            and FieldMoves.isCurrent(token, self)
    end
    self.menu:show({"NO", "YES"}, function(index)
        if not current() then
            return false, "stale-selection"
        end
        if index ~= 2 then
            self:close(false)
            return true
        end
        self.phase, self.frame = "announce", 0
        self.menu:hide()
        return true
    end, function()
        if not current() then
            return false, "stale-selection"
        end
        self:close(false)
        return true
    end)
end

function FieldMoveState:close(success)
    if not self.active or not self:isTop() then
        return
    end
    local party = self.party
    self.machine:pop()
    if success and self.machine:current() == party then
        self.machine:pop()
    elseif self.machine:current() == party and party.active and self.game.session == party.session then
        party:actions()
    end
end

function FieldMoveState:exit()
    if self.token then
        FieldMoves.cancel(self.token)
    end
    self.active, self.phase = false, "closed"
    self.visit = (self.visit or 0) + 1
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.token, self.party, self.session, self.treeFrames = nil, nil, nil, nil
    self.grassPresentation, self.effect = nil, nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function FieldMoveState:update()
    if not self.active or not self:isTop() then
        return
    end
    if not FieldMoves.isCurrent(self.token, self) then
        self:close(false)
        return
    end
    if self.phase ~= "effect" then
        return
    end
    local data = self.effect
    local frames = data.flash_white_frames
    if self.preview.key == "cut" then
        frames = self.preview.kind == "grass" and data.grass_frames // 2 or data.tree_frames
    end
    -- Grass has 32 single-VBlank source positions at nominal 60 Hz, paired
    -- into 16 production 30 Hz updates. Tree/Flash retain their existing 8/3.
    -- Frame zero is presented on the A press; commit after the final interval.
    -- An interrupted overlay leaves terrain and the session unchanged.
    self.frame = self.frame + 1
    if self.frame < frames then
        return
    end
    local ok, reason = FieldMoves.complete(self.token, self)
    self.lastResult = {ok = ok, reason = reason, key = self.preview.key}
    self:close(ok)
end

function FieldMoveState:handleInput()
    if self.phase == "confirm" then
        self.menu:handleInput()
    elseif self.phase == "announce" then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            self:close(false)
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            self.phase, self.frame = "effect", 0
        end
    end
end

local function treeFrames(grid)
    local frames = {}
    for _, palette in ipairs({0xe4, 0x80}) do
        local rows = {}
        for y, row in ipairs(grid) do
            rows[y] = row:gsub("[.12#]", function(code)
                local index = assert(({["."] = 0, ["1"] = 1, ["2"] = 2, ["#"] = 3})[code])
                local shade = (palette >> (index * 2)) & 3
                return (".12#"):sub(shade + 1, shade + 1)
            end)
        end
        local image = TileFactory.renderGrid(rows, nil, {0, 0})
        local mask = gfx.image.new(32, 32, gfx.kColorBlack)
        gfx.pushContext(mask)
        gfx.setColor(gfx.kColorWhite)
        for y, row in ipairs(grid) do
            for x = 1, 16 do
                if row:sub(x, x) ~= "." then
                    gfx.fillRect((x - 1) * 2, (y - 1) * 2, 2, 2)
                end
            end
        end
        gfx.popContext()
        image:setMaskImage(mask)
        frames[#frames + 1] = image
    end
    return frames
end

-- The source leaf is an 8x8 OAM tile, not a synthetic terrain cell.
-- Pad only for the existing 16x16 renderer; the mask removes all padding and
-- original color-zero pixels before either OAM palette is applied.
local function grassFrames(leaf)
    local frames = {}
    for _, palette in ipairs({0xe4, 0x80}) do
        local rows = {}
        local mask = gfx.image.new(32, 32, gfx.kColorBlack)
        gfx.pushContext(mask)
        gfx.setColor(gfx.kColorWhite)
        for y = 1, 16 do
            local row = ""
            for x = 1, 16 do
                local code = y <= 8 and x <= 8 and leaf[y]:sub(x, x) or "."
                local index = assert(({["."] = 0, ["1"] = 1, ["2"] = 2, ["#"] = 3})[code])
                local shade = (palette >> (index * 2)) & 3
                row = row .. (".12#"):sub(shade + 1, shade + 1)
                if code ~= "." then
                    gfx.fillRect((x - 1) * 2, (y - 1) * 2, 2, 2)
                end
            end
            rows[y] = row
        end
        gfx.popContext()
        local padded = TileFactory.renderGrid(rows, nil, {0, 0})
        padded:setMaskImage(mask)
        local image = gfx.image.new(16, 16, gfx.kColorClear)
        gfx.pushContext(image)
        padded:draw(0, 0)
        gfx.popContext()
        frames[palette] = image
    end
    return frames
end

-- Zero-based source sample at the END of each two-VBlank native interval.
-- Native updates 0..15 present source frames 1,3,...31 (positions 2..32).
function FieldMoveState.grassSourceFrame(nativeUpdate)
    assert(Party._integer(nativeUpdate, 0, 15), "bounded grass native update required")
    return nativeUpdate * 2 + 1
end

-- Explicit preparation boundary for gameplay enter and catalog bootstrap.
-- Drawing never allocates a missing art cache or consults a field token.
function FieldMoveState.prepareGrassPresentation(effect, preview)
    assert(effect.grass_frames == 32 and #effect.grass_animation == 32, "source grass timing required")
    local ground, tiles = {}, {}
    for _, cell in ipairs(preview.cells) do
        local key <const> = cell.after
        if not tiles[key] then
            tiles[key] = TileRegistry.renderImportedGrid(assert(FieldMoves.tile(key)).grid, TileFactory.renderGrid)
        end
        ground[#ground + 1] = {x = cell.x, y = cell.y, image = tiles[key]}
    end
    return {
        palettes = grassFrames(effect.grass_leaf), ground = ground,
        animation = effect.grass_animation, target = {x = preview.target.x, y = preview.target.y}
    }
end

function FieldMoveState.drawGrassPresentation(presentation, sourceFrame, ox, oy)
    assert(Party._integer(sourceFrame, 0, 31), "bounded grass source frame required")
    for _, cell in ipairs(presentation.ground) do
        cell.image:draw(cell.x * 32 + ox, cell.y * 32 + oy)
    end
    local animation <const> = presentation.animation[sourceFrame + 1]
    local target <const> = presentation.target
    for _, entry in ipairs(animation.entries) do
        local flip <const> = entry.flip == "x" and gfx.kImageFlippedX or gfx.kImageFlippedY
        presentation.palettes[animation.palette]:draw(target.x * 32 + ox + entry.x * 2,
            target.y * 32 + oy + entry.y * 2, flip)
    end
end

function FieldMoveState:draw()
    if not self.active then
        return
    end
    local ox, oy = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    if self.phase == "effect" then
        if self.preview.key == "flash" then
            -- GBPalWhiteOutWithDelay3, not an invented circular light radius.
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(0, 0, 400, 240)
        elseif self.preview.kind == "grass" then
            FieldMoveState.drawGrassPresentation(self.grassPresentation,
                FieldMoveState.grassSourceFrame(self.frame), ox, oy)
        else
            self.treeFrames = self.treeFrames or treeFrames(self.effect.tree_grid)
            local target = self.preview.target
            local x, y = target.x * 32 + ox, target.y * 32 + oy
            for _, cell in ipairs(self.preview.cells) do
                if cell.x == target.x and cell.y == target.y then
                    local entry = assert(FieldMoves.tile(cell.after))
                    self.ground = self.ground or TileRegistry.renderImportedGrid(entry.grid, TileFactory.renderGrid)
                    self.ground:draw(x, y)
                end
            end
            local image = self.treeFrames[self.frame % 2 == 0 and 2 or 1]
            local shift = (self.frame + 1) * 2
            gfx.setClipRect(x - 16, y, 64, 16)
            image:draw(x + shift, y)
            gfx.setClipRect(x - 16, y + 16, 64, 16)
            image:draw(x - shift, y)
            gfx.clearClipRect()
        end
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(4, 174, 392, 62)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(4, 174, 392, 62)
        local text = self.phase == "confirm" and ("Use " .. self.preview.key:upper() .. "?")
            or (self.preview.name .. " used " .. self.preview.key:upper() .. "!")
        gfx.drawText(text, 14, 184)
        if self.phase == "confirm" then
            self.menu:draw(264, 116, 126, 56)
        else
            gfx.drawText("A: Continue  B: Cancel", 14, 210)
        end
    end
    gfx.setDrawOffset(ox, oy)
end
