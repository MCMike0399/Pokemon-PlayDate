-- Root calls this delegate from its one final NPCTradeState-derived controller.
HideoutTowerController = {}
function HideoutTowerController.enter(state)
    RocketHideoutStoryController.enter(state)
    TowerStoryController.enter(state)
end
function HideoutTowerController.advance(state)
    return RocketHideoutStoryController.advance(state) or TowerStoryController.advance(state)
end
function HideoutTowerController.update(state)
    RocketHideoutStoryController.update(state)
end
function HideoutTowerController.handleButton(state, button)
    return RocketHideoutStoryController.handleButton(state, button)
end
function HideoutTowerController.draw(state)
    RocketHideoutStoryController.draw(state)
end
function HideoutTowerController.cancel(state)
    RocketHideoutStoryController.exit(state)
    TowerStoryController.exit(state)
end
function HideoutTowerController.afterExit(state)
    local id = state.id or ""
    if not (id:match("^pokered:ROCKET_HIDEOUT_") or id:match("^pokered:GAME_CORNER:")
        or id == TowerStory.FUJI or id == TowerStory.HOUSE_FUJI or TowerStory.rocket(id)
        or SnorlaxStory.definition(id)) then
        return
    end
    if state.game.session == state.session and currentZone == state.zone then
        KantoScenes.reconcileActors(state.game)
    end
end
