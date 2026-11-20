#!/usr/bin/env python3
"""Continuing a Hall of Fame save must use the pokered post-credits spawn.

pret/pokered af519899 saves while the player is still in the Hall, then
Init. Continue of that save, when wNumHoFTeams is not zero, special-warps
to Pallet Town (5, 6) facing down. The ceremony walk leaves our save at
HALL_OF_FAME (5, 2). postgameStory.boot() tries to install the continue
wrapper at import, and a cached load before GameSaves exists does not
install it. KantoScenes.install does not retry, so the title continue
keeps the Hall cell.

tools/notes/lane-e-hof-continue.patch.
"""

import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = "af519899719f0754965776faac0e836a3b906e6d"
SPAWN = ("pokered:PALLET_TOWN", 5, 6, "down")
HALL = ("pokered:HALL_OF_FAME", 5, 2, "up")

HOST = r"""
local root = arg[1]
json = {
    decodeFile = function(path)
        if path:find("story.json", 1, true) then
            return {
                schema = 1,
                source_revision = "af519899719f0754965776faac0e836a3b906e6d",
                rematch = {
                    hall_zone = "pokered:HALL_OF_FAME",
                    oak_id = "oak",
                    champion_flag = "EVENT_BEAT_CHAMPION_RIVAL",
                    continue_spawn = {
                        zone_id = "pokered:PALLET_TOWN", x = 5, y = 6, facing = "down",
                    },
                    roster = { roster = "same" },
                },
                cave = { floors = {}, mewtwo = { id = "mew" }, hide = "HIDE" },
                power_plant = { items = {}, statics = {} },
                fossil = { scientist = { id = "sci" }, island_zone = "z", island_map = "m" },
            }
        end
        return { schema = 1, source_revision = "af519899719f0754965776faac0e836a3b906e6d", texts = {} }
    end,
}
-- The simulator caches this import before GameSaves exists.
local source = assert(io.open(root .. "/Source/game/postgameStory.lua")):read("a")
assert(load(source, "@postgameStory.lua"))()

GameSession = {
    _copy = function(value)
        if type(value) ~= "table" then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = GameSession._copy(item) end
        return out
    end,
}
local place = { zone_id = "pokered:HALL_OF_FAME", x = 5, y = 2, facing = "up" }
GameContext = {}
function GameContext:installSession(candidate)
    local location = candidate:location()
    place = { zone_id = location.zone_id, x = location.x, y = location.y, facing = location.facing }
    return true
end
GameSaves = {}
function GameSaves:continueGame()
    return GameContext:installSession(self.candidate)
end
function GameSaves:continuePreparedTitle()
    return GameContext:installSession(self.candidate)
end
local before = GameSaves.continuePreparedTitle
io.write("BOOT_WRAPPED 0\n")
local scenes = assert(io.open(root .. "/Source/game/kantoScenes.lua")):read("a")
local window = assert(scenes:match("function KantoScenes.install%(%)(.-)\n    installed = true"))
local retries = window:find("PostgameStory.ensureRuntime()", 1, true) ~= nil
if retries then
    PostgameStory.ensureRuntime()
end
local loc = { zone_id = "pokered:HALL_OF_FAME", x = 5, y = 2, facing = "up" }
local candidate = {
    location = function()
        return { zone_id = loc.zone_id, x = loc.x, y = loc.y, facing = loc.facing }
    end,
    hallOfFame = function()
        return { teams = { { species = "charizard" } } }
    end,
    worldData = function() return {} end,
    flags = function() return {} end,
    checkpoint = function()
        return { zone_id = "pokered:PALLET_TOWN", x = 3, y = 17, facing = "up" }
    end,
    captureTraversal = function(_, snapshot)
        loc = snapshot.location
        return true
    end,
}
SourceActors = { describe = function() return { ok = true } end }
WorldMotionData = { reconcile = function() return {} end }
GameSaves.continuePreparedTitle({ candidate = candidate })
local wrapped = GameSaves.continuePreparedTitle ~= before and 1 or 0
io.write(string.format("SCENE_RETRY %d\n", retries and 1 or 0))
io.write(string.format("WRAPPED %d\n", wrapped))
io.write(string.format("PLACE %s %d %d %s\n", place.zone_id, place.x, place.y, place.facing))
-- A missing actor descriptor must not install the Hall cell.
loc = { zone_id = "pokered:HALL_OF_FAME", x = 5, y = 2, facing = "up" }
place = { zone_id = "unchanged", x = 0, y = 0, facing = "none" }
SourceActors.describe = function() return nil end
local refused, why = GameSaves.continuePreparedTitle({ candidate = candidate })
io.write("REFUSED " .. tostring(refused) .. "\n")
io.write("WHY " .. tostring(why) .. "\n")
io.write(string.format("STAY %s %d %d %s\n", place.zone_id, place.x, place.y, place.facing))
"""


