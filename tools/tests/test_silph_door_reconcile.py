"""Drive real Silph door reconciliation and count world copies.

SilphStoryWorld.reconcile used to call projectBlock once per card-key door.
Each call deep-copied the exported world. The elevator arrives on Silph Co 2F,
which has two doors. The host test loads those two source files and compares
reconcile with that per-door loop.
"""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROCKET = ROOT / "Source/game/rocketHideoutStoryWorld.lua"
SILPH = ROOT / "Source/game/silphStoryWorld.lua"
SCENES = ROOT / "Source/data/silphStory/scenes.json"
MANIFEST = ROOT / "Source/data/sourceMaps.json"
FLOOR = "pokered:SILPH_CO_2F"
OPEN_KEY = "pokered:FACILITY:cell:01-01-01-01"


def lua_executable():
    candidates = []
    if os.environ.get("LUA"):
        candidates.append(os.environ["LUA"])
    found = shutil.which("lua")
    if found:
        candidates.append(found)
    candidates.append("/tmp/lua-5.4.7/src/lua")
    for path in candidates:
        if not path or not os.access(path, os.X_OK):
            continue
        version = subprocess.check_output([path, "-v"], text=True, stderr=subprocess.STDOUT).strip()
        if version.startswith("Lua 5.3") or version.startswith("Lua 5.4"):
            return path
    raise AssertionError("Lua 5.3+ is required to execute SilphStoryWorld.reconcile")


def lua_literal(value):
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, list):
        return "{" + ",".join(lua_literal(item) for item in value) + "}"
    if isinstance(value, dict):
        fields = []
        for key, item in value.items():
            if isinstance(key, str) and key.isidentifier():
                fields.append(f"{key}={lua_literal(item)}")
            else:
                fields.append(f"[{lua_literal(key)}]={lua_literal(item)}")
        return "{" + ",".join(fields) + "}"
    raise TypeError(type(value))


DRIVER = r"""
local sceneData = dofile(arg[3])
local geometry = dofile(arg[4])

local function rawCopy(value, seen)
    if type(value) ~= "table" then return value end
    local out = {}
    seen = seen or {}
    assert(not seen[value], "cyclic world")
    seen[value] = true
    for key, item in pairs(value) do
        out[rawCopy(key, seen)] = rawCopy(item, seen)
    end
    seen[value] = nil
    return out
end

local function same(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not same(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local tables = 0
local worldCopies = 0
local function countingCopy(value, seen)
    if type(value) ~= "table" then return value end
    local out = {}
    tables = tables + 1
    if value.zones ~= nil and seen == nil then worldCopies = worldCopies + 1 end
    seen = seen or {}
    assert(not seen[value], "cyclic world")
    seen[value] = true
    for key, item in pairs(value) do
        out[countingCopy(key, seen)] = countingCopy(item, seen)
    end
    seen[value] = nil
    return out
end

GameSession = { _copy = countingCopy }
SourceMaps = {}
function SourceMaps.entry(name)
    local geometryRow = assert(geometry[name], "map outside source manifest")
    return {id = geometryRow.id, width = geometryRow.width, padding = geometryRow.padding}
end
function SourceMaps.hasTile() return true end
function SourceMaps.cell() return {key = "OPEN_KEY"} end

WorldDeltas = {}
function WorldDeltas.definitionProvider()
    return {descriptor = function() return {revision = "silph-door-test"} end}
end
function WorldDeltas.export() error("export is installed per case") end

SilphStory = {}
function SilphStory.scenes() return sceneData end

dofile(arg[1])
dofile(arg[2])

local flags = {}
local forks = 0
local transacts = {}
local session = {}
function session:questFlag(id) return flags[id] or false end
function session:forkWorldRNG()
    forks = forks + 1
    local n = forks
    return {toData = function() return {kind = "fork", n = n} end}, "token-" .. n
end
function session:worldRngData() return {kind = "before"} end
function session:transactScene(expected, changes, scene)
    transacts[#transacts + 1] = {expected = expected, changes = changes, scene = scene}
    return true
end
local game = {session = session, player = {gridX = 4, gridY = 2, facing = "down"}}

local function sentinel(world)
    for _, zone in ipairs(world.zones) do
        if zone.zone_id == "pokered:ZONE_01" then
            return zone.tiles[1].key
        end
    end
    error("missing sentinel zone")
end

local function otherZones()
    local zones = {}
    for index = 1, 40 do
        local tiles = {}
        for tile = 1, 30 do
            tiles[tile] = {x = tile, y = 1, key = index == 1 and tile == 1 and "sentinel" or "other"}
        end
        zones[index] = {schema = 1, zone_id = string.format("pokered:ZONE_%02d", index),
            definition_revision = "r", tiles = tiles, tile_count = #tiles}
    end
    return {schema = 1, zones = zones, zone_count = #zones}
end

local function specsFor(doors, mode)
    local specs = {}
    for index, door in ipairs(doors) do
        local opened = mode == "open" or (mode == "mixed" and index == 1)
        flags[door.flag] = opened
        specs[index] = {map = door.map, x = door.x, y = door.y,
            keys = opened and door.open_keys or door.closed_keys}
    end
    return specs
end

local function projectLoop(world, specs)
    local candidate = world
    for _, spec in ipairs(specs) do
        candidate = RocketHideoutStoryWorld.projectBlock(candidate, spec)
    end
    return candidate
end

local function measure(mode, template)
    local doors = sceneData.doors["FLOOR"]
    flags = {}
    local specs = specsFor(doors, mode)
    worldCopies, tables = 0, 0
    GameSession._copy = countingCopy
    local baselineWorld = rawCopy(template)
    local baseline = projectLoop(baselineWorld, specs)
    local baselineCopies, baselineTables = worldCopies, tables
    assert(sentinel(baselineWorld) == "sentinel", "per-door projection mutated the export")

    worldCopies, tables, forks, transacts = 0, 0, 0, {}
    local exported
    function WorldDeltas.export()
        exported = rawCopy(template)
        return exported
    end
    currentZone = {stableID = "FLOOR"}
    SilphStoryWorld.reconcile(game)
    local reconcileCopies, reconcileTables = worldCopies, tables
    assert(sentinel(exported) == "sentinel", "reconcile mutated the exported world")
    local candidate
    if #transacts == 0 then
        candidate = exported
        assert(forks == 0, "matching floor forked world RNG")
    else
        assert(#transacts == 1, "one scene transaction")
        assert(forks == 1, "scene transaction forks world RNG once")
        assert(transacts[1].scene.beforeWorld == exported, "transaction keeps the export as the pre-image")
        assert(transacts[1].changes.flags["SILPH_STORY_SCENE_V1_TURN_A"] == true)
        assert(transacts[1].changes.flags["SILPH_STORY_SCENE_V1_TURN_B"] == false)
        assert(transacts[1].scene.location.zone_id == "FLOOR")
        candidate = transacts[1].scene.world
    end
    io.write(string.format("%s\t%d\t%d\t%d\t%d\t%s\t%d\t%d\n", mode,
        baselineCopies, reconcileCopies, baselineTables, reconcileTables,
        same(candidate, baseline) and "true" or "false", #transacts, forks))
end

local input = otherZones()
worldCopies = 0
GameSession._copy = countingCopy
local once = RocketHideoutStoryWorld.projectBlock(input, {map = "SilphCo2F", x = 0, y = 0,
    keys = {"OPEN_KEY", "OPEN_KEY", "OPEN_KEY", "OPEN_KEY"}})
assert(worldCopies == 1, "projectBlock still copies once")
assert(once ~= input and input.zones[1].tiles[1].key == "sentinel", "projectBlock mutated its input")

measure("open", otherZones())
measure("closed", otherZones())
measure("mixed", otherZones())

GameSession._copy = rawCopy
flags = {}
local closed = projectLoop(otherZones(), specsFor(sceneData.doors["FLOOR"], "closed"))
measure("repeat-closed", closed)
"""


