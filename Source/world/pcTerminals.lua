-- Immutable pokered hidden-event coordinates; no map/provider materialization.
PCTerminals={}
local terminals={
    ["pokered:VIRIDIAN_POKECENTER"]="pokered:VIRIDIAN_POKECENTER:hidden:2",
    ["pokered:PEWTER_POKECENTER"]="pokered:PEWTER_POKECENTER:hidden:2",
}
function PCTerminals.query(position)
    if type(position)~="table" then return nil end
    local id=terminals[position.zone_id]
    if id and position.x==13 and position.y==4 and position.facing=="up" then
        return {id=id,zone_id=position.zone_id,x=13,y=3}
    end
    return nil
end
function PCTerminals.tryInteract(game)
    local machine,player=game.machine,game.player
    local world=machine:get("overworld")
    if machine:depth()~=1 or machine:current()~=world or not world or not world.sub
        or world.sub:getCurrent()~="explore" or not player or player.isMoving or player.isJumping
        or player.pendingEdgeDoor or player.pendingConnection or player.stepJustFinished then return false end
    local terminal=PCTerminals.query({zone_id=currentZone.stableID,x=player.gridX,y=player.gridY,facing=player.facing})
    if not terminal or not machine:get("pc") then return false end
    machine:push("pc",{terminal_id=terminal.id});return true
end
