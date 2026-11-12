"""A scripted walk must release its actor before the trainer battle.

The Route 22 rival plan walks the sprite, then starts a script-mode
battle in the same event. move-npc keeps the NPCMotion lease.
TrainerEvents:prepare claims that same actor, and claimScript returns
source-actor-already-claimed while the walk lease is held. The other
story controllers cancel the walk before startTrainer. EventState's
generic handoff now does too. Lane E can take the notes patch for main.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source/game/eventState.lua'
PATCH = ROOT / 'tools/notes/lane-e-trainer-lease.patch'


def start_trainer(text):
    start = text.index('function EventState:startTrainer(step)')
    end = text.index('function EventState:trainerReady()')
    body = text[start:end].replace(
        'function EventState:startTrainer(step)', 'function(self, step)', 1)
    lua = f'''
local leased = true
local failed
local actor = {{def = {{source_event_id = "rival"}}}}
local state = {{
    cancelNPCMove = function() leased = false end,
    fail = function(_, reason) failed = reason end,
    trainerReady = function() end,
    game = {{
        npcManager = {{npcs = {{actor}}}},
        trainers = {{
            prepare = function()
                if leased then return nil, "source-actor-already-claimed" end
                return {{}}
            end,
            updateApproach = function() return true end,
        }},
    }},
}}
local start = {body}
start(state, {{id = "rival", mode = "script"}})
if failed then print(failed) else print("ready") end
'''
    completed = subprocess.run(['lua5.4', '-'], input=lua, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr + lua)
    return completed.stdout.strip()


class TrainerLeaseTests(unittest.TestCase):
    def test_scripted_walk_releases_before_the_battle_claim(self):
        self.assertEqual(start_trainer(SOURCE.read_text()), 'ready')

    def test_applied_patch_matches_the_notes_diff(self):
        original = SOURCE.read_text()
        check = subprocess.run(
            ['git', 'apply', '--reverse', '--check', str(PATCH)],
            cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertEqual(SOURCE.read_text(), original)


if __name__ == '__main__':
    unittest.main()
