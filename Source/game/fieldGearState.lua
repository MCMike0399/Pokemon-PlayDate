-- Bag and registered-item USE share one guarded field controller.
local gfx <const> = playdate.graphics
Class("FieldGearState"):extends(State)

function FieldGearState:init(game)
    FieldGearState.super.init(self, "fieldGear")
    self.game = game
    self.dialog = Dialog()
end

function FieldGearState.open(game, bag, id)
    if not game.machine:get("fieldGear") then
        return false, "field-gear-state-not-installed"
    end
    local token, reason = FieldGearRequests.prepare(game, bag, id)
    if not token then
        return false, reason
    end
    bag.phase = "field-wait"
    bag.menu:hide()
    game.machine:push("fieldGear", token, bag, id)
    return true
end

function FieldGearState:enter(token, bag, id)
    self.active = true
    self.token, self.bag, self.id = token, bag, id
    self.session, self.player, self.zone = self.game.session, self.game.player, currentZone
    self.bagVisit = bag.visit
    self.plan = assert(FieldGearRequests.preview(token))
    self.phase, self.frame, self.done, self.enemy = "cast", 0, false, nil
    self.response, self.art = 0, nil
    self.rules = RulesRNG.snapshot()
    self.position = FieldTravelRuntime.position(self.game)
    self.actors = self.game.npcManager.motion:snapshot()
    self.dialog.isActive = false
end

function FieldGearState:valid()
    return self.active and self:isTop() and self.game.session == self.session
        and self.game.player == self.player and currentZone == self.zone
        and self.bag.active and self.bag.session == self.session and self.bag.visit == self.bagVisit
end

function FieldGearState:showResult(labels, ram)
    local pages = EventText.pagesFrom(labels, CeruleanContent.text, ram)
    local lines = {}
    for _, page in ipairs(pages) do
        lines[#lines + 1] = page.text
    end
    if self.plan.kind == "bicycle" then
        lines = {table.concat(lines, " ")}
    end
    self.phase = "result"
    self.dialog:show(lines, function()
        if self:valid() then
            self.done = true
        end
    end)
end

function FieldGearState:complete()
    local previousImage = self.player:getImage()
    if self.plan.kind == "bicycle" then
        local candidate = self.plan.travel.mode == "bicycle"
            and FieldGearArt.bicycle(self.player.facing, "stand") or SpriteFactory.playerStand[self.player.facing]
        self.player:setImage(candidate)
    end
    local accepted, result = FieldGearRequests.complete(self.token, self)
    if not accepted then
        self.player:setImage(previousImage)
        self.game.lastFieldGear = {kind="failed", item=self.id, reason=tostring(result)}
        self.phase = "result"
        self.dialog:show({"That item could not be used."}, function()
            self.done = true
        end)
        return
    end
    self.game.lastFieldGear = {kind=result.kind, item=self.id,
        receipt=result.receipt and GameSession._copy(result.receipt) or nil}
    if result.kind == "bicycle" then
        local label = result.mode == "bicycle" and "GotOn" or "GotOff"
        self:showResult({"_" .. label .. "BicycleText1", "_" .. label .. "BicycleText2"},
            {wStringBuffer=ItemData.definitions.bicycle.name})
    elseif result.kind == "encounter" then
        self.enemy = result.pokemon
        self.response, self.phase = 1, "bite"
    else
        self:showResult({result.kind == "no-fish" and "_NothingHereText" or "_NoNibbleText"})
    end
end

function FieldGearState:close(success)
    local game, bag, enemy = self.game, self.bag, success and self.enemy
    local session, position, actors, rules = self.session, self.position, self.actors, self.rules
    self.machine:pop()
    if self.machine:current() == bag then
        if success then
            self.machine:pop()
        else
            bag.phase = "list"
        end
    end
    if not enemy then
        return
    end
    local prepared, reason = FieldBattle.prepare(game, session:activePokemon(), enemy)
    local ok, accepted, failure = pcall(function()
        assert(prepared, reason)
        return FieldBattle.start(game, session:activePokemon(), enemy)
    end)
    if ok and accepted then
        return
    end
    -- A failed native battle installation must not turn an attempted cast into
    -- a consumed fishing roll or relocate the earned player checkpoint.
    RulesRNG.restore(rules)
    game.machine:change("overworld", {entry=position, actors=actors, fieldRestore=true})
    game.lastFieldGear = {kind="failed", item="fishing", reason=tostring(ok and failure or accepted)}
    game.machine:push("dialog", {"The fishing battle could not start."})
end

function FieldGearState:update()
    if not self:valid() then
        return
    end
    if self.phase == "cast" or self.phase == "bite" then
        self.frame = self.frame + 1
        if self.plan.kind ~= "bicycle" then
            self.art = FieldGearArt.fishingFrame(self.frame - 1, self.response, self.player.facing)
            if self.art.character then
                self.player:setImage(self.art.character)
                self.player:moveTo(self.player.gridX * TILE_SIZE,
                    self.player.gridY * TILE_SIZE + self.art.playerOffsetY)
            end
        end
        if self.phase == "bite" then
            if self.art.phase == "text" then
                self:showResult({self.art.textLabel})
            end
            return
        end
        -- FishingAnim waits 10 + 100 source VBlanks before the response.
        if self.plan.kind == "bicycle" or self.frame >= 55 then
            self:complete()
        end
    else
        self.dialog:update()
    end
end

function FieldGearState:handleInput()
    if not self:valid() then
        return
    end
    if self.phase == "cast" then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            self:close(false)
        end
        return
    end
    if self.phase == "bite" then
        return
    end
    self.dialog:handleInput()
    if self.done then
        self:close(true)
    end
end

function FieldGearState:draw()
    if not self.active then
        return
    end
    EventState.redrawSprites()
    if self.art then
        for _, name in ipairs({"rod", "exclamation"}) do
            local overlay = self.art[name]
            if overlay then
                overlay.image:draw(self.player.x + overlay.x,
                    self.player.y - self.art.playerOffsetY + overlay.y)
            end
        end
    end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    self.dialog:draw()
    gfx.popContext()
end

function FieldGearState:exit()
    FieldGearRequests.cancel(self.token)
    self.dialog.isActive = false
    if self.game.player == self.player and currentZone == self.zone then
        self.player:moveTo(self.player.gridX * TILE_SIZE, self.player.gridY * TILE_SIZE)
        self.player:updateSprite()
    end
    self.art = nil
    self.active = false
    self.phase = "closed"
    self.token, self.bag, self.enemy = nil, nil, nil
end
