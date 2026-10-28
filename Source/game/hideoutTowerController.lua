-- Root calls this delegate from its one final NPCTradeState-derived controller.
HideoutTowerController = {}
function HideoutTowerController.enter(state)
    RocketHideoutStoryController.enter(state)
    TowerStoryController.enter(state)
    MidgameGymStoryController.enter(state)
    SilphStoryController.enter(state)
end
function HideoutTowerController.advance(state)
    return RocketHideoutStoryController.advance(state) or TowerStoryController.advance(state)
        or MidgameGymStoryController.advance(state) or SilphStoryController.advance(state)
end
function HideoutTowerController.update(state)
    RocketHideoutStoryController.update(state)
end
function HideoutTowerController.handleButton(state, button)
    return RocketHideoutStoryController.handleButton(state, button) or SilphStoryController.handleButton(state, button)
end
function HideoutTowerController.draw(state)
    RocketHideoutStoryController.draw(state)
    SilphStoryController.draw(state)
end
function HideoutTowerController.cancel(state)
    RocketHideoutStoryController.exit(state)
    TowerStoryController.exit(state)
    SilphStoryController.exit(state)
end
function HideoutTowerController.afterExit(state)
    local id = state.id or ""
    if not (id:match("^pokered:ROCKET_HIDEOUT_") or id:match("^pokered:GAME_CORNER:")
        or id == TowerStory.RIVAL or id == TowerStory.FUJI or id == TowerStory.HOUSE_FUJI or TowerStory.rocket(id)
        or SnorlaxStory.definition(id)) then
        return
    end
    if state.game.session == state.session and currentZone == state.zone then
        KantoScenes.reconcileActors(state.game)
    end
end
