-- Root calls this delegate from its one final NPCTradeState-derived controller.
HideoutTowerController = {}
function HideoutTowerController.enter(state)
    RocketHideoutStoryController.enter(state)
    if TowerStoryController then TowerStoryController.enter(state) end
    if MidgameGymStoryController then MidgameGymStoryController.enter(state) end
    if SilphStoryController then SilphStoryController.enter(state) end
    CeladonServicesController.enter(state)
end
function HideoutTowerController.advance(state)
    return RocketHideoutStoryController.advance(state) or (TowerStoryController and TowerStoryController.advance(state))
        or (MidgameGymStoryController and MidgameGymStoryController.advance(state)) or (SilphStoryController and SilphStoryController.advance(state))
        or CeladonServicesController.advance(state)
end
function HideoutTowerController.update(state)
    RocketHideoutStoryController.update(state)
    CeladonServicesController.update(state)
end
function HideoutTowerController.handleButton(state, button)
    return RocketHideoutStoryController.handleButton(state, button) or (SilphStoryController and SilphStoryController.handleButton(state, button))
        or CeladonServicesController.handleButton(state, button)
end
function HideoutTowerController.draw(state)
    RocketHideoutStoryController.draw(state)
    if SilphStoryController then SilphStoryController.draw(state) end
    CeladonServicesController.draw(state)
end
function HideoutTowerController.cancel(state)
    RocketHideoutStoryController.exit(state)
    if TowerStoryController then TowerStoryController.exit(state) end
    if SilphStoryController then SilphStoryController.exit(state) end
    CeladonServicesController.exit(state)
end
function HideoutTowerController.afterExit(state)
    local id = state.id or ""
    if not (id:match("^pokered:ROCKET_HIDEOUT_") or id:match("^pokered:GAME_CORNER:")
        or TowerStory and (id == TowerStory.RIVAL or id == TowerStory.FUJI or id == TowerStory.HOUSE_FUJI or TowerStory.rocket(id))
        or SnorlaxStory and SnorlaxStory.definition(id)) then
        return
    end
    if state.game.session == state.session and currentZone == state.zone then
        KantoScenes.reconcileActors(state.game)
    end
end
