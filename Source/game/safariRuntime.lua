-- Read-only observations and narrow integration at existing settled boundaries.
SafariRuntime = {}
local completed = setmetatable({}, {__mode = "k"})
function SafariRuntime.completedStep(game, fieldOwner)
    local player = game.player
    local ordinary = game.machine:getCurrent() == "overworld" and game.machine:depth() == 1
    local ownedSurf = fieldOwner and game.machine:getCurrent() == "fieldTravel"
        and game.machine:current() == fieldOwner and fieldOwner.active and fieldOwner.session == game.session
    if not player or player.isMoving or not player.stepJustFinished or not (ordinary or ownedSurf) then
        return false
    end
    local before = completed[game]
    if before and before.player == player and before.zone == currentZone
        and before.x == player.gridX and before.y == player.gridY and before.toggle == player.walkToggle then
        return false
    end
    completed[game] = {player = player, zone = currentZone, x = player.gridX, y = player.gridY, toggle = player.walkToggle}
    local plan = SafariGame.step(game.session:safariData())
    if not plan then
        return false
    end
    local accepted, reason = game.session:commitSafari(plan, game.session:fieldWorldEpoch())
    assert(accepted, reason)
    return true
end
function SafariRuntime.check(game)
    if game.machine:getCurrent() ~= "overworld" or game.machine:depth() ~= 1
        or not game.player or game.player.isMoving then
        return false
    end
    local data = game.session:safariData()
    if data.ending ~= "none" then
        local mutation = assert(SafariGame.leave(data, false))
        local token, reason = SafariPassage.prepare(game, "forced-return", mutation)
        assert(token, reason)
        game.player.pendingEdgeDoor, game.player.pendingConnection = nil, nil
        assert(SafariPassageState.open(game, token))
        return true
    end
    return false
end
function SafariRuntime.startEncounter(game, enemy)
    if not game.session:safariData().active or not SafariGame.isBattleMap(currentZone.stableID) then
        return false, "not-safari"
    end
    return SafariBattleState.open(game, enemy)
end
function SafariRuntime.allowDoor(game, door)
    local provider = WorldDeltas.definitionProvider()
    local target = provider and provider:hasKey(door.to) and provider:descriptor(door.to).id or door.to
    if currentZone.stableID == "pokered:SAFARI_ZONE_GATE" and SafariGame.isBattleMap(target)
        and not game.session:safariData().active then
        return false, "Safari admission required"
    end
    return true
end
function SafariRuntime.observe(game)
    local value = SafariGame.observe(game)
    local battle, passage = game.machine:get("safariBattle"), game.machine:get("safariPassage")
    value.battle = battle and battle:getSnapshot() or {active = false, phase = "unregistered"}
    value.passage = passage and passage:getSnapshot() or {active = false, phase = "unregistered"}
    value.lastPassage = game.lastSafariPassageSession == game.session and game.lastSafariPassage and GameSession._copy(game.lastSafariPassage) or nil
    value.lastBattle = game.lastSafariBattleSession == game.session and game.lastSafariBattle and GameSession._copy(game.lastSafariBattle) or nil
    return value
end
