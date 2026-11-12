"""Route 22's second rival is lane D's check in ceruleanRoutes.lua.

pret/pokered Route22DefaultScript arms a fight on (29, 4) and (29, 5)
when EVENT_ROUTE22_RIVAL_WANTS_BATTLE is set. EVENT_1ST selects the
first rival. Otherwise EVENT_2ND selects the second. Giovanni sets the
shared wants-battle flag together with EVENT_2ND, including when the
first rival was skipped, so objects:1 was never defeated and EVENT_1ST
stays clear. The check now follows that script: EVENT_1ST still starts
the first rival, and otherwise EVENT_2ND starts the second. The notes
patch is the applied diff.
"""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/ceruleanRoutes.lua'
PATCH = ROOT / 'tools/notes/lane-d-route22-second-rival.patch'
FIRST = 'pokered:ROUTE_22:objects:1'
SECOND = 'pokered:ROUTE_22:objects:2'
SKIPPED_FIRST = {
    'EVENT_1ST_ROUTE22_RIVAL_BATTLE': False,
    'EVENT_2ND_ROUTE22_RIVAL_BATTLE': True,
    'EVENT_ROUTE22_RIVAL_WANTS_BATTLE': True,
    'EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE': False,
}


def route22_chunk(text):
    start = text.index('    if zone.stableID == "pokered:ROUTE_22"')
    end = text.index('    elseif zone.stableID == "pokered:CERULEAN_CITY"')
    return text[start:end] + '    end\n'


def dispatch(text, flags, defeated, on_tile):
    """Run only the Route 22 branch of CeruleanRoutes.check."""
    block = route22_chunk(text)
    block = block.replace('EndgameStory.noteRoute22Tile(index)', 'noted = index')
    block = block.replace('zone.stableID == "pokered:ROUTE_22"', 'true')
    block = block.replace('game.session:trainerDefeated(ROUTE)', 'defeated')
    block = re.sub(r'game\.session:questFlag\("([^"]+)"\)', r'(flags.\1 == true)', block)
    block = block.replace('at(data().triggers.route22,x,y)', '(on_tile and 2 or nil)')
    block = block.replace('EndgameStory', 'true')
    block = block.replace('id=ROUTE', 'id = FIRST')
    fields = ',\n'.join(
        f'  {name} = {str(bool(flags.get(name))).lower()}' for name in SKIPPED_FIRST)
    lua = f'''
local flags = {{
{fields}
}}
local defeated = {str(bool(defeated)).lower()}
local on_tile = {str(bool(on_tile)).lower()}
local FIRST = "{FIRST}"
local id
{block}
print(id or "none")
'''
    completed = subprocess.run(['lua5.4', '-'], input=lua, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr + lua)
    return None if completed.stdout.strip() == 'none' else completed.stdout.strip()


class Route22SecondRivalTests(unittest.TestCase):
    def test_skipped_first_rival_starts_the_second_battle(self):
        source = SOURCE.read_text()
        self.assertIn('return empty("unavailable-rival")', source)
        self.assertEqual(dispatch(source, SKIPPED_FIRST, defeated=False, on_tile=True), SECOND)
        still_first = dict(SKIPPED_FIRST, EVENT_1ST_ROUTE22_RIVAL_BATTLE=True)
        self.assertEqual(dispatch(source, still_first, defeated=False, on_tile=True), FIRST)
        self.assertEqual(dispatch(source, SKIPPED_FIRST, defeated=True, on_tile=True), SECOND)
        beaten = dict(SKIPPED_FIRST, EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE=True)
        self.assertIsNone(dispatch(source, beaten, defeated=False, on_tile=True))
        self.assertIsNone(dispatch(source, SKIPPED_FIRST, defeated=False, on_tile=False))

    def test_applied_patch_matches_the_notes_diff(self):
        original = SOURCE.read_text()
        check = subprocess.run(
            ['git', 'apply', '--reverse', '--check', str(PATCH)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertEqual(SOURCE.read_text(), original)


if __name__ == '__main__':
    unittest.main()
