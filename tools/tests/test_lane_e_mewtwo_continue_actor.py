#!/usr/bin/env python3
"""A Hall-team Continue rejects the newer cave save.

The field save after catching Mewtwo is adventure.b.json, sequence 2.
Its actor list keeps the still-visible Max Revive and omits
pokered:CERULEAN_CAVE_B1F:objects:1 because EVENT_BEAT_MEWTWO is set.
Title inspect validates that list before loadHallContinue installs the
postgame chunk. LateKantoStory.actorMetadata then has no hide rule, so
WorldMotionData.normalize reports a missing visible source actor and the
slot is corrupt. Continue falls through to the older Hall fixture.

The handoff is tools/notes/lane-e-mewtwo-continue-actor.patch. It is not
applied here. This test fails on the current tree and passes after
git apply. MallocPoolSize stays 16645684. No skip.
"""

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PROBE = r"""
json = {
    decodeFile = function()
        return {
            schema = 1,
            source_revision = "af519899719f0754965776faac0e836a3b906e6d",
            scenes = { cerulean_cave = { hide = "TOGGLE_CERULEAN_CAVE_GUY", guard_id = "guard" } },
        }
    end,
}
function import() end
PostgameStory = nil
dofile(__SOURCE__)
assert(PostgameStory == nil, "the boot probe loaded PostgameStory")
local meta = LateKantoStory.actorMetadata("pokered:CERULEAN_CAVE_B1F:objects:1")
local rule = meta.visibility and meta.visibility[1]
if not rule or rule.group ~= "quest" or rule.id ~= "EVENT_BEAT_MEWTWO" or rule.equals ~= false then
    io.stderr:write("mewtwo visibility " .. tostring(rule and rule.id) .. "\n")
    os.exit(1)
end
print("mewtwo-hidden-before-postgame")
"""


class MewtwoContinueActorTests(unittest.TestCase):
    def test_boot_chunk_hides_mewtwo_before_the_postgame_chunk_loads(self):
        script = ROOT / "Source/game/lateKantoStory.lua"
        code = PROBE.replace("__SOURCE__", json.dumps(str(script)))
        result = subprocess.run(
            ["lua5.4", "-e", code],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("mewtwo-hidden-before-postgame", result.stdout)


if __name__ == "__main__":
    unittest.main()
