import "game/optionsState"
import "game/namingState"
import "game/introMovie"
import "game/gbFont"
local gfx <const> = playdate.graphics

Class("TitleState"):extends(State)

function TitleState:init(game)
    TitleState.super.init(self, "title")
    self.game = game
    self.menu = BattleMenu()
    self.logo = assert(gfx.image.new("images/title/logo"))
    self.versionArt = assert(gfx.image.new("images/title/blue"))
    self.playerSheet = assert(gfx.image.new("images/title/player"))
    self.ballTile = self:cutBallTile()
    self.idleArt = {}
    self.idle = TitleIdle.start()
    self.introDone = false
    if game.machine and not game.machine:get("naming") and NamingState then
        game.machine:register("naming", NamingState(game))
    end
    if game.machine and not game.machine:get("oak") and OakSpeechState then
        game.machine:register("oak", OakSpeechState(game))
    end
end

function TitleState:cutBallTile()
    local col, row = TitleIdle.ballTile()
    local tile = TitleIdle.TILE
    local image = gfx.image.new(tile, tile, gfx.kColorWhite)
    gfx.pushContext(image)
    self.playerSheet:draw(-col * tile, -row * tile)
    gfx.popContext()
    return image
end

function TitleState:enter(options)
    if self.game.session then
        self.game.session:disablePlayTime()
    end
    gfx.sprite.removeAll()
    self.game.camera:reset()
    self.epoch = (self.epoch or 0) + 1
    self.message = nil
    self.idle = TitleIdle.start()
    self.menu:hide()
    self.menuDelay = 0
    self.afterRefresh = nil
    self.startupReady = not (options and options.preparing)
    if not self.introDone then
        self.intro = IntroMovie.start()
        self.phase = "intro"
        IntroMovie.sound("intro")
    else
        self.phase = "preparing"
        if self.startupReady then self:finishStartup() end
    end
end

function TitleState:finishStartup()
    self.startupReady = true
    if self.phase ~= "preparing" or not self:isTop() then return end
    self:refresh()
end

function TitleState:showTitle()
    self.phase = "title"
    self.menu:hide()
    self.menuDelay = 0
    -- engine/movie/title.asm plays MUSIC_TITLE_SCREEN after the version scroll.
    TitleIdle.playMusic()
end

function TitleState:refresh()
    self.epoch = (self.epoch or 0) + 1
    local epoch = self.epoch
    self.phase = "preparing"
    self.menu:hide()
    self.candidate, self.metadata = nil, nil
    return GameBootstrap.withLoading("title.inspect", function()
        local candidate, metadata
        if self.game.saves.prepareTitle then
            -- This optional hook retains fully decoded inactive owners, with
            -- all untrusted-load validators and constructor checks intact.
            candidate, metadata = self.game.saves:prepareTitle()
        else
            candidate, metadata = self.game.saves:inspect()
        end
        if epoch ~= self.epoch or not self:isTop() then return end
        if candidate then
            BootTrace.mark("title.map.prepare.begin")
            local provider = WorldDeltas.definitionProvider()
            local key = provider and provider:keyForID(candidate:location().zone_id)
            -- Existing bounded cache only: no zone switch, durable deltas,
            -- RNG activation, actors or second runtime/view are installed.
            if key then provider:ensure(key) end
            BootTrace.mark("title.map.prepare.end")
        end
        if epoch ~= self.epoch or not self:isTop() then return end
        self.candidate, self.metadata = candidate, metadata
        if self.afterRefresh == "menu" then
            self.afterRefresh = nil
            self:openMainMenu()
        else
            self:showTitle()
        end
    end, function()
        self:draw()
        return true
    end)
end

