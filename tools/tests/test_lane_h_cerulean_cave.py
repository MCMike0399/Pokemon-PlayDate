import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('postgame', ROOT / 'tools/generate_postgame_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
def reference_dir():
    chosen = os.environ.get('POKERED_REFERENCE_DIR')
    if chosen:
        return Path(chosen)
    home = Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'
    if home.exists():
        return home
    return Path('/tmp/pokered')


REFERENCE = reference_dir()


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


class CeruleanCaveSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.story = json.loads(cls.generated['story.json'])
        cls.play = json.loads(cls.generated['play.json'])

    def test_installed_plan_matches_the_pinned_generator(self):
        for name, raw in self.generated.items():
            self.assertEqual((GEN.OUTPUT / name).read_bytes(), raw, name)

    def test_blue_wild_tables_match_the_installed_maps_and_exclude_mewtwo(self):
        floors = {row['map']: row for row in self.story['cave']['floors']}
        self.assertEqual(list(floors), ['CeruleanCave1F', 'CeruleanCave2F', 'CeruleanCaveB1F'])
        asm = (REFERENCE / 'data/wild/maps/CeruleanCaveB1F.asm').read_text()
        self.assertIn('IF DEF(_BLUE)\n\tdb 57, SANDSLASH', asm)
        self.assertNotIn('MEWTWO', asm)
        for name, row in floors.items():
            installed = json.loads((ROOT / 'Source/data/zRemainder' / f'{name}.json').read_text())
            grass = installed['encounters']['grass']
            self.assertEqual(grass['rate_byte'], row['grass_rate'])
            self.assertEqual(installed['encounters']['water']['rate_byte'], 0)
            self.assertEqual(
                [(slot['level'], slot['species'], slot['weight_256']) for slot in grass['slots']],
                [(slot['level'], slot['species'], slot['weight_256']) for slot in row['grass']])
            self.assertNotIn('mewtwo', [slot['species'] for slot in row['grass']])
            self.assertEqual(sum(slot['weight_256'] for slot in row['grass']), 256)
            self.assertGreaterEqual(installed['source_map_id'], 0x25)
            self.assertEqual(installed['tileset']['constant'], 'CAVERN')
        zone = (ROOT / 'Source/world/zone.lua').read_text()
        self.assertIn('sourceMapID >= firstIndoorMap', zone)
        self.assertIn("tileset.constant ~= \"FOREST\"", zone)

    def test_items_and_mewtwo_keep_the_source_objects(self):
        mewtwo = self.story['cave']['mewtwo']
        objects = (REFERENCE / 'data/maps/objects/CeruleanCaveB1F.asm').read_text()
        self.assertIn('object_event 27, 13, SPRITE_MONSTER, STAY, DOWN, TEXT_CERULEANCAVEB1F_MEWTWO, MEWTWO, 70',
                      objects)
        self.assertEqual((mewtwo['id'], mewtwo['x'], mewtwo['y'], mewtwo['level'], mewtwo['flag']),
                         ('pokered:CERULEAN_CAVE_B1F:objects:1', 27, 13, 70, 'EVENT_BEAT_MEWTWO'))
        self.assertEqual(mewtwo['positions'], [[27, 12], [27, 14], [26, 13], [28, 13]])
        self.assertEqual(mewtwo['battle']['hide_on'], ['victory', 'caught', 'run'])
        self.assertEqual(mewtwo['battle']['stay_on'], ['defeat'])
        self.assertEqual(self.play['texts']['_MewtwoBattleText']['recipe'][0]['text'], 'Mew!@')
        items = [item['symbol'] for floor in self.story['cave']['floors'] for item in floor['items']]
        self.assertEqual(items, [
            'FULL_RESTORE', 'MAX_ELIXER', 'NUGGET', 'PP_UP', 'ULTRA_BALL', 'FULL_RESTORE',
            'ULTRA_BALL', 'MAX_REVIVE'])
        self.assertEqual(len(items), 8)

    def test_hall_of_fame_opens_the_cave_and_the_champion_is_inside_the_reset(self):
        self.assertEqual(self.story['cave']['hide'], 'TOGGLE_CERULEAN_CAVE_GUY')
        hall = (REFERENCE / 'scripts/HallOfFame.asm').read_text()
        self.assertIn('ld a, TOGGLE_CERULEAN_CAVE_GUY', hall)
        self.assertIn('ResetEventRange INDIGO_PLATEAU_EVENTS_START, INDIGO_PLATEAU_EVENTS_END, 1', hall)
        self.assertIn('EVENT_BEAT_CHAMPION_RIVAL', self.story['rematch']['indigo_events'])
        reset = re.search(r'local INDIGO_RESET <const> = \{([^}]+)\}',
                          (ROOT / 'Source/game/endgameStory.lua').read_text(), re.S)
        names = re.findall(r'"(EVENT_[A-Z0-9_]+)"', reset.group(1))
        self.assertIn('EVENT_LANCES_ROOM_LOCK_DOOR', names)
        self.assertNotIn('EVENT_BEAT_CHAMPION_RIVAL', names)
        roster = self.story['rematch']['roster']
        self.assertEqual((roster['roster'], roster['selector'], roster['teams'], roster['opponent']),
                         ('same', 'wRivalStarter', 3, 'OPP_RIVAL3'))
        parties = (REFERENCE / 'data/trainers/parties.asm').read_text()
        self.assertEqual(parties.count('Rival3Data:'), 1)
        self.assertNotIn('Rival4Data:', parties)

    def test_post_hall_continue_uses_the_pallet_fly_warp(self):
        spawn = self.story['rematch']['continue_spawn']
        self.assertEqual((spawn['zone_id'], spawn['x'], spawn['y'], spawn['facing']),
                         ('pokered:PALLET_TOWN', 5, 6, 'down'))
        menu = (REFERENCE / 'engine/menus/main_menu.asm').read_text()
        pressed = menu.split('.pressedA', 1)[1].split('InitOptions:', 1)[0]
        self.assertLess(pressed.find('PLAYER_DIR_DOWN'), pressed.find('cp HALL_OF_FAME'))
        self.assertIn('ld a, [wNumHoFTeams]', pressed)
        warps = (REFERENCE / 'data/maps/special_warps.asm').read_text()
        self.assertRegex(warps, r'\.PalletTown:\s+fly_warp PALLET_TOWN,\s+5,\s+6')

    def test_power_plant_items_disguises_and_zapdos_follow_the_script(self):
        plant = self.story['power_plant']
        installed = json.loads((ROOT / 'Source/data/zRemainder/PowerPlant.json').read_text())
        self.assertEqual(plant['grass'], installed['encounters']['grass']['slots'])
        self.assertEqual(plant['grass_rate'], installed['encounters']['grass']['rate_byte'])
        self.assertEqual(plant['water_rate'], 0)
        self.assertNotIn('electabuzz', [slot['species'] for slot in plant['grass']])
        script = (REFERENCE / 'scripts/PowerPlant.asm').read_text()
        pointers = script.split('PowerPlant_TextPointers:', 1)[1].split('PowerPlantTrainerHeaders:', 1)[0]
        flags = []
        for name in re.findall(r'dw_const (\w+),', pointers):
            if name == 'PickUpItemText':
                continue
            body = script.split('\n' + name + ':', 1)[1]
            header = re.search(r'ld hl, (\w+TrainerHeader)', body).group(1)
            flags.append(re.search(header + r':\n\ttrainer (EVENT_[A-Z0-9_]+)', script).group(1))
        self.assertEqual([row['flag'] for row in plant['statics']], flags)
        disguised = [row for row in plant['statics'] if row['disguised']]
        self.assertEqual(len(disguised), 8)
        self.assertEqual(sorted(row['species'] for row in disguised), ['ELECTRODE', 'ELECTRODE', 'VOLTORB', 'VOLTORB', 'VOLTORB', 'VOLTORB', 'VOLTORB', 'VOLTORB'])
        zapdos = plant['statics'][-1]
        self.assertEqual((zapdos['species'], zapdos['level'], zapdos['x'], zapdos['y'], zapdos['sprite'], zapdos['cry']),
                         ('ZAPDOS', 50, 4, 9, 'SPRITE_BIRD', 'zapdos'))
        self.assertEqual(zapdos['battle']['hide_on'], ['victory', 'caught', 'run'])
        self.assertEqual(zapdos['battle']['stay_on'], ['defeat'])
        self.assertEqual([item['item'] for item in plant['items']], ['carbos', 'hpUp', 'rareCandy', 'tm25', 'tm33'])
        self.assertEqual(self.play['texts']['_PowerPlantVoltorbBattleText']['recipe'][0]['text'], 'Bzzzt!')
        self.assertEqual(self.play['texts']['_PowerPlantZapdosBattleText']['recipe'][0]['text'], 'Gyaoo!@')
        self.assertNotIn('cry', plant['statics'][0])

    def test_runtime_hides_mewtwo_clears_the_champion_and_continues_in_pallet(self):
        module = ROOT / 'Source/game/postgameStory.lua'
        probe = r'''
json = { decodeFile = function(path)
    if string.find(path, "play.json", 1, true) then return play end
    return story
end }
local registered = {}
SourceEvents = {
    registerEventSource = function(name, events) registered.events = events; registered.eventName = name end,
    registerTextSource = function(name, resolver) registered.textName = name; registered.text = resolver end,
    registerWorldHooks = function(id, hooks) registered.hook = id; registered.hooks = hooks end,
    has = function() return false end,
}
SourceEventHandlers = {}
local noted
EndgameStory = {
    plan = function()
        return { status = "ready", steps = {},
            changes = { flags = { TOGGLE_CERULEAN_CAVE_GUY = true } },
            expected = { flags = { TOGGLE_CERULEAN_CAVE_GUY = false } } }
    end,
    noteParty = function(members) noted = members end,
}
local captured
local function candidate(zone, teams)
    return {
        location = function() return { zone_id = zone, x = 4, y = 2, facing = "up" } end,
        hallOfFame = function() return { teams = teams } end,
        worldData = function() return { schema = 1 } end,
        flags = function() return { quest = {}, trainers = {} } end,
        checkpoint = function() return { zone_id = "pokered:PALLET_TOWN", x = 3, y = 17, facing = "up" } end,
        captureTraversal = function(self, snapshot) captured = snapshot; return true end,
    }
end
SourceActors = { describe = function() return { zone_id = "pokered:PALLET_TOWN" } end }
WorldMotionData = { reconcile = function() return { version = 1, count = 0, actors = {} } end }
local hallCandidate = candidate("pokered:HALL_OF_FAME", { { species = "pikachu" } })
GameContext = { installSession = function(_, loaded) return loaded end }
GameSaves = {
    continueGame = function() return GameContext:installSession(hallCandidate) end,
    continuePreparedTitle = function() return true end,
}
dofile(module_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local request = PostgameStory.mewtwoRequest({})
check(request.species, "mewtwo", "species")
check(request.level, 70, "level")
check(request.id, "pokered:CERULEAN_CAVE_B1F:objects:1", "id")
check(request.zone_id, "pokered:CERULEAN_CAVE_B1F", "zone")
check(request.outcomes.run.flags.EVENT_BEAT_MEWTWO, true, "run hides")
check(request.outcomes.victory.flags.EVENT_BEAT_MEWTWO, true, "win hides")
check(request.outcomes.caught.flags.EVENT_BEAT_MEWTWO, true, "catch hides")
check(next(request.outcomes.defeat.flags), nil, "loss stays")
check(request.rules.capture, true, "capture")
local mewtwo = PostgameStory.visibility(request.id)
check(mewtwo.visibility[1].id, "EVENT_BEAT_MEWTWO", "mewtwo flag")
check(mewtwo.visibility[1].equals, false, "mewtwo hidden when set")
local oak = story.rematch.oak_id
local plan = EndgameStory.plan(oak, { flags = { EVENT_BEAT_CHAMPION_RIVAL = true } })
check(plan.changes.flags.EVENT_BEAT_CHAMPION_RIVAL, false, "champion cleared")
check(plan.expected.flags.EVENT_BEAT_CHAMPION_RIVAL, true, "champion was set")
check(plan.continue_at.x, 5, "continue x")
check(plan.continue_at.y, 6, "continue y")
check(plan.continue_at.zone_id, "pokered:PALLET_TOWN", "continue zone")
check(plan.rematch_roster, "same", "roster")
check(PostgameStory.continueDecision({ zone_id = "pokered:PALLET_TOWN" }, 1), nil, "pallet stays")
check(PostgameStory.continueDecision({ zone_id = "pokered:HALL_OF_FAME" }, 0), nil, "no teams")
local spawn = PostgameStory.continueDecision({ zone_id = "pokered:HALL_OF_FAME" }, 1)
check(spawn.x, 5, "spawn x")
check(spawn.facing, "down", "spawn facing")
local pickups = 0
for id, event in pairs(registered.events) do
    if event.kind == "pickup" then
        pickups = pickups + 1
        check(event.item ~= nil, true, id)
        check(string.sub(event.flag, 1, 7), "PICKUP:", id)
    end
end
check(pickups, 13, "pickups")
check(registered.events[request.id].kind, "bespoke", "mewtwo event")
local zapdos = PostgameStory.staticRequest("pokered:POWER_PLANT:objects:9", {})
check(zapdos.species, "zapdos", "zapdos species")
check(zapdos.level, 50, "zapdos level")
check(zapdos.zone_id, "pokered:POWER_PLANT", "zapdos zone")
check(zapdos.outcomes.run.flags.EVENT_BEAT_ZAPDOS, true, "zapdos run hides")
check(zapdos.outcomes.victory.flags.EVENT_BEAT_ZAPDOS, true, "zapdos win hides")
check(zapdos.outcomes.caught.flags.EVENT_BEAT_ZAPDOS, true, "zapdos catch hides")
check(next(zapdos.outcomes.defeat.flags), nil, "zapdos loss stays")
local voltorb = PostgameStory.staticRequest("pokered:POWER_PLANT:objects:1", {})
check(voltorb.species, "voltorb", "voltorb species")
check(voltorb.level, 40, "voltorb level")
check(voltorb.outcomes.run.flags.EVENT_BEAT_POWER_PLANT_VOLTORB_0, true, "voltorb run hides")
check(registered.events[voltorb.id].kind, "bespoke", "voltorb is not a pickup")
check(registered.events["pokered:POWER_PLANT:objects:4"].kind, "bespoke", "electrode is not a pickup")
check(registered.events["pokered:POWER_PLANT:objects:10"].kind, "pickup", "carbos")
check(registered.events["pokered:POWER_PLANT:objects:10"].item, "carbos", "carbos id")
check(registered.events["pokered:POWER_PLANT:objects:13"].item, "tm25", "tm thunder")
check(registered.events["pokered:POWER_PLANT:objects:14"].item, "tm33", "tm reflect")
local hidden = PostgameStory.visibility(zapdos.id)
check(hidden.visibility[1].id, "EVENT_BEAT_ZAPDOS", "zapdos flag")
check(hidden.visibility[1].equals, false, "zapdos hidden when set")
check(registered.events["pokered:CINNABAR_LAB_FOSSIL_ROOM:objects:1"].kind, "bespoke", "fossil scientist")
check(registered.text("_MewtwoBattleText").recipe[1].text, "Mew!@", "cry text")
check(GameSaves:continueGame(), hallCandidate, "continue returns")
check(captured.location.zone_id, "pokered:PALLET_TOWN", "relocated zone")
check(captured.location.x, 5, "relocated x")
check(captured.location.y, 6, "relocated y")
check(captured.location.facing, "down", "relocated facing")
currentZone = { stableID = "pokered:HALL_OF_FAME" }
local dispatched
SourceEvents.dispatch = function(_, id) dispatched = id; return true end
registered.hooks.onEnter({ session = { questFlag = function() return true end, party = function()
    return { count = function() return 1 end, get = function() return { species = "pikachu", level = 70, name = "PIKACHU" } end }
end } })
check(registered.hooks.explore({ session = { party = function()
    return { count = function() return 1 end, get = function() return { species = "pikachu", level = 70, name = "PIKACHU" } end }
end } }), true, "rematch dispatch")
check(dispatched, oak, "oak id")
check(noted[1].species, "pikachu", "recorded party")
check(registered.hooks.explore({ session = { party = function()
    return { count = function() return 1 end, get = function() return { species = "pikachu", level = 70, name = "PIKACHU" } end }
end } }), false, "one ceremony")
print("lane-h cave ok")
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.lua'
            path.write_text('story = ' + lua_literal(self.story)
                            + '\nplay = ' + lua_literal(self.play)
                            + '\nmodule_path = ' + json.dumps(str(module)) + '\n' + probe)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('lane-h cave ok', completed.stdout)


class LaneEStaticEncounterHandoffTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.story = json.loads((GEN.OUTPUT / 'story.json').read_text())
        cls.patch = (ROOT / 'tools/notes/lane-e-static-encounters.patch').read_text()

    def test_one_patch_covers_mewtwo_and_the_power_plant_statics(self):
        self.assertFalse((ROOT / 'tools/notes/lane-e-mewtwo-encounter.patch').exists())
        rows = [self.story['cave']['mewtwo'], *self.story['power_plant']['statics']]
        self.assertEqual(len(rows), 10)
        for row in rows:
            self.assertIn('["' + row['id'] + '"]', self.patch)
            self.assertIn('species = "' + row['species'].lower() + '", level = ' + str(row['level']), self.patch)
            self.assertIn('flag = "' + row['flag'] + '", legendary = true', self.patch)
        self.assertIn('species = "mewtwo", level = 70', self.patch)
        self.assertIn('species = "zapdos", level = 50', self.patch)
        self.assertIn('species = "electrode", level = 43', self.patch)
        self.assertEqual(sum(1 for line in self.patch.splitlines() if line.startswith('+') and 'legendary = true' in line), 10)
        completed = subprocess.run(['patch', '--dry-run', '--fuzz=0', '-p1'], input=self.patch, text=True,
                                   cwd=ROOT, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertNotIn('FAILED', completed.stdout)

    @unittest.expectedFailure
    def test_source_encounters_defines_the_static_rows(self):
        text = (ROOT / 'Source/domain/sourceEncounters.lua').read_text()
        for row in (self.story['cave']['mewtwo'], *self.story['power_plant']['statics']):
            self.assertIn('["' + row['id'] + '"]', text)
            self.assertIn('flag = "' + row['flag'] + '", legendary = true', text)


if __name__ == '__main__':
    unittest.main()
