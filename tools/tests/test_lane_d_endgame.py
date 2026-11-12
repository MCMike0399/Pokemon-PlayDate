"""Lane D endgame scripts. Decisions only; no Playdate SDK and no save write."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from PIL import Image

from tools.generate_battle_art import decoded_delta, threshold

ROOT = Path(__file__).resolve().parents[2]
STORY = json.loads((ROOT / "Source/data/endgame/story.json").read_text())
PLAY = json.loads((ROOT / "Source/data/endgame/play.json").read_text())


def lua_binary():
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required")


LUA_RESERVED = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while",
}


def lua_literal(value, level=0):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        while True:
            marker = "]" + ("=" * level) + "]"
            if marker not in value:
                eq = "=" * level
                return f"[{eq}[{value}]{eq}]"
            level += 1
    if isinstance(value, list):
        return "{" + ",".join(lua_literal(item, level) for item in value) + "}"
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            if isinstance(key, str) and key.isidentifier() and key not in LUA_RESERVED:
                parts.append(f"{key}={lua_literal(item, level)}")
            else:
                quoted = json.dumps(key)
                parts.append(f"[{quoted}]={lua_literal(item, level)}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(value))


PROBE = r'''
json = { decodeFile = function(path)
    if string.find(path, "play.json", 1, true) then return play end
    if string.find(path, "visual.json", 1, true) then return visual end
    return story
end }
dofile(module_path)
dofile(encounters_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local data = EndgameStory.story()
check(EndgameStory.badgeName("BADGE_EARTH"), "EARTHBADGE", "earth badge name")
check(EndgameStory.badgeName("BADGE_CASCADE"), "CASCADEBADGE", "cascade badge name")
local earth = data.route23.guards[1]
local denied = EndgameStory.plan(earth.id, {flags = {}})
check(denied.ram.wNameBuffer, "EARTHBADGE", "denied badge ram")
check(denied.steps[2].direction, "down", "denied still steps down")
check(denied.steps[1].audio, nil, "denied line has no cue")
check(denied.steps[2].audio.source, "SFX_DENIED", "denied step plays the cue")
local accepted = EndgameStory.plan(earth.id, {flags = {BADGE_EARTH = true}})
check(accepted.ram.wNameBuffer, "EARTHBADGE", "accepted badge ram")
check(accepted.changes.flags[earth.passed], true, "earth check recorded")
check(EndgameStory.plan(earth.id, {flags = {[earth.passed] = true, BADGE_EARTH = true}}).status,
    "already-complete", "passed guard stays quiet")

local lorelei = data.elite_four[1]
check(EndgameStory.entranceAction(lorelei, 4, 11, {}), "autowalk", "door autowalks")
check(EndgameStory.entranceAction(lorelei, 4, 10, {}), "dont-run", "tile above the door stops a leave")
check(EndgameStory.entranceAction(lorelei, 4, 11, {[lorelei.autowalk_event] = true}), "dont-run",
    "door stays shut after the walk")
check(EndgameStory.entranceAction(lorelei, 4, 11, {[lorelei.flag] = true}), nil, "beaten room is quiet")
local walk = EndgameStory.approachWalk(lorelei, 4)
local rights, ups = 0, 0
for _, step in ipairs(walk) do
    if step.direction == "right" then rights = rights + step.count end
    if step.direction == "up" then ups = ups + step.count end
end
check(rights, 0, "door walk stays on the entry column")
check(ups, 6, "door walk is the six source steps")
local arrow = data.viridian_gym.arrows[1]
local spin = EndgameStory.plan("pokered:VIRIDIAN_GYM:script:arrow",
    {arrow_x = arrow.x, arrow_y = arrow.y, flags = {}})
check(spin.spin, true, "arrow tiles spin the player")
check(spin.audio.source, "SFX_ARROW_TILES", "arrow tiles play the arrow cue")
check(EndgameStory.spinnerFacing("down"), "left", "spinner turns down to left")
check(EndgameStory.spinnerFacing("right"), "down", "spinner turns right to down")
check(#spin.steps > 0, true, "arrow tiles still move the player")
local lance = data.elite_four[4]
local hallway = EndgameStory.approachWalk(lance, 24)
local counts = {}
for _, step in ipairs(hallway) do counts[#counts + 1] = step.direction .. step.count end
check(table.concat(counts, ","), "up8,up4,left8,left4,down7,left6", "lance hallway")
check(EndgameStory.besideTrainer(lance, 6, 2), true, "south of lance")
check(EndgameStory.besideTrainer(lance, 24, 16), false, "staircase is not the battle tile")
local reset = EndgameStory.indigoReset()
local championReset = false
for _, name in ipairs(reset) do
    if name == "EVENT_BEAT_CHAMPION_RIVAL" then championReset = true end
end
check(championReset, false, "champion flag survives the lobby reset")
check(reset[#reset], "EVENT_LANCES_ROOM_LOCK_DOOR", "reset includes the lock")

local hole = EndgameStory.holeWarp("VictoryRoad3F", 23, 15, {})
check(hole.to, "kanto_victory_road_2f", "hole map")
check(hole.toX, 22, "hole x")
check(hole.toY, 16, "hole y")
check(EndgameStory.holeWarp("VictoryRoad3F", 23, 15, {EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH2 = true}),
    nil, "boulder covers the hole")

local leader = data.viridian_gym.leader.id
local won = EndgameStory.plan(leader, {flags = {}, trainers = {[leader] = true},
    can_add = {tm27 = true}, items = {tm27 = 0},
    receipt = {won = true, payout = 4950}})
check(won.changes.flags.EVENT_GOT_TM27, true, "tm27 flag")
check(won.changes.items[1].id, "tm27", "tm27 item")
check(won.steps[1].op, "confirmed-dialog", "giovanni won text")
local advice = EndgameStory.plan(leader, {flags = {EVENT_GOT_TM27 = true}, trainers = {[leader] = true},
    can_add = {}, items = {}})
check(advice.changes.flags.TOGGLE_VIRIDIAN_GYM_GIOVANNI, true, "giovanni hides")
check(advice.disappear.fade_out_steps, 4, "giovanni fades out")
check(advice.disappear.fade_frames, 8, "giovanni fade frames")
check(advice.disappear.delay, 3, "giovanni waits")
check(advice.disappear.fade_in_steps, 4, "giovanni fades in")

local rival = data.route22_rival.id
EndgameStory.noteRoute22Tile(1)
local upper = EndgameStory.route22RivalPlan(rival, {flags = {}, trainers = {}})
check(upper.steps[1].direction, "right", "upper approach")
check(upper.steps[1].count, 3, "upper skips the first right")
check(upper.steps[2].op, "face-npc", "upper rival faces right")
check(upper.steps[2].direction, "right", "upper rival facing")
check(upper.steps[3].direction, "left", "upper player faces left")
check(upper.steps[#upper.steps].mode, "script", "upper battle is the script")
EndgameStory.noteRoute22Tile(2)
local lower = EndgameStory.route22RivalPlan(rival, {flags = {}, trainers = {}})
check(lower.steps[1].count, 4, "lower walks onto the player's tile")
check(lower.steps[2].direction, "up", "lower rival faces up")
check(lower.steps[3].direction, "down", "lower player faces down")
check(lower.steps[#lower.steps].mode, "script", "lower battle is the script")

local champ = data.champion.id
EndgameStory.noteStarter("bulbasaur")
local oak = EndgameStory.championPlan(champ, {flags = {}, trainers = {[champ] = true},
    receipt = {won = true, payout = 6435}})
check(oak.ram.wNameBuffer, "BULBASAUR", "oak names the starter")
local oakWalks = 0
local followed = false
for _, step in ipairs(oak.steps) do
    if step.op == "move-npc" and step.direction == "up" then oakWalks = oakWalks + step.count end
    if step.op == "move" and step.direction == "up" and step.count == 3 then followed = true end
end
check(#oak.steps <= 16, true, "oak scene fits the event step limit")
check(oakWalks, 7, "oak walks up off the warp and onto the hall door")
check(followed, true, "player follows onto the hall warp")
check(oak.steps[#oak.steps].op, "warp", "oak leads to the hall")
check(oak.steps[#oak.steps].to, "kanto_hall_of_fame", "hall warp")
check(oak.oakWalk, true, "oak walk is marked")
check(oak.simulated, true, "the follow is simulated joypad")
check(oak.follow[1].count, 4, "follow records four ups")
check(oak.follow[2].count, 1, "follow records the left")
local oakMoves = 0
for _, step in ipairs(oak.steps) do
    if step.op == "move-npc" and step.count == 5 then oakMoves = oakMoves + 1 end
end
check(oakMoves, 1, "oak's first walk is five ups")
local order = {}
for _, step in ipairs(oak.steps) do
    if step.labels then order[#order + 1] = step.labels[1] end
    if step.op == "move-npc" then order[#order + 1] = "walk-" .. tostring(step.count) end
    if step.op == "move" then order[#order + 1] = "follow-" .. tostring(step.count) end
    if step.op == "warp" then order[#order + 1] = "warp" end
end
check(table.concat(order, ","), table.concat({
    "_RivalDefeatedText", "_MoneyForWinningText", "_ChampionsRoomRivalAfterBattleText",
    "_ChampionsRoomOakText", "walk-5",
    "_ChampionsRoomOakCongratulatesPlayerText", "_ChampionsRoomOakDisappointedWithRivalText",
    "_ChampionsRoomOakComeWithMeText", "walk-2", "follow-3", "warp",
}, ","), "oak calls, then walks in, then the three lines, then leads")
local warpCells = false
for _, cell in ipairs(EndgameStory.oakCells()) do
    if cell.y == 7 or cell.y == 0 then warpCells = true end
end
check(warpCells, false, "warp cells stay unlisted until the engine allows them")
check(EndgameStory.championParty("squirtle").party[6].species, "venusaur", "squirtle champion")

EndgameStory.noteParty({{species = "pikachu", level = 81, name = "PIKACHU"}})
local hall = EndgameStory.plan(data.hall_of_fame.oak_id, {flags = {}})
check(hall.saves, true, "hall saves")
check(hall.blackout.zone_id, "pokered:PALLET_TOWN", "blackout map is pallet")
check(hall.blackout.x, 3, "pallet blackout x")
check(hall.blackout.y, 17, "pallet blackout y")
check(hall.steps[#hall.steps].op, "credits", "hall still rolls credits")
check(hall.record[1].species, "pikachu", "hall record species")
check(hall.record[1].level, 81, "hall record level")
check(hall.record[1].name, "PIKACHU", "hall record name")
check(hall.changes.flags.TOGGLE_CERULEAN_CAVE_GUY, true, "cave guy still hides")
check(hall.changes.flags.EVENT_LANCES_ROOM_LOCK_DOOR, false, "indigo lock resets")
check(hall.changes.flags.EVENT_BEAT_CHAMPION_RIVAL, nil, "champion flag stays")
check(#hall.photos, 2, "one mon and then the player")
check(hall.photos[1].kind, "pokemon", "first card is the mon")
check(hall.photos[1].species, "pikachu", "photo species")
check(hall.photos[1].cry, "pikachu", "photo cry")
check(hall.photos[1].types[1], "ELECTRIC", "photo type")
check(hall.photos[2].kind, "player", "last card is the player")
check(hall.photos[1].pic, "front", "party card shows the mon front pic")
check(hall.photos[2].pic, "player", "red is his own later card")
local single = EndgameStory.hallRows({kind = "pokemon", name = "CHARMANDER", level = 5,
    types = EndgameStory.monTypes("charmander"), pic = "front"})
check(single[4].text, "TYPE1/", "type 1 label stays on its row")
check(single[4].row, 8, "TYPE1/ is the double-spaced label row")
check(single[5].text, "FIRE", "type 1 name is the row under the label")
check(single[5].col, 3, "type 1 name starts at column 3")
check(single[5].row, 9, "type 1 name is hlcoord row 9")
check(#single, 5, "single type erases the TYPE2/ row")
local dual = EndgameStory.hallRows({kind = "pokemon", name = "CHARIZARD", level = 36,
    types = EndgameStory.monTypes("charizard"), pic = "front"})
check(dual[4].text, "TYPE1/", "dual type keeps the type 1 label")
check(dual[5].text, "FIRE", "dual type 1 name is under the label")
check(dual[6].text, "TYPE2/", "dual type keeps the type 2 label")
check(dual[6].row, 10, "TYPE2/ is two rows under TYPE1/")
check(dual[7].text, "FLYING", "type 2 name is the row under TYPE2/")
check(dual[7].col, 3, "type 2 name starts at column 3")
check(dual[7].row, 11, "type 2 name is two rows under the type 1 name")
local pikachu = EndgameStory.hallRows(hall.photos[1])
check(pikachu[5].text, "ELECTRIC", "pikachu prints its one type under TYPE1/")
check(#pikachu, 5, "pikachu erases TYPE2/")
check(EndgameStory.hallCaptionRow().text, "HALL OF FAME", "caption is its own box")
check(EndgameStory.hallCaptionRow().row, 15, "caption is below the mon box")
check(EndgameStory.hallScrollFrames("back"), 56, "back pic scrolls for 56 frames")
check(EndgameStory.hallScrollFrames("front"), 40, "front pic scrolls for 40 frames")
local backStart = EndgameStory.hallScrollFrame("back", 1)
check(backStart.scx, 0xc0, "back scroll starts at hSCX $c0")
check(backStart.scy, 0xd0, "back scroll keeps hSCY $d0")
check(backStart.pic, "back", "the first scroll is the back pic")
check(backStart.x, 160, "back pic starts just off the right edge")
local backEnd = EndgameStory.hallScrollFrame("back", 56)
check(backEnd.scx, 0x9c, "last back frame is one step before $a0")
local frontStart = EndgameStory.hallScrollFrame("front", 1)
check(frontStart.scx, 0xa0, "front scroll starts at hSCX $a0")
check(frontStart.scy, 0, "front scroll clears hSCY")
check(frontStart.pic, "front", "the tiles swap to the front pic")
local frontEnd = EndgameStory.hallScrollFrame("front", 40)
check(frontEnd.scx, 4, "last front frame is one step before rest")
local rest = EndgameStory.hallRest()
check(rest.x, 96, "front pic rests at tile column 12")
check(rest.y, 40, "front pic rests at tile row 5")
check(rest.scx, 0, "the hold is hSCX 0")
check(EndgameStory.playerHallPics().source, "overworld", "red stays on the overworld grid without playdate")
local landed = EndgameStory.playerHallPics(function() return true end)
check(landed.source, "RedPicFront", "red uses RedPicFront once both pics open")
check(landed.front, "images/player/red-pic-front", "RedPicFront path")
check(landed.back, "images/player/red-pic-back", "RedPicBack path")
local cries = {}
EndgameStory.playCry = function(species)
    cries[#cries + 1] = species
    return true
end
local photoState = {photo = {index = 1, clock = 0, stage = "preamble"},
    plan = {photos = {{kind = "pokemon", cry = "charmander"}, {kind = "player"}}}}
local seen = {}
local function tick()
    EndgameStory.updatePhotos(photoState)
    seen[#seen + 1] = photoState.photo.stage .. ":" .. tostring(photoState.photo.clock)
end
for _ = 1, 100 do tick() end
check(seen[100], "preamble:100", "the opening wait is 100 frames")
tick()
check(seen[101], "scroll-back:1", "the back scroll is the next frame")
for _ = 1, 55 do tick() end
check(seen[156], "scroll-back:56", "the back scroll lasts 56 frames")
tick()
check(seen[157], "scroll-front:1", "the front pic replaces the back pic")
check(#cries, 0, "the cry waits until the scroll finishes")
for _ = 1, 39 do tick() end
check(seen[196], "scroll-front:40", "the front scroll lasts 40 frames")
tick()
check(seen[197], "show:1", "the name and types follow the scroll")
check(cries[1], "charmander", "the cry starts with the mon info")
check(EndgameStory.hallCaptionDue(80), false, "the caption waits out the 80-frame hold")
check(EndgameStory.hallCaptionDue(81), true, "the caption follows that hold")
check(EndgameStory.hallShowsCaption({kind = "pokemon"}, "show", 81), true, "a party card gets the hall box")
check(EndgameStory.hallShowsCaption({kind = "player"}, "show", 81), false, "red's card has no hall box")
check(EndgameStory.hallShowsCaption({kind = "player"}, "fade", 1), false, "the fade does not add red's hall box")
local redRows = EndgameStory.playerHallRows({name = "RED", hours = 1, minutes = 5, money = 3000})
check(redRows[1].text, "RED", "red's name is in the name box")
check(redRows[1].col, 7, "name is hlcoord 7, 2")
check(redRows[1].row, 2, "name row")
check(redRows[2].text, "PLAY TIME", "play time label")
check(redRows[2].row, 6, "play time is hlcoord 1, 6")
check(redRows[3].text, "  1:05", "hours are three right-aligned digits, minutes have a leading zero")
check(redRows[3].col, 5, "the time starts at hlcoord 5, 7")
check(redRows[4].text, "MONEY", "money label")
check(redRows[4].row, 9, "money is hlcoord 1, 9")
check(redRows[5].text, "  ¥3000", "yen prints on the first non-zero digit")
check(redRows[5].col, 4, "the amount starts at hlcoord 4, 10")
check(EndgameStory.formatMoney(0), "     ¥0", "a zero balance still prints yen and zero")
local pages = EndgameStory.playerHallPages({seen = 20, owned = 12})
check(pages[1].delay, 120, "seen/owned holds 120 frames")
check(pages[1].text, "POKéDEX   Seen:20\n         Owned:12", "seen line then owned line")
check(pages[2].text, "POKéDEX Rating:", "rating header is the second page")
check(pages[2].delay, 120, "rating header holds 120 frames")
check(string.find(pages[3].text, "right track", 1, true) ~= nil, true, "owned 12 uses the 10-to-19 paragraph")
check(pages[3].delay, 120, "the rating paragraph holds 120 frames")
check(string.find(EndgameStory.dexRating(0), "lots to do", 1, true) ~= nil, true, "owned 0 is the first band")
check(string.find(EndgameStory.dexRating(151), "entirely complete", 1, true) ~= nil, true, "a full dex is the last band")
local redPhoto = {photo = {index = 1, clock = 40, stage = "scroll-front", },
    plan = {photos = {{kind = "player", stats = {seen = 20, owned = 12}}}}}
EndgameStory.updatePhotos(redPhoto)
check(redPhoto.photo.stage, "show", "red's stats follow his scroll")
check(redPhoto.photo.page, 1, "the seen/owned page is first")
check(redPhoto.photo.dexRating, "EVENT_HALL_OF_FAME_DEX_RATING", "the hall dex event is set before the rating")
local dexFlag = {}
local filled = {photo = {index = 1, clock = 40, stage = "scroll-front"},
    plan = {photos = {{kind = "player"}}},
    session = {
        title = function() return {playerName = "RED"} end,
        inventory = function() return {money = function() return 350 end} end,
        pokedex = function() return {seen = {charmander = true, pikachu = true}, owned = {charmander = true}} end,
        playTime = function() return {hours = 2, minutes = 8} end,
        setQuestFlag = function(_, id, value) dexFlag[#dexFlag + 1] = {id, value} end,
    }}
EndgameStory.updatePhotos(filled)
check(dexFlag[1][1], "EVENT_HALL_OF_FAME_DEX_RATING", "the hall dex event is named")
check(dexFlag[1][2], true, "the hall dex event is set before the rating")
check(dexFlag[2][2], false, "CheckAndResetEventA clears the hall dex event")
check(filled.plan.photos[1].stats.money, 350, "red's card reads the session money")
check(filled.plan.photos[1].stats.seen, 2, "red's card counts seen")
check(filled.plan.photos[1].stats.owned, 1, "red's card counts owned")
check(filled.plan.photos[1].stats.hours, 2, "red's card reads play time when a clock exists")
check(EndgameStory.formatMoney(350), "   ¥350", "350 prints three spaces then yen")
local timing = EndgameStory.hallPhotoTiming()
check(timing.preamble, 100, "hall preamble")
check(timing.mon_delay, 80, "hall mon delay")
check(timing.caption, 180, "hall caption")
check(timing.fade_white, 24, "hall fade")

local request = EndgameStory.moltresRequest({})
check(request.species, "moltres", "moltres species")
check(request.level, 50, "moltres level")
check(request.outcomes.run.flags.EVENT_BEAT_MOLTRES, true, "a run hides moltres")
check(request.outcomes.defeat.flags.EVENT_BEAT_MOLTRES, nil, "a loss leaves moltres")
check(request.outcomes.caught.flags.EVENT_BEAT_MOLTRES, true, "a catch hides moltres")
check(request.outcomes.victory.flags.EVENT_BEAT_MOLTRES, true, "a win hides moltres")
local positions = SourceEncounters.positions(request.id)
check(positions[1][1], 11, "moltres trigger x")
check(SourceEncounters.completed({legendary = true}, "run"), true, "legendary run")
check(SourceEncounters.completed({legendary = true}, "defeat"), false, "legendary loss")
check(SourceEncounters.completed({legendary = true}, "caught"), true, "legendary catch")
check(SourceEncounters.completed({legendary = true}, "victory"), true, "legendary win")
check(SourceEncounters.completed({fight = "EVENT_FIGHT_ROUTE12_SNORLAX"}, "run"), true, "snorlax run still completes")
check(SourceEncounters.completed({}, "victory", true), false, "unidentified ghost does not complete")
check(SourceEncounters.completed({}, "victory", false), true, "identified ghost still completes")
check(EndgameStory.text("_BoulderText").recipe[1].text, "This requires", "boulder text")
check(string.sub(EndgameStory.text("_VictoryRoad2FMoltresBattleText").recipe[1].text, 1, 6), "Gyaoo!", "moltres cry text")
local moltres = EndgameStory.moltresPlan(request.id, {flags = {}})
check(moltres.cry, "moltres", "moltres cry")
check(EndgameStory.exclamation(data.champion.id), false, "champion has no bubble")
check(EndgameStory.exclamation(lorelei.id), false, "lorelei has no bubble")
check(EndgameStory.blockKeys("CEMETERY", 59)[1], "pokered:CEMETERY:cell:07-08-17-18", "agatha closed door")
check(EndgameStory.unmappedSprites()[5], "SPRITE_OAK", "oak sprite is mapped here")
local gate = EndgameStory.plan(data.route22_gate.id, {flags = {}})
check(gate.steps[2].audio.source, "SFX_DENIED", "gate plays the denied cue")
print("lane-d-endgame ok")
'''


class LaneDEndgameTests(unittest.TestCase):
    def test_play_text_covers_the_scripts_story_json_left_out(self):
        for label in (
            "_ViridianGymGuidePreBattleText", "_ViridianGymGuidePostBattleText",
            "_IndigoPlateauLobbyGymGuideText", "_Route22PokemonLeagueSignText",
            "_VictoryRoad2FMoltresBattleText", "_ChampionsRoomOakCongratulatesPlayerText",
            "_BoulderText", "_FoundItemText", "_PokemonCenterWelcomeText",
            "_CableClubNPCWelcomeText",
        ):
            self.assertIn(label, PLAY["texts"])
            self.assertNotIn(label, STORY["texts"])
        self.assertEqual(PLAY["source_revision"], STORY["source_revision"])

    def test_scripts_follow_pokered(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.lua"
            path.write_text(
                "story = " + lua_literal(STORY) + "\nplay = " + lua_literal(PLAY)
                + "\nvisual = " + lua_literal(json.loads((ROOT / "Source/data/endgame/visual.json").read_text()))
                + "\nmodule_path = " + json.dumps(str(ROOT / "Source/game/endgameStory.lua"))
                + "\nencounters_path = " + json.dumps(str(ROOT / "Source/domain/sourceEncounters.lua"))
                + "\n" + PROBE)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("lane-d-endgame ok", completed.stdout)

    def test_save_schema_keeps_a_hall_of_fame_record(self):
        source = (ROOT / "Source/domain/sessionCodec.lua").read_text()
        self.assertIn("hallOfFame=true", source)
        self.assertIn("HallOfFame.normalize", source)
        self.assertIn("hallOfFame=session:hallOfFame()", source)
        session = (ROOT / "Source/domain/gameSession.lua").read_text()
        self.assertIn("function GameSession:recordHallOfFame", session)
        self.assertIn("hallOfFame = HallOfFame.empty()", session)

    def test_arrow_and_denied_scores_are_in_the_synth(self):
        scores = (ROOT / "Source/audio/scores.lua").read_text()
        engine = (ROOT / "Source/audio/engine.lua").read_text()
        for name in ("arrow_tiles", "denied"):
            self.assertIn(name, scores)
            self.assertIn(name, engine)

    def test_oak_can_cross_the_champion_warps(self):
        source = (ROOT / "Source/world/sourceActors.lua").read_text()
        self.assertIn("championsOakMayCrossWarp", source)
        probe = r'''
SourceActors = { championsOakMayCrossWarp = function() return true end }
json = { decodeFile = function(path)
    if string.find(path, "visual.json", 1, true) then return visual end
    if string.find(path, "play.json", 1, true) then return play end
    return story
end }
dofile(module_path)
local listed = false
for _, cell in ipairs(EndgameStory.oakCells()) do
    if cell.y == 7 or cell.y == 0 then listed = true end
end
assert(listed, "oak lists the champion warps once the engine allows them")
print("oak-warps ok")
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.lua"
            path.write_text(
                "story = " + lua_literal(STORY) + "\nplay = " + lua_literal(PLAY)
                + "\nvisual = " + lua_literal(json.loads((ROOT / "Source/data/endgame/visual.json").read_text()))
                + "\nmodule_path = " + json.dumps(str(ROOT / "Source/game/endgameStory.lua"))
                + "\n" + probe)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("oak-warps ok", completed.stdout)

    def test_simulated_follow_ignores_sprite_collision(self):
        source = (ROOT / "Source/game/eventState.lua").read_text()
        self.assertIn("plan.simulated", source)

    def test_endgame_sprites_install_before_the_catalog(self):
        source = (ROOT / "Source/main.lua").read_text()
        self.assertLess(
            source.index("EndgameStory.prepareArt()"),
            source.index("CeruleanContent.install(campaignActorMetadata)"))

    def test_agatha_closed_door_is_in_the_tile_cache(self):
        source = (ROOT / "Source/data/sourceMapCache/tile-grids.json").read_text()
        self.assertIn("pokered:CEMETERY:cell:07-08-17-18", source)

    def test_red_hall_pics_use_the_battle_art_threshold(self):
        reference = os.environ.get("POKERED_REFERENCE_DIR")
        if not reference:
            raise RuntimeError("explicit pinned POKERED_REFERENCE_DIR required; no skipped checks")
        pairs = (
            (Path(reference) / "gfx/player/red.png", ROOT / "Source/images/player/red-pic-front.png", (56, 56)),
            (Path(reference) / "gfx/player/redb.png", ROOT / "Source/images/player/red-pic-back.png", (32, 32)),
        )
        for source_path, target_path, size in pairs:
            original = Image.open(source_path)
            self.assertEqual(original.mode, "L")
            self.assertEqual(original.size, size)
            self.assertEqual(set(original.get_flattened_data()), {0, 85, 170, 255})
            actual = Image.open(target_path)
            self.assertEqual(actual.mode, "1")
            self.assertEqual(actual.size, size)
            self.assertTrue(decoded_delta(threshold(original), actual)["equal"])
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        self.assertIn("images/player/red-pic-front", story)
        self.assertIn("images/player/red-pic-back", story)
        manifest = (ROOT / "tools/references/battle-art.json").read_text()
        self.assertNotIn("red-pic-front", manifest)
        self.assertNotIn("red-pic-back", manifest)


if __name__ == "__main__":
    unittest.main()
