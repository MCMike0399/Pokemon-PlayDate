#!/usr/bin/env python3
"""Return the root-owned API patch without changing those files in the checkout."""
from pathlib import Path
import difflib

ROOT = Path(__file__).resolve().parents[2]
changes = {}


def edit(name, old, new):
    text = changes.get(name, (ROOT / name).read_text())
    if old not in text:
        raise ValueError(f'root seam changed: {name}: {old!r}')
    changes[name] = text.replace(old, new, 1)


session = 'Source/domain/gameSession.lua'
edit(session, 'local function location(deps,value,candidateWorld,player)',
     'local function location(deps,value,candidateWorld,player,travel)')
edit(session, 'local resolved = resolver(copy(value), copy(candidateWorld))',
     'local resolved = resolver(copy(value), copy(candidateWorld), copy(travel or FieldTravel.empty()))')
edit(session, 'fieldWorld = {version = 1, mapPalOffset = 0},',
     'fieldWorld = {version = 1, mapPalOffset = 0},\n        fieldTravel = FieldTravel.empty(),')
edit(session, 'actors = true, fieldWorld = true})', 'actors = true, fieldWorld = true, fieldTravel = true})')
edit(session, 'local position = location(current.deps, assert(snapshot.location, "candidate location required"), normalized, true)',
     'local travel = FieldTravel.normalize(snapshot.fieldTravel or current.fieldTravel)\n'
     '        local position = location(current.deps, assert(snapshot.location, "candidate location required"), normalized, true, travel)')
edit(session, 'fieldWorld = fieldData(snapshot.fieldWorld or current.fieldWorld)',
     'fieldWorld = fieldData(snapshot.fieldWorld or current.fieldWorld),\n            fieldTravel = travel')
edit(session, 'current.currentActors = prepared.actors\n    current.fieldWorld',
     'current.currentActors = prepared.actors\n    current.fieldTravel = prepared.fieldTravel\n    current.fieldWorld')
edit(session, 'values.fieldWorld = fieldData(values.fieldWorld)',
     'values.fieldWorld = fieldData(values.fieldWorld)\n    values.fieldTravel = FieldTravel.normalize(values.fieldTravel)')
edit(session, 'function GameSession:fieldWorldData()',
     'function GameSession:fieldTravelData()\n    return copy(state[self].fieldTravel)\nend\n\nfunction GameSession:fieldWorldData()')
edit(session, 'local position = location(current.deps, scene.location, candidate, true)',
     'local position = location(current.deps, scene.location, candidate, true, current.fieldTravel)')
codec = 'Source/domain/sessionCodec.lua'
edit(codec, 'SessionCodec={VERSION=3,', 'SessionCodec={VERSION=4,')
edit(codec, 'fieldWorld=true,daycare=true})', 'fieldWorld=true,daycare=true,fieldTravel=true})')
edit(codec, 'data.version==2 or data.version==SessionCodec.VERSION',
     'data.version==2 or data.version==3 or data.version==SessionCodec.VERSION')
edit(codec, 'local location=GameSession._location(deps,data.location,world,true)',
     'local travel = data.fieldTravel\n'
     '    if data.version < 4 then\n'
     '        assert(travel == nil, "legacy session cannot contain fieldTravel")\n'
     '        travel = FieldTravel.empty()\n'
     '    end\n'
     '    travel = FieldTravel.normalize(travel)\n'
     '    local location=GameSession._location(deps,data.location,world,true,travel)')
edit(codec, 'worldMotion=motion,fieldWorld=fieldWorld}',
     'worldMotion=motion,fieldWorld=fieldWorld,fieldTravel=travel}')
edit(codec, 'fieldWorld=session:fieldWorldData(),title=',
     'fieldTravel=session:fieldTravelData(),fieldWorld=session:fieldWorldData(),title=')
edit(codec, 'rng=prepared.rng,fieldWorld=prepared.fieldWorld})',
     'rng=prepared.rng,fieldWorld=prepared.fieldWorld,fieldTravel=prepared.fieldTravel})')
context = 'Source/game/context.lua'
edit(context, 'resolvePlayerLocation=function(location,world) return WorldDeltas.resolvePlayerLocation(location,world,self.sessionLocationPolicy) end,',
     'resolvePlayerLocation=function(location, world, travel)\n'
     '            return FieldTravelWorld.resolvePlayerLocation(location, world, self.sessionLocationPolicy, travel)\n'
     '        end,')
# Other direct calls use walking semantics, which is correct for checkpoints.
# Root must pass candidate travel to future player-position preflights.
patch = ''.join(''.join(difflib.unified_diff((ROOT / name).read_text().splitlines(True), value.splitlines(True),
                                          fromfile='a/' + name, tofile='b/' + name))
                for name, value in changes.items())
patch = ''.join('\n' if line == ' \n' else line for line in patch.splitlines(True))
(ROOT / 'docs/implementation/field-travel/root-api.patch').write_text(patch)
print('Returned root session/codec/dependency patch; no owned file edited.')
