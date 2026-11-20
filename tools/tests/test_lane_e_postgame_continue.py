"""Champion win through Hall of Fame, credits, and a Pallet Continue.

Each starter is a fixture party, the same shape a settled continue save
stores. The probe does not debug-warp. pret/pokered af519899:

- data/trainers/parties.asm Rival3Data is the champion team. Charmander
  faces Blastoise, Squirtle faces Venusaur, Bulbasaur faces Charizard.
- engine/movie/hall_of_fame.asm AnimateHallOfFame records the player's
  party, then engine/movie/credits.asm HallOfFamePC rolls the credits.
  The roll opens on Venusaur for every starter.
- scripts/HallOfFame.asm HallOfFameResetEventsAndSaveScript sets the
  blackout map to Pallet and saves, then Init.
- data/maps/special_warps.asm .PalletTown is (5, 6). A Continue whose
  saved map is the Hall of Fame uses that fly warp, facing down.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.tests.test_lane_d_endgame import lua_binary, lua_literal

ROOT = Path(__file__).resolve().parents[2]
STORY = json.loads((ROOT / "Source/data/endgame/story.json").read_text())
PLAY = json.loads((ROOT / "Source/data/endgame/play.json").read_text())
VISUAL = json.loads((ROOT / "Source/data/endgame/visual.json").read_text())
POSTGAME = json.loads((ROOT / "Source/data/postgame/story.json").read_text())

# Rival3Data order is Charmander, Squirtle, Bulbasaur. The player's own
# final form is the other starter, and that is what the Hall of Fame records.
ACES = {"charmander": "blastoise", "squirtle": "venusaur", "bulbasaur": "charizard"}
OWN_FINAL = {"charmander": "charizard", "squirtle": "blastoise", "bulbasaur": "venusaur"}

WARP_MAPS = (
    "PalletTown", "OaksLab", "LoreleisRoom", "BrunosRoom", "AgathasRoom",
    "LancesRoom", "ChampionsRoom", "HallOfFame", "RedsHouse1F", "BluesHouse",
    "Colosseum", "TradeCenter", "RockTunnelB1F",
)

PROBE = r'''
json = { decodeFile = function(path)
    if string.find(path, "postgame/play.json", 1, true) then return postplay end
    if string.find(path, "postgame/story.json", 1, true) then return postgame end
    if string.find(path, "play.json", 1, true) then return play end
    if string.find(path, "visual.json", 1, true) then return visual end
    return story
end }
dofile(endgame_path)
dofile(credits_path)
dofile(postgame_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local champ = story.champion.id
local oakId = story.hall_of_fame.oak_id
for _, starter in ipairs({"squirtle", "bulbasaur", "charmander"}) do
    EndgameStory.noteStarter(starter)
    local won = EndgameStory.championPlan(champ, {flags = {}, trainers = {[champ] = true},
        starter = starter, receipt = {won = true, payout = 6435}})
    check(won.ram.wNameBuffer, string.upper(starter), starter .. " oak names the starter")
    check(won.steps[#won.steps].to, "kanto_hall_of_fame", starter .. " warps to the hall")
    local party = EndgameStory.championParty(starter).party
    check(party[#party].species, aces[starter], starter .. " champion ace")
    local own = owns[starter]
    EndgameStory.noteParty({{species = own, level = 65, name = string.upper(own)}})
    local hall = EndgameStory.plan(oakId, {flags = {EVENT_BEAT_CHAMPION_RIVAL = true}})
    hall = PostgameStory.amendHallPlan(hall, oakId, {flags = {EVENT_BEAT_CHAMPION_RIVAL = true}})
    check(hall.record[1].species, own, starter .. " hall records the player")
    check(hall.record[1].species == party[#party].species, false, starter .. " hall is not the rival ace")
    check(hall.photos[1].species, own, starter .. " photo is the player")
    check(hall.photos[#hall.photos].kind, "player", starter .. " photo ends on Red")
    check(hall.steps[#hall.steps].op, "credits", starter .. " credits follow the photos")
    check(hall.saves, true, starter .. " hall saves")
    check(hall.return_to, "title", starter .. " credits return to the title")
    check(hall.blackout.zone_id, "pokered:PALLET_TOWN", starter .. " blackout map")
    check(hall.blackout.x, 3, starter .. " blackout x")
    check(hall.blackout.y, 17, starter .. " blackout y")
    check(hall.changes.flags.TOGGLE_CERULEAN_CAVE_GUY, true, starter .. " cave opens")
    check(hall.changes.flags.EVENT_BEAT_CHAMPION_RIVAL, false, starter .. " champion flag resets")
    check(hall.continue_at.zone_id, "pokered:PALLET_TOWN", starter .. " continue zone")
    check(hall.continue_at.x, 5, starter .. " continue x")
    check(hall.continue_at.y, 6, starter .. " continue y")
    check(hall.continue_at.facing, "down", starter .. " continue facing")
    local spawn = PostgameStory.continueDecision({zone_id = "pokered:HALL_OF_FAME", x = 4, y = 2, facing = "up"}, 1)
    check(spawn.zone_id, "pokered:PALLET_TOWN", starter .. " continue leaves the hall")
    check(spawn.x, 5, starter .. " spawn x")
    check(spawn.y, 6, starter .. " spawn y")
    check(spawn.facing, "down", starter .. " spawn facing")
    check(PostgameStory.continueDecision({zone_id = "pokered:PALLET_TOWN"}, 1), nil, starter .. " pallet save stays")
end
local roll = CreditsPlayer.start(EndgameStory.credits(), EndgameStory.creditTiming())
check(roll.frames[1].mon, "venusaur", "credits open on Venusaur for every starter")
local guard = 0
while not roll.done do
    CreditsPlayer.advance(roll)
    guard = guard + 1
    if guard > 200000 then error("credits did not finish") end
end
check(roll.return_to, "title", "credits return to the title")
check(roll.frames[#roll.frames].command, "CRED_THE_END", "credits end on THE END")
print("postgame-continue ok")
'''


class PostgameContinueTests(unittest.TestCase):
    def test_each_starter_reaches_pallet_from_a_hall_save(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.lua"
            path.write_text(
                "story = " + lua_literal(STORY)
                + "\nplay = " + lua_literal(PLAY)
                + "\nvisual = " + lua_literal(VISUAL)
                + "\npostgame = " + lua_literal(POSTGAME)
                + "\npostplay = {}\n"
                + "aces = " + lua_literal(ACES)
                + "\nowns = " + lua_literal(OWN_FINAL)
                + "\nendgame_path = " + json.dumps(str(ROOT / "Source/game/endgameStory.lua"))
                + "\ncredits_path = " + json.dumps(str(ROOT / "Source/game/creditsPlayer.lua"))
                + "\npostgame_path = " + json.dumps(str(ROOT / "Source/game/postgameStory.lua"))
                + "\n" + PROBE)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("postgame-continue ok", completed.stdout)

    def test_thirteen_debug_warp_maps_have_sprite_strips(self):
        """The visual-audit crashes were missing strips and one Rock Tunnel assert.

        scripts are unchanged: DebugState zoneSwitch respawns through
        OverworldState, which calls FieldWorld.entryTravel with reason
        "continue". It does not call FieldWorld.enter, so the
        "unsupported Rock Tunnel outside entry" assert is not on that path.
        engine/overworld/map_setup.asm still only sets the dark offset on an
        outside step into ROCK_TUNNEL_1F. B1F stays an unsupported outside entry
        for that function, and this test does not add a bypass.
        """
        maps = json.loads((ROOT / "Source/data/sourceMaps.json").read_text())["maps"]
        catalog = set()
        for path in (ROOT / "Source/data").rglob("sprites.json"):
            catalog.update(json.loads(path.read_text()).get("sprites", {}))
        for name in WARP_MAPS:
            entry = maps[name]
            data = json.loads((ROOT / "Source" / entry["path"]).read_text())
            for obj in data["events"]["objects"]:
                self.assertIn(obj["sprite"], catalog, f"{name} {obj['sprite']}")
        debug = (ROOT / "Source/game/debugState.lua").read_text()
        overworld = (ROOT / "Source/game/overworldState.lua").read_text()
        field = (ROOT / "Source/domain/fieldWorld.lua").read_text()
        self.assertIn('action.type == "zoneSwitch"', debug)
        self.assertNotIn("FieldWorld.enter", debug)
        self.assertIn('FieldWorld.entryTravel(game,', overworld)
        self.assertIn('"continue"', overworld)
        self.assertIn("unsupported Rock Tunnel outside entry", field)
        self.assertIn('assert(toID == "pokered:ROCK_TUNNEL_1F"', field)


if __name__ == "__main__":
    unittest.main()
