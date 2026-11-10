"""League story generated from pinned pokered, and the decisions that read it."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tools.generate_endgame_story import OUTPUT, build

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')


def lua_binary():
    for name in ('lua', 'lua5.4'):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError('Lua 5.4 is required')


LUA_RESERVED = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
    'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while',
}


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


class EndgameStoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = build(POKERED)
        cls.story = json.loads(cls.generated['story.json'])

    def test_generated_story_matches_the_pinned_sources(self):
        for name, raw in self.generated.items():
            self.assertEqual((OUTPUT / name).read_bytes(), raw, name)
        gym = self.story['viridian_gym']
        leader = gym['leader']
        self.assertEqual(gym['required_mask'], 127)
        self.assertEqual((gym['trigger']['x'], gym['trigger']['y']), (32, 8))
        self.assertEqual((gym['door']['x'], gym['door']['y']), (32, 7))
        self.assertEqual(len(gym['arrows']), 12)
        self.assertEqual(gym['arrows'][0], {'x': 19, 'y': 11, 'steps': [{'direction': 'up', 'count': 9}]})
        self.assertEqual((leader['x'], leader['y'], leader['roster'], leader['item']), (2, 1, 3, 'tm27'))
        self.assertEqual(leader['party'][-1], {'species': 'rhydon', 'level': 50})
        self.assertEqual(leader['id'], 'pokered:VIRIDIAN_GYM:objects:1')
        self.assertEqual([guard['badge'] for guard in self.story['route23']['guards']], [
            'BADGE_EARTH', 'BADGE_VOLCANO', 'BADGE_MARSH', 'BADGE_SOUL',
            'BADGE_RAINBOW', 'BADGE_THUNDER', 'BADGE_CASCADE'])
        self.assertEqual([guard['y'] for guard in self.story['route23']['guards']],
                         [35, 56, 85, 96, 105, 119, 136])
        switches = {(row['map'], row['x'], row['y'], row['block']['x'], row['block']['y'])
                    for row in self.story['victory_road']['switches']}
        self.assertEqual(switches, {
            ('VictoryRoad1F', 17, 13, 4, 6),
            ('VictoryRoad2F', 1, 16, 3, 4),
            ('VictoryRoad2F', 9, 16, 11, 7),
            ('VictoryRoad3F', 3, 5, 3, 5),
        })
        rooms = self.story['elite_four']
        self.assertEqual([row['map'] for row in rooms],
                         ['LoreleisRoom', 'BrunosRoom', 'AgathasRoom', 'LancesRoom'])
        self.assertEqual([row['party'][-1]['species'] for row in rooms],
                         ['lapras', 'machamp', 'gengar', 'dragonite'])
        self.assertEqual([row['party'][-1]['level'] for row in rooms], [56, 58, 60, 62])
        parties = self.story['champion']['parties_by_player_starter']
        self.assertEqual(parties['charmander']['party'][-1]['species'], 'blastoise')
        self.assertEqual(parties['squirtle']['party'][-1]['species'], 'venusaur')
        self.assertEqual(parties['bulbasaur']['party'][-1]['species'], 'charizard')
        rival = self.story['route22_rival']['parties_by_player_starter']['charmander']['party'][-1]
        self.assertEqual(rival, {'species': 'blastoise', 'level': 53})
        opening = self.story['hall_of_fame']['credits'][0]
        self.assertEqual(opening['lines'], ['#MON', 'BLUE VERSION STAFF'])
        self.assertEqual(opening['mon'], 'venusaur')
        self.assertEqual(opening['command'], 'CRED_TEXT_FADE_MON')
        closing = self.story['hall_of_fame']['credits'][-1]
        self.assertTrue(closing['end'])
        self.assertEqual(closing['command'], 'CRED_THE_END')
        self.assertEqual(closing['graphic'], 'gfx/credits/the_end.2bpp')
        self.assertEqual(self.story['hall_of_fame']['return_to'], 'title')
        self.assertFalse(self.story['hall_of_fame']['saves'])
        self.assertEqual(self.story['hall_of_fame']['timing']['preamble_frames'], [100, 128])
        self.assertEqual(self.story['hall_of_fame']['timing']['scroll_tiles'], [7, 20])
        self.assertEqual(self.story['hall_of_fame']['oak_id'], 'pokered:HALL_OF_FAME:objects:1')
        gate = self.story['route22_gate']
        self.assertEqual(gate['y_split'], 4)
        self.assertEqual((gate['north_map'], gate['south_map'], gate['badge']),
                         ('ROUTE_23', 'ROUTE_22', 'BADGE_BOULDER'))

    def test_decisions_follow_the_story_without_writing_a_save(self):
        module = ROOT / 'Source/game/endgameStory.lua'
        probe = r'''
json = { decodeFile = function() return story end }
dofile(module_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local bits = {}
for index, name in ipairs(EndgameStory.story().badge_bits) do bits[name] = true end
check(EndgameStory.badgeValue(bits), 255, "all badges")
bits.BADGE_EARTH = nil
check(EndgameStory.badgeValue(bits), 127, "seven badges")
check(EndgameStory.gymDoor(bits), "open-and-set", "gym opens")
bits.BADGE_VOLCANO = nil
check(EndgameStory.gymDoor(bits), "locked", "volcano still required")
bits.BADGE_VOLCANO = true
bits[EndgameStory.story().viridian_gym.open_event] = true
check(EndgameStory.gymDoor(bits), "open", "gym stays open")
local guard, accepted = EndgameStory.route23Guard(10, 35, {})
check(accepted, false, "earth gate denies")
check(guard.badge, "BADGE_EARTH", "earth gate")
local accepted_guard, has_badge = EndgameStory.route23Guard(10, 35, {BADGE_EARTH = true})
check(has_badge, true, "earth gate accepts")
check(accepted_guard.badge, "BADGE_EARTH", "accepted gate")
check(EndgameStory.route23Guard(14, 35, {}), nil, "earth gate is west of x 14")
local denied = EndgameStory.plan(guard.id, {flags = {}})
check(denied.status, "denied", "denied plan")
check(denied.steps[2].direction, "down", "denied step")
local switch = EndgameStory.boulderSwitch("VictoryRoad1F", 17, 13)
check(switch.event, "EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH", "first switch")
check(EndgameStory.boulderSwitch("VictoryRoad3F", 23, 15).hide_toggle,
    "TOGGLE_VICTORY_ROAD_3F_BOULDER", "third floor hole")
check(EndgameStory.route22Party("charmander").party[#EndgameStory.route22Party("charmander").party].species,
    "blastoise", "route 22 ace")
check(EndgameStory.championParty("bulbasaur").party[#EndgameStory.championParty("bulbasaur").party].species,
    "charizard", "champion ace")
local arrow = EndgameStory.plan("pokered:VIRIDIAN_GYM:script:arrow", {arrow_x = 19, arrow_y = 11})
check(arrow.steps[1].count, 8, "arrow split")
check(arrow.steps[2].count, 1, "arrow remainder")
check(arrow.steps[1].direction, "up", "arrow direction")
local credits = EndgameStory.credits()
check(credits[1].lines[2], "BLUE VERSION STAFF", "credits")
check(credits[1].command, "CRED_TEXT_FADE_MON", "opening command")
check(credits[#credits].graphic, "gfx/credits/the_end.2bpp", "the end")
dofile(credits_path)
local player = CreditsPlayer.start(credits, EndgameStory.creditTiming())
local frames = 0
while not player.done do
    CreditsPlayer.advance(player)
    frames = frames + 1
    if frames > 20000 then error("credits did not finish") end
end
check(player.return_to, "title", "credits return")
check(frames, expected_frames, "credits length")
local hall = EndgameStory.plan(EndgameStory.story().hall_of_fame.oak_id, {flags = {}})
check(hall.return_to, "title", "hall returns")
check(hall.saves, false, "hall does not save")
check(hall.steps[#hall.steps].op, "credits", "hall credits")
check(hall.changes.flags.TOGGLE_CERULEAN_CAVE_GUY, true, "cave guy hides")
local badges = 0
for name in pairs(hall.changes.flags) do
    if string.find(name, "BADGE_", 1, true) then badges = badges + 1 end
end
check(badges, 0, "no badge write")
print("endgame-decisions ok")
'''
        timing = self.story['hall_of_fame']['timing']
        fade = timing['fade_steps'] * timing['fade_hold']
        scroll = sum(timing['scroll_tiles'])
        holds = timing['hold']
        expected = sum(timing['preamble_frames'])
        for frame in self.story['hall_of_fame']['credits']:
            command = frame['command']
            if command == 'CRED_TEXT_FADE_MON':
                expected += fade + holds[command] + scroll
            elif command == 'CRED_TEXT_MON':
                expected += holds[command] + scroll
            elif command == 'CRED_TEXT_FADE':
                expected += fade + holds[command]
            elif command == 'CRED_TEXT':
                expected += holds[command]
            elif command == 'CRED_THE_END':
                expected += holds[command] + fade
            else:
                self.fail(command)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.lua'
            path.write_text('story = ' + lua_literal(self.story) + '\nmodule_path = '
                            + json.dumps(str(module)) + '\ncredits_path = '
                            + json.dumps(str(ROOT / 'Source/game/creditsPlayer.lua'))
                            + '\nexpected_frames = ' + str(expected) + '\n' + probe)
            completed = subprocess.run([lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('endgame-decisions ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