def reference():
    raw = os.environ.get("POKERED_REFERENCE_DIR")
    if not raw:
        raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
    path = Path(raw)
    if not path.is_dir():
        raise RuntimeError("POKERED_REFERENCE_DIR is not a directory")
    revision = subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()
    if revision != REVISION:
        raise AssertionError(revision)
    return path


def line_value(text, needle):
    for line in text.splitlines():
        if needle in line:
            return line
    raise AssertionError(needle)


class HallContinuePalletTests(unittest.TestCase):
    def test_post_credits_continue_spawns_in_pallet_town(self):
        ref = reference()
        constants = (ref / "constants/map_constants.asm").read_text(encoding="utf-8")
        pallet = line_value(constants, "map_const PALLET_TOWN,")
        hall = line_value(constants, "map_const HALL_OF_FAME,")
        self.assertIn("; $00", pallet)
        self.assertIn("; $76", hall)
        menu = (ref / "engine/menus/main_menu.asm").read_text(encoding="utf-8")
        pressed = menu.split(".pressedA", 1)[1].split("InitOptions:", 1)[0]
        self.assertIn("ld a, PLAYER_DIR_DOWN", pressed)
        self.assertIn("ld [wPlayerDirection], a", pressed)
        self.assertIn("ld a, [wNumHoFTeams]", pressed)
        self.assertIn("cp HALL_OF_FAME", pressed)
        self.assertIn("xor a", pressed)
        self.assertIn("ld [wDestinationMap], a", pressed)
        self.assertIn("call PrepareForSpecialWarp", pressed)
        self.assertIn("jp SpecialEnterMap", pressed)
        warps = (ref / "data/maps/special_warps.asm").read_text(encoding="utf-8")
        self.assertIn("fly_warp PALLET_TOWN,      5,  6", warps)
        macro = warps.split("MACRO fly_warp", 1)[1].split("DungeonWarpData:", 1)[0]
        self.assertIn(r"db ((\3) & $01) ;sub-block Y", macro)
        self.assertIn(r"db ((\2) & $01) ;sub-block X", macro)
        special = (ref / "engine/overworld/special_warps.asm").read_text(encoding="utf-8")
        fly = special.split(".usedFlyWarp", 1)[1].split(".done", 1)[0]
        self.assertIn("ld c, $6", fly)
        self.assertNotIn("wPlayerDirection", fly)
        script = (ref / "scripts/HallOfFame.asm").read_text(encoding="utf-8")
        reset = script.split("HallOfFameResetEventsAndSaveScript:", 1)[1].split("HallOfFameDefaultScript:", 1)[0]
        self.assertIn("predef HallOfFamePC", reset)
        self.assertIn("ld a, PALLET_TOWN", reset)
        self.assertIn("ld [wLastBlackoutMap], a", reset)
        self.assertIn("farcall SaveGameData", reset)
        self.assertIn("jp Init", reset)
        self.assertIn("db PAD_UP, 5", script)
        self.assertIn("ld a, PLAYER_DIR_RIGHT", script)
        objects = (ref / "data/maps/objects/HallOfFame.asm").read_text(encoding="utf-8")
        self.assertIn("warp_event  5,  7, CHAMPIONS_ROOM, 4", objects)
        self.assertIn("object_event  5,  2, SPRITE_OAK, STAY, DOWN, TEXT_HALLOFFAME_OAK", objects)
        movie = (ref / "engine/movie/hall_of_fame.asm").read_text(encoding="utf-8")
        animate = movie.split("AnimateHallOfFame:", 1)[1].split(".skipInc", 1)[0]
        self.assertIn("ld hl, wNumHoFTeams", animate)
        self.assertNotIn("PALLET_TOWN", animate)
        endgame = (ROOT / "Source/game/endgameStory.lua").read_text(encoding="utf-8")
        self.assertIn(
            '{op = "warp", to = "kanto_hall_of_fame", toX = 5, toY = 7, facing = "up"}',
            endgame)
        story = (ROOT / "Source/data/endgame/story.json").read_text(encoding="utf-8")
        self.assertIn('"count": 5', story)
        self.assertIn('"direction": "up"', story)

        completed = subprocess.run(
            ["lua5.4", "-", str(ROOT)], input=HOST, text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        facts = {}
        for line in completed.stdout.splitlines():
            key, _, rest = line.partition(" ")
            facts[key] = rest
        self.assertEqual(facts["BOOT_WRAPPED"], "0", completed.stdout)
        zone, x, y, facing = facts["PLACE"].split()
        self.assertEqual((zone, int(x), int(y), facing), SPAWN, completed.stdout)
        self.assertNotEqual((zone, int(x), int(y), facing), HALL)
        self.assertEqual(facts["REFUSED"], "false", completed.stdout)
        self.assertEqual(facts["WHY"], "pallet-actors-unavailable", completed.stdout)
        stay = facts["STAY"].split()
        self.assertEqual(tuple(stay), ("unchanged", "0", "0", "none"), completed.stdout)


if __name__ == "__main__":
    unittest.main()
