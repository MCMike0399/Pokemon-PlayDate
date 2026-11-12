"""Lane D endgame scripts. Decisions only; no Playdate SDK and no save write."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

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
check(spin.spinner, true, "arrow tiles spin the player")
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
check(EndgameStory.championParty("squirtle").party[6].species, "venusaur", "squirtle champion")

EndgameStory.noteParty({{species = "pikachu", level = 81, name = "PIKACHU"}})
local hall = EndgameStory.plan(data.hall_of_fame.oak_id, {flags = {}})
check(hall.saves, false, "hall still does not save")
check(hall.steps[#hall.steps].op, "credits", "hall still rolls credits")
check(hall.record[1].species, "pikachu", "hall record species")
check(hall.record[1].level, 81, "hall record level")
check(hall.changes.flags.TOGGLE_CERULEAN_CAVE_GUY, true, "cave guy still hides")

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
                + "\nmodule_path = " + json.dumps(str(ROOT / "Source/game/endgameStory.lua"))
                + "\nencounters_path = " + json.dumps(str(ROOT / "Source/domain/sourceEncounters.lua"))
                + "\n" + PROBE)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("lane-d-endgame ok", completed.stdout)

    @unittest.expectedFailure
    def test_save_schema_keeps_a_hall_of_fame_record(self):
        source = (ROOT / "Source/domain/sessionCodec.lua").read_text()
        self.assertIn("hallOfFame=true", source)


if __name__ == "__main__":
    unittest.main()
