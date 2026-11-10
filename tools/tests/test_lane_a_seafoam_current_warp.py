"""Seafoam current warps land on water and enter the surf state.

B3F warps 6 and 7 arrive on B4F foot tile $14. Land collision rejects that
tile, but pokered's CollisionCheckOnWater accepts it. A solid non-water
arrival and a blocked water cell stay rejected.
"""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source'
MAPS = ('SeafoamIslandsB2F', 'SeafoamIslandsB3F', 'SeafoamIslandsB4F')

LUA_RESERVED = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
    'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while',
}


def lua_binary():
    for name in ('lua', 'lua5.4'):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError('Lua 5.4 is required')


def lua_literal(value, level=0):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        while True:
            marker = ']' + ('=' * level) + ']'
            if marker not in value:
                eq = '=' * level
                return f'[{eq}[{value}]{eq}]'
            level += 1
    if isinstance(value, list):
        return '{' + ','.join(lua_literal(item, level) for item in value) + '}'
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            if isinstance(key, str) and key.isidentifier() and key not in LUA_RESERVED:
                parts.append(f'{key}={lua_literal(item, level)}')
            else:
                quoted = json.dumps(key) if isinstance(key, str) else lua_literal(key, level)
                parts.append(f'[{quoted}]={lua_literal(item, level)}')
        return '{' + ','.join(parts) + '}'
    raise TypeError(type(value))


def records():
    manifest = json.loads((SOURCE / 'data/sourceMaps.json').read_text())
    compact = json.loads((SOURCE / 'data/sourceMapCache/compact.json').read_text())
    maps = {name: compact['maps'][name] for name in MAPS}
    # One extra B4F warp sits on a cavern wall (foot $10, not water).
    wall = dict(maps['SeafoamIslandsB4F']['warps'][0])
    wall.update(id='pokered:SEAFOAM_ISLANDS_B4F:warps:wall', x=0, y=0, source_x=0, source_y=0)
    maps['SeafoamIslandsB4F']['warps'] = list(maps['SeafoamIslandsB4F']['warps']) + [wall]
    tiles = {}
    for descriptor in maps.values():
        for key in descriptor['palette']:
            tiles[key] = compact['tiles'][key]
    return {
        'data/sourceMaps.json': {
            'schema': manifest['schema'],
            'source_revision': manifest['source_revision'],
            'door_tiles': {},
            'maps': {name: manifest['maps'][name] for name in MAPS},
        },
        'data/sourceMapCache/compact.json': {
            'schema': compact['schema'],
            'source_revision': compact['source_revision'],
            'manifest_sha256': compact['manifest_sha256'],
            'door_tiles': {},
            'maps': maps,
            'tiles': tiles,
        },
    }, json.loads((SOURCE / 'data/fieldTravel.json').read_text())