function TitleState:openMainMenu()
    local epoch = self.epoch
    local labels, actions = {}, {}
    local function add(text, action)
        labels[#labels + 1], actions[#actions + 1] = text, action
    end
    -- main_menu.asm ContinueText / NewGameText. Recovery rows are the
    -- Playdate save store; they follow OPTION so the source rows stay first.
    local source = TitleIdle.mainMenu(self.candidate ~= nil)
    for _, text in ipairs(source) do
        local action = text == "CONTINUE" and "continue" or text == "NEW GAME" and "new" or "options"
        add(text, action)
    end
    if self.metadata and self.metadata.reason == "recoverable-candidate" then
        add("RECOVER SAVE", "candidate")
    elseif self.candidate and self.metadata and (self.metadata.hasCorruption or self.metadata.pendingCandidate) then
        add("REPAIR SAVE", "published")
    end
    if self.metadata and self.metadata.proposalAvailable then add("RECOVER NEW SAVE", "proposal") end
    if self.metadata and self.metadata.backupPublished then add("RESTORE BACKUP", "backup-published") end
    if self.metadata and self.metadata.backupCandidate then add("RESTORE CANDIDATE", "backup-candidate") end
    self.actions = actions
    self.phase = "menu"
    self.menuDelay = TitleIdle.MENU_DELAY
    self.menu:show(labels, function(index)
        if self.epoch == epoch and self:isTop() and self.phase == "menu" and self.menuDelay == 0 then
            self:choose(actions[index])
        end
    end, function()
        if self.epoch == epoch and self:isTop() and self.phase == "menu" and self.menuDelay == 0 then
            self:showTitle()
        end
    end)
end

function TitleState:continueInfo(session)
    local flags = {}
    if session.questFlag then
        for _, id in ipairs(TitleIdle.BADGE_FLAGS) do
            flags[id] = session:questFlag(id) == true
        end
    end
    local owned = 0
    if session.pokedex then
        local dex = session:pokedex()
        for _, value in pairs(dex.owned or {}) do
            if value then owned = owned + 1 end
        end
    end
    local clock = session.playTime and session:playTime() or {hours = 0, minutes = 0}
    local name = Story.playerName(self.game)
    return {
        {label = "PLAYER", value = name},
        {label = "BADGES", value = string.format("%2d", TitleIdle.countFlags(flags))},
        {label = "POKéDEX", value = string.format("%3d", owned)},
        {label = "TIME", value = TitleIdle.playTimeText(clock.hours, clock.minutes)},
    }
end

function TitleState:choose(action)
    if not self:isTop() or self.phase ~= "menu" then return end
    local epoch = self.epoch
    local function current(phase)
        return self.epoch == epoch and self:isTop() and self.phase == phase
    end
    if action == "options" then
        self.machine:push("options")
    elseif action == "continue" then
        self.phase = "continue-info"
        self.menuDelay = TitleIdle.CONTINUE_DELAY
        self.info = self:continueInfo(self.candidate)
    elseif action == "new" then
        self.phase = "confirm-new"
        self.menu:show({"NO", "YES"}, function(index)
            if not current("confirm-new") then return end
            if index == 1 then self.afterRefresh = "menu"; self:refresh(); return end
            local ok = self.game.saves:beginNewGame(RulesRNG.snapshot().seed)
            if ok then Story.beginOakSpeech(self.game)
            else self:showMessage("The new adventure could not be started.") end
        end, function()
            if current("confirm-new") then self.afterRefresh = "menu"; self:refresh() end
        end)
    else
        self.phase = "confirm-recovery"
        self.menu:show({"NO", "YES"}, function(index)
            if not current("confirm-recovery") then return end
            if index == 1 then self.afterRefresh = "menu"; self:refresh(); return end
            local ok = self.game.saves:recover(action)
            self:showMessage(ok and "Your save has been recovered." or "The save could not be recovered.")
        end, function()
            if current("confirm-recovery") then self.afterRefresh = "menu"; self:refresh() end
        end)
    end
end

function TitleState:confirmContinue()
    local saves = self.game.saves
    local continueGame = saves.continuePreparedTitle or saves.continueGame
    local ok = continueGame(saves)
    if not ok then self:showMessage("The save could not be opened.") end
end

function TitleState:showMessage(message)
    if not self:isTop() then return end
    self.phase, self.message = "message", message
    self.menu:hide()
    self.afterRefresh = "menu"
end

function TitleState:exit()
    self.epoch = (self.epoch or 0) + 1
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.candidate = nil
    if self.game.saves and self.game.saves.discardPreparedTitle then
        self.game.saves:discardPreparedTitle()
    end
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function TitleState:monImage()
    local species = self.idle.species
    local image = self.idleArt[species]
    if not image then
        image = assert(gfx.image.new(PokemonArt.path(species, "front")), "missing title mon: " .. species)
        self.idleArt[species] = image
    end
    return image
end

function TitleState:introSheet(name, width)
    self.introArt = self.introArt or {}
    local key = name .. ":" .. tostring(width or "full")
    local image = self.introArt[key]
    if image == nil then
        local sheet = gfx.image.new("images/title/intro/" .. name)
        if sheet and width then
            local _, height = sheet:getSize()
            local frame = gfx.image.new(width, height, gfx.kColorWhite)
            gfx.pushContext(frame)
            sheet:draw(0, 0)
            gfx.popContext()
            image = frame
        else
            image = sheet or false
        end
        self.introArt[key] = image
    end
    if image then return image end
end

function TitleState:update()
    -- lane-f b9634998. Same bed as the audio observer, so a repeat is a no-op.
    if KantoAudio and KantoAudio.playCue and self.phase ~= "closed" then
        KantoAudio.playCue("title")
    end
    if not self:isTop() then return end
    if self.phase == "intro" then
        local pressed = playdate.buttonJustPressed(playdate.kButtonA) or false
        IntroMovie.advance(self.intro, pressed)
        if self.intro.done then
            self.introDone = true
            self.phase = "preparing"
            if self.startupReady then self:refresh() end
        end
        return
    end
    if self.phase == "title" then
        TitleIdle.advance(self.idle, function(count) return math.random(count) end)
    elseif (self.phase == "menu" or self.phase == "continue-info") and self.menuDelay > 0 then
        self.menuDelay = self.menuDelay - 1
    end
end

function TitleState:handleInput()
    if self.phase == "preparing" or self.phase == "closed" or self.phase == "intro" then return end
    if self.menuDelay > 0 then return end
    if self.phase == "title" then
        -- CheckForUserInterruption accepts A or Start. Playdate uses A.
        if playdate.buttonJustPressed(playdate.kButtonA) then
            self:openMainMenu()
        end
    elseif self.phase == "continue-info" then
        if playdate.buttonJustPressed(playdate.kButtonA) then
            self:confirmContinue()
        elseif playdate.buttonJustPressed(playdate.kButtonB) then
            self:openMainMenu()
        end
    elseif self.phase == "message" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
            self.phase, self.message = "preparing", nil
            self:refresh()
        end
    else
        self.menu:handleInput()
    end
end

function TitleState:fitted(cache, key, source, width, height)
    local image = cache[key]
    if image then return image end
    image = gfx.image.new(width, height, gfx.kColorWhite)
    local sourceWidth, sourceHeight = source:getSize()
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    for y = 0, height - 1 do
        local sourceY = math.floor(y * sourceHeight / height)
        for x = 0, width - 1 do
            local sourceX = math.floor(x * sourceWidth / width)
            if source:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(x, y)
            end
        end
    end
    gfx.popContext()
    cache[key] = image
    return image
end

function TitleState:copyrightSheets()
    if self.copyrightArt then return self.copyrightArt end
    self.copyrightArt = {
        copyright = assert(gfx.image.new("images/title/font/copyright_tiles"), "missing Nintendo copyright tiles"),
        gamefreak = assert(gfx.image.new("images/title/font/gamefreak_inc"), "missing Game Freak tiles"),
        cells = {},
    }
    return self.copyrightArt
end

function TitleState:copyrightCell(sheetName, index)
    local sheets = self:copyrightSheets()
    local key = sheetName .. ":" .. index
    local cached = sheets.cells[key]
    if cached then return cached end
    local source = sheets[sheetName]
    -- Clear, not white, so a repeated tile drawn over Red keeps his pixels
    -- everywhere the glyph itself is blank.
    local image = gfx.image.new(TitleIdle.COL, TitleIdle.ROW)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    for y = 0, TitleIdle.ROW - 1 do
        local sourceY = math.floor(y * 8 / TitleIdle.ROW)
        for x = 0, TitleIdle.COL - 1 do
            local sourceX = index * 8 + math.floor(x * 8 / TitleIdle.COL)
            if source:sample(sourceX, sourceY) == gfx.kColorBlack then
                gfx.drawPixel(x, y)
            end
        end
    end
    gfx.popContext()
    sheets.cells[key] = image
    return image
end

function TitleState:drawCopyright()
    local origin = TitleIdle.copyrightRect()
    for index, tile in ipairs(TitleIdle.COPYRIGHT_TILES) do
        local sheetName, sourceIndex = TitleIdle.copyrightSource(tile)
        self:copyrightCell(sheetName, sourceIndex):draw(origin.x + (index - 1) * TitleIdle.COL, origin.y)
    end
end

function TitleState:drawTitleArt()
    local layout = TitleIdle.LAYOUT
    self.logo:drawScaled(layout.logo.x, layout.logo.y, layout.logo.scale)
    self.versionArt:drawScaled(layout.version.x, layout.version.y, layout.version.scale)
    local slot = TitleIdle.titleMonSlot()
    local mon = self:fitted(self.idleArt, self.idle.species .. ":slot", self:monImage(), slot.w, slot.h)
    local dx = math.floor(self.idle.offset * TitleIdle.COL / TitleIdle.TILE)
    gfx.setClipRect(0, slot.y, 400, slot.h)
    mon:draw(slot.x + dx, slot.y)
    gfx.clearClipRect()
    self:drawPlayer()
    self:drawCopyright()
end

function TitleState:drawPlayer()
    self.playerFit = self.playerFit or {}
    local box = TitleIdle.playerRect()
    self:fitted(self.playerFit, "body", self.playerSheet, box.w, box.h):draw(box.x, box.y)
    local col, row = TitleIdle.ballTile()
    local cellX = box.x + col * TitleIdle.COL
    local cellY = box.y + row * TitleIdle.ROW
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(cellX, cellY, TitleIdle.COL, TitleIdle.ROW)
    local packed = TitleIdle.PLAYER_OAM_Y + row * TitleIdle.TILE
    local dy = math.floor((TitleIdle.ballOamY(self.idle) - packed) * TitleIdle.ROW / TitleIdle.TILE)
    self:fitted(self.playerFit, "ball", self.ballTile, TitleIdle.COL, TitleIdle.ROW):draw(cellX, cellY + dy)
end

function TitleState:drawIntroMon(name, col, row)
    local image = self:introSheet(name)
    if image then
        image:draw(col * TitleIdle.COL, row * TitleIdle.ROW)
    end
end

function TitleState:draw()
    self.game.camera:reset()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    if self.phase == "intro" then
        IntroMovie.draw(self.intro, gfx)
        local scene = self.intro and IntroMovie.SCENES[self.intro.index]
        if scene and scene.cast then
            -- Blue's FightIntroFrontMon is the jigglypuff pictures.
            -- Gengar is gengar_1/2/3.tilemap placed on the deduped sheet,
            -- not a crop of the first 56px. hSCX stays 0 for this static frame.
            local front = IntroMovie.JIGGLY_AT
            local back = IntroMovie.GENGAR_AT
            if scene.cast == "nidorino" or scene.cast == "both" then
                self:drawIntroMon(IntroMovie.frontFrame(scene.id), front.col, front.row)
            end
            if scene.cast == "gengar" or scene.cast == "both" then
                self:drawIntroMon(IntroMovie.backFrame(scene.id), back.col, back.row)
            end
        end
        return
    end
    if self.phase == "title" or self.phase == "preparing" then
        self:drawTitleArt()
        if self.phase == "preparing" then
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(8, 200, 360, 32)
            GbFont.drawTight("Preparing adventure...", 16, 206)
        end
        return
    end
    if self.phase == "message" then
        gfx.drawTextInRect(self.message .. "\n\nA: OK", 20, 60, 360, 160)
        return
    end
    if self.phase == "confirm-new" or self.phase == "confirm-recovery" then
        local text = self.phase == "confirm-new"
            and "Start a new adventure?\nOn SAVE, old save files will be kept as a backup before replacement."
            or "Recover this save? Current save files will first be kept as a backup."
        gfx.drawTextInRect(text, 20, 40, 360, 96)
        local box = TitleIdle.textBox(10, 10, 6, 2)
        GbFont.drawBox(box)
        for index, label in ipairs(self.menu.options) do
            local row = 11 + index - 1
            if index == self.menu.selectedIndex then
                GbFont.drawChar(TitleIdle.CURSOR, 11, row)
            end
            GbFont.drawString(label, 12, row)
        end
        return
    end
    local hasSave = self.candidate ~= nil
    local extra = #self.menu.options - #TitleIdle.mainMenu(hasSave)
    GbFont.drawBox(TitleIdle.mainMenuBox(hasSave, extra))
    for index, cell in ipairs(TitleIdle.mainMenuCells(self.menu.options)) do
        if index == self.menu.selectedIndex then
            GbFont.drawChar(TitleIdle.CURSOR, 1, cell.row)
        end
        GbFont.drawString(cell.label, 2, cell.row)
    end
    if self.phase == "continue-info" and self.info then
        local box = TitleIdle.continueBox()
        GbFont.drawBox(box)
        local cells = TitleIdle.continueCells(
            self.info[1].value, tonumber(self.info[2].value), tonumber(self.info[3].value), self.info[4].value)
        for _, cell in ipairs(cells) do
            local spec = nil
            for _, row in ipairs(TitleIdle.CONTINUE_TEXT) do
                if row.label == cell.label then spec = row end
            end
            GbFont.drawString(cell.label, spec.labelCol, spec.row)
            GbFont.drawString(cell.value, spec.valueCol, spec.row)
        end
    end
end

function TitleState:resume()
    self.menu.crank:reset()
end