class SilphDoorReconcileTests(unittest.TestCase):
    def test_floor_two_reuses_one_world_for_every_card_key_door(self):
        scenes = json.loads(SCENES.read_text())["scenes"]
        doors = scenes["doors"][FLOOR]
        self.assertEqual(len(doors), 2)
        for door in doors:
            self.assertEqual(door["open_keys"], [OPEN_KEY] * 4)
            self.assertTrue(any(key != OPEN_KEY for key in door["closed_keys"]))
        manifest = json.loads(MANIFEST.read_text())["maps"]
        geometry = {}
        for door in doors:
            entry = manifest[door["map"]]
            geometry[door["map"]] = {"id": entry["id"], "width": entry["width"], "padding": entry["padding"]}

        driver = (DRIVER
                  .replace("OPEN_KEY", OPEN_KEY)
                  .replace("FLOOR", FLOOR))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            rocket = root / "rocket.lua"
            silph = root / "silph.lua"
            rocket.write_text(ROCKET.read_text().replace(" <const>", ""))
            silph.write_text(SILPH.read_text().replace(" <const>", ""))
            doors_path = root / "scenes.lua"
            geometry_path = root / "geometry.lua"
            doors_path.write_text("return " + lua_literal({"doors": {FLOOR: doors}}) + "\n")
            geometry_path.write_text("return " + lua_literal(geometry) + "\n")
            script = root / "drive.lua"
            script.write_text(driver)
            completed = subprocess.run(
                [lua_executable(), str(script), str(rocket), str(silph), str(doors_path), str(geometry_path)],
                text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        rows = {}
        for line in completed.stdout.splitlines():
            mode, baseline_copies, reconcile_copies, baseline_tables, reconcile_tables, same, transacts, forks = line.split("\t")
            rows[mode] = {
                "baseline_copies": int(baseline_copies),
                "reconcile_copies": int(reconcile_copies),
                "baseline_tables": int(baseline_tables),
                "reconcile_tables": int(reconcile_tables),
                "same": same == "true",
                "transacts": int(transacts),
                "forks": int(forks),
            }
        # Already-open and repeat-closed floors match the export, so reconcile
        # keeps that table. The old loop still copied once per door.
        for mode in ("open", "repeat-closed"):
            row = rows[mode]
            self.assertTrue(row["same"], mode)
            self.assertEqual(row["baseline_copies"], 2, mode)
            self.assertEqual(row["reconcile_copies"], 0, mode)
            self.assertGreater(row["baseline_tables"], row["reconcile_tables"], mode)
            self.assertEqual(row["reconcile_tables"], 0, mode)
            self.assertEqual(row["transacts"], 0, mode)
            self.assertEqual(row["forks"], 0, mode)
        # Locked and mixed floors still commit one scene, with one world copy.
        for mode in ("closed", "mixed"):
            row = rows[mode]
            self.assertTrue(row["same"], mode)
            self.assertEqual(row["baseline_copies"], 2, mode)
            self.assertEqual(row["reconcile_copies"], 1, mode)
            self.assertGreater(row["baseline_tables"], row["reconcile_tables"], mode)
            self.assertEqual(row["transacts"], 1, mode)
            self.assertEqual(row["forks"], 1, mode)


if __name__ == "__main__":
    unittest.main()
