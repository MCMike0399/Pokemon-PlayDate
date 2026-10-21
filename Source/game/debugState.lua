-- game/debugState.lua — Debug menu as a pushed overlay
--
-- Pushed over the overworld (world keeps animating underneath). In-menu
-- actions (heal, warp, toggles...) are consumed every frame; menu-closing
-- actions (wild battle, zone switch) are handled when the menu's onClose
-- fires: pop first, then change() into the requested state.

Class("DebugState"):extends(State)

function DebugState:init(game)
    DebugState.super.init(self, "debug")
    self.game = game
end

function DebugState:enter()
    local game = self.game
    local session=game.session
    self.visit=(self.visit or 0)+1
    local visit=self.visit
    self.game.debugMenu:open(function()
        if not self:isTop() or self.visit~=visit or game.session~=session then return false,"stale-debug-creation" end
        if not Specimen.isActiveSession(session) then game.debugMenu.isActive=true;return false,"inactive-specimen-session" end
        local action = game.debugMenu:consumeAction()
        if action and action.type=="wildBattle" and not session:party():firstUsable()then
            game.debugMenu.isActive=true;game.debugMenu:showMessage("No usable POKEMON.");return false,"no-usable-pokemon"
        end
        local enemy
        if action and action.type=="wildBattle" and game.session:party():firstUsable() then
            local problem
            enemy,problem=Specimen.createForSession(session,action.species,action.level,"debug")
            if not enemy then
                game.debugMenu.isActive=true
                game.debugMenu:showMessage("Couldn't start battle.")
                return false,problem
            end
        end
        self.machine:pop()

        if action and action.type == "wildBattle" and game:getPlayerPokemon() then
            assert(FieldBattle.start(self.game,
                game:getPlayerPokemon(), enemy, nil))
        elseif action and action.type == "zoneSwitch" then
            switchZone(action.zone)
            self.machine:change("overworld", { respawn = true })
        elseif action and action.type == "skipIntro" then
            Story.skipIntro(game)
            -- Rebuild in place so story-conditional NPCs refresh
            self.machine:change("overworld")
        elseif action and action.type == "resetIntro" then
            Story.resetIntro(game)
            self.machine:push("dialog", Story.openingLines)
        end
    end)
end

function DebugState:exit()
    self.visit=(self.visit or 0)+1
    self.game.debugMenu.isActive = false
end

function DebugState:update()
    local game = self.game
    local action = game.debugMenu:consumeAction()
    if not action then return end

    if action.type == "heal" and game:getPlayerPokemon() then
        game:getPlayerPokemon():fullRestore()
    elseif action.type == "resetNPCs" then
        for _, npc in ipairs(game.npcManager.npcs) do
            npc:resetInteracted()
        end
    elseif action.type == "setLevel" and game:getPlayerPokemon() then
        game:resetActiveLevelForDebug(action.level)
    elseif action.type == "warp" and game.player then
        game.player.gridX = action.x
        game.player.gridY = action.y
        game.player:moveTo(action.x * TILE_SIZE, action.y * TILE_SIZE)
    end
end

function DebugState:handleInput()
    self.game.debugMenu:handleInput()
end

function DebugState:draw()
    local camera = self.game.camera
    camera:reset()
    self.game.debugMenu:draw()
    camera:apply()
end
