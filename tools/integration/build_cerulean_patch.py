"""Emit a reviewable root patch; does not edit any shared Source file."""
from pathlib import Path
import difflib

ROOT=Path(__file__).resolve().parents[2]
changes={}
p='Source/game/sourceEvents.lua'
s=(ROOT/p).read_text()
s=s.replace('id:match("^pokered:[^:]+:objects:%d+$")\n            and not current[id]', '(id:match("^pokered:[^:]+:objects:%d+$") or id == "pokered:BILLS_HOUSE:hidden_events:1")\n            and not current[id]')
s += '''
-- Explicit source-script exceptions, separate from player/wandering collision.
function SourceEvents.actorCollisionPositions(id)
    local descriptor = definitions()[id]
    return SourceEvents.validateActorPositions(id, descriptor and descriptor.script_collision_positions or {})
end
'''
changes[p]=s
p='Source/domain/gameSession.lua'
s=(ROOT/p).read_text().replace('local badgeFlags={boulder="BADGE_BOULDER"}', 'local badgeFlags={boulder="BADGE_BOULDER",cascade="BADGE_CASCADE"}')
changes[p]=s
p='Source/world/sourceActors.lua'
s=(ROOT/p).read_text()
s=s.replace('spec.visibility = Party._primitive(metadata.visibility or {})', '''spec.script_collision_positions = {}
        for _, position in ipairs(SourceEvents.actorCollisionPositions(event.id)) do
            local cell = position.y * surface.width + position.x + 1
            assert(spec.script_positions[cell] and not protected[cell], "collision exception outside source script positions")
            spec.script_collision_positions[cell] = true
        end
        spec.visibility = Party._primitive(metadata.visibility or {})''')
s=s.replace('and (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1] == 0 then return true end', 'and ((runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1] == 0\n                or spec.script_collision_positions[cell]) then return true end')
changes[p]=s
p='Source/world/npcMotion.lua'
s=(ROOT/p).read_text()
s=s.replace('epoch=s.epoch, player=s.game.player}', 'epoch=s.epoch, player=s.game.player, origin=copy(actor.value)}')
s=s.replace('function NPCMotion:releaseScript(token)', 'function NPCMotion:releaseScript(token, rollback)')
s=s.replace('local actor = scriptLease(s, token)\n    if not actor then return false end', 'local actor, lease = scriptLease(s, token)\n    if not actor then return false end\n    if rollback then actor.value = copy(lease.origin) end')
s += '''
-- Source scene placement is a lease operation, never a direct sprite write.
function NPCMotion:placeScript(token, x, y)
    local s = stores[self]
    local actor, lease = scriptLease(s, token)
    if not actor or not scriptCurrent(s, lease) then return false, "stale-script-token" end
    if lease.move then return false, "script-cell-in-progress" end
    if not Party._integer(x,0,s.descriptor.width-1) or not Party._integer(y,0,s.descriptor.height-1)
        or s.descriptor.protected[y*s.descriptor.width+x+1]
        or not actor.spec.script_positions[y*s.descriptor.width+x+1]
        or not s.descriptor.canStand(actor.spec,x,y,s.zone) then return false, "invalid-source-script-placement" end
    local occupant = s.manager:getNPCAt(x,y)
    local player = s.game.player
    if occupant and occupant ~= actor.npc or player.gridX == x and player.gridY == y
        or player.isMoving and player.startPixelX/TILE_SIZE == x and player.startPixelY/TILE_SIZE == y then
        return false, "occupied-source-script-placement"
    end
    local v = actor.value
    v.x,v.y = x,y
    v.origin_x,v.target_x,v.origin_y,v.target_y = x,x,y,y
    self:_pose(actor)
    return true
end
'''
changes[p]=s
patch=''
for p,new in changes.items():
    old=(ROOT/p).read_text()
    assert old!=new,p
    patch+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+p,tofile='b/'+p))
(ROOT/'tools/integration/cerulean-story.patch').write_text(patch)