PROBE = r'''
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
Party = {
    _primitive = copy,
    _array = function(value) return type(value) == "table" end,
}
GameSession = {
    _copy = copy,
    _object = function(value, allowed)
        assert(type(value) == "table")
        for key in pairs(value) do assert(allowed[key], "unknown field: " .. tostring(key)) end
    end,
}
FieldMoves = { same = function() return true end }
json = { decodeFile = function(path)
    assert(path == "data/fieldTravel.json", path)
    return TRAVEL
end }
dofile("Source/world/sourceMaps.lua")
dofile("Source/domain/fieldTravel.lua")
dofile("Source/domain/fieldWorld.lua")
FieldCycling = {
    FLAG = "pokered:status6:BIT_ALWAYS_ON_BIKE",
    enter = function(travel, forced)
        return {kind = "bicycle-entry", travel = travel, forced = forced}
    end,
}
FieldTravelWorld = {
    cell = function(position)
        local name = SourceMaps.nameForID(position.zone_id)
        if not name then return nil, "missing" end
        local descriptor = SourceMaps.descriptor(name)
        return SourceMaps.cell(name, position.x, position.y).terrain, descriptor
    end,
}

local function warp(name, index)
    return SourceMaps.descriptor(name).warps[index]
end

local function arrive(mode, zone, x, y, reason)
    local plan, failure = FieldWorld.entryTravel({
        sessionLocationPolicy = {},
        session = {
            fieldTravelData = function()
                return {version = 1, mode = mode, strength = false, visited = {}}
            end,
            questFlag = function() return false end,
            inventory = function() return {quantity = function() return 0 end} end,
        },
    }, {zone_id = zone, x = x, y = y}, {schema = 1, zones = {}, zone_count = 0}, reason)
    assert(plan, failure)
    return plan.mode
end

SourceMaps._withRecords(RECORDS, function()
    local b2 = SourceMaps.warpSpec("SeafoamIslandsB2F", warp("SeafoamIslandsB2F", 2))
    assert(b2.status == "bound" and b2.target_name == "SeafoamIslandsB3F", "B2F stair")
    assert(b2.toX == 5 and b2.toY == 12 and b2.travel == nil, "B2F stair stays on land")

    local current = SourceMaps.warpSpec("SeafoamIslandsB3F", warp("SeafoamIslandsB3F", 2))
    assert(current.status == "bound" and current.target_name == "SeafoamIslandsB4F", "B3F land stair")
    assert(current.travel == nil and current.toX == 11 and current.toY == 7, "land arrival does not surf")

    for _, index in ipairs({6, 7}) do
        local event = warp("SeafoamIslandsB3F", index)
        local spec = SourceMaps.warpSpec("SeafoamIslandsB3F", event)
        assert(spec.status == "bound", "water warp " .. index)
        assert(spec.target_name == "SeafoamIslandsB4F", "water target")
        assert(spec.toX == event.x and spec.toY == event.y, "water coordinates")
        assert(spec.travel == "surfing", "water arrival surfs")
        local cell = SourceMaps.cell("SeafoamIslandsB4F", spec.toX, spec.toY)
        assert(cell.collision == 1 and cell.terrain.foot_tile == 0x14
            and cell.terrain.water_candidate == true, "arrival is water tile $14")
    end

    local b4 = SourceMaps.descriptor("SeafoamIslandsB4F")
    local live = SourceMaps._sharedCompact().maps.SeafoamIslandsB4F
    local waterIndex = tostring(17 * live.width + 20 + 1)
    live.blocked[waterIndex] = "probe"
    local blocked = SourceMaps.warpSpec("SeafoamIslandsB3F", warp("SeafoamIslandsB3F", 6))
    assert(blocked.status == "blocked", "blocked water stays blocked")
    live.blocked[waterIndex] = nil

    local wall = warp("SeafoamIslandsB4F", #b4.warps)
    local solid, err = pcall(function()
        SourceMaps.warpSpec("SeafoamIslandsB3F", {
            id = "probe-solid", x = 0, y = 0,
            destination = {kind = "map", map = "SEAFOAM_ISLANDS_B4F", warp_index = #b4.warps},
        })
    end)
    assert(not solid and string.find(tostring(err), "original warp arrival is blocked", 1, true), tostring(err))
    assert(wall.x == 0 and wall.y == 0, "probe warp is the wall")
    local cell = SourceMaps.cell("SeafoamIslandsB4F", 0, 0)
    assert(cell.collision == 1 and cell.terrain.water_candidate ~= true, "wall is not water")

    local zone = "pokered:SEAFOAM_ISLANDS_B4F"
    assert(arrive("walking", zone, 20, 17, "map") == "surfing", "map entry surfs onto water")
    assert(arrive("walking", zone, 11, 7, "map") == "walking", "land entry stays walking")
    assert(arrive("walking", zone, 0, 0, "map") == "walking", "solid entry stays walking")
    assert(arrive("surfing", zone, 20, 17, "continue") == "surfing", "continue keeps surf on water")
    assert(arrive("walking", zone, 20, 17, "blackout") == "walking", "blackout stays on foot")
    assert(arrive("surfing", zone, 11, 7, "map") == "walking", "surf ends on land")
end)
print("OK")
'''


class SeafoamCurrentWarpTests(unittest.TestCase):
    def test_water_warp_arrivals_enter_surf_and_solid_arrivals_stay_blocked(self):
        pinned, travel = records()
        script = (
            'local RECORDS = ' + lua_literal(pinned) + '\n'
            + 'local TRAVEL = ' + lua_literal(travel) + '\n'
            + PROBE
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.lua'
            path.write_text(script)
            result = subprocess.run(
                [lua_binary(), str(path)], cwd=ROOT, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('OK', result.stdout)


if __name__ == '__main__':
    unittest.main()
