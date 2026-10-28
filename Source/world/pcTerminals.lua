-- Immutable pokered hidden-event coordinates; no map/provider materialization.
PCTerminals={}
local data <const> = assert(json.decodeFile("data/pcTerminals.json"))
assert(data.schema == 1 and data.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
    "unverified source PC terminals")
local terminals <const> = data.terminals
function PCTerminals.query(position)
    if type(position)~="table" then return nil end
    -- Original source OpenRedsPC is relocated to the existing authored PC tile;
    -- geometry/art remain unchanged. Bedroom PC opens only the personal service.
    if position.zone_id=="reds_house_2f"and position.x==7 and position.y==3 and position.facing=="up"then
        return {id="pokered:REDS_HOUSE_2F:hidden:1",zone_id=position.zone_id,x=7,y=2,personal=true}
    end
    local terminal = terminals[position.zone_id]
    local name = SourceMaps and SourceMaps.nameForID(position.zone_id)
    if terminal and name then
        local padding = SourceMaps.entry(name).padding
        if position.x == terminal.x + padding and position.y == terminal.y + 1
            and position.facing == terminal.facing then
            return {id=terminal.id, zone_id=position.zone_id, x=terminal.x + padding, y=terminal.y}
        end
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
    if not terminal then return false end
    if terminal.personal then return ItemPCState.open(game,{terminal_id=terminal.id})end
    if not machine:get("pc")then return false end
    machine:push("pc",{terminal_id=terminal.id});return true
end
