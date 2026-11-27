#!/usr/bin/env python3
"""A Hall-team Continue rejects a save that hid a postgame static.

The field save after catching Mewtwo omits
pokered:CERULEAN_CAVE_B1F:objects:1 because EVENT_BEAT_MEWTWO is set.
Title inspect validates that list before loadHallContinue installs the
postgame chunk. LateKantoStory.actorMetadata then has no hide rule, so
WorldMotionData.normalize reports a missing visible source actor and the
slot is corrupt. Continue falls through to the older Hall fixture.

The same gap covers the Power Plant statics, including Zapdos. Their
hide rules live only in PostgameStory.visibility. A taken cave Ultra Ball
fails the same check for a second reason: PostgameStory.installEvents is
what registers the pickup, so title inspect has no PICKUP flag and the
omitted ball still looks visible. That handoff is
tools/notes/lane-e-postgame-pickup-continue.patch, applied after the
static patch.

Snorlax (Routes 12 and 16), Articuno, and Moltres already hide from
boot-chunk metadata. The Mew gift actor is not a pokered source object.
Ordinary item balls whose pickup descriptor is registered at boot do not
fail this check.

Neither patch is applied here. This test fails on the current tree and
passes after both git applies. MallocPoolSize stays 16645684. No skip.
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
local expected = {
    ["pokered:CERULEAN_CAVE_B1F:objects:1"] = "EVENT_BEAT_MEWTWO",
    ["pokered:POWER_PLANT:objects:1"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_0",
    ["pokered:POWER_PLANT:objects:2"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_1",
    ["pokered:POWER_PLANT:objects:3"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_2",
    ["pokered:POWER_PLANT:objects:4"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_3",
    ["pokered:POWER_PLANT:objects:5"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_4",
    ["pokered:POWER_PLANT:objects:6"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_5",
    ["pokered:POWER_PLANT:objects:7"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_6",
    ["pokered:POWER_PLANT:objects:8"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_7",
    ["pokered:POWER_PLANT:objects:9"] = "EVENT_BEAT_ZAPDOS",
    ["pokered:CERULEAN_CAVE_B1F:objects:2"] = "PICKUP:pokered:CERULEAN_CAVE_B1F:objects:2",
    ["pokered:CERULEAN_CAVE_1F:objects:1"] = "PICKUP:pokered:CERULEAN_CAVE_1F:objects:1",
    ["pokered:CERULEAN_CAVE_2F:objects:2"] = "PICKUP:pokered:CERULEAN_CAVE_2F:objects:2",
    ["pokered:POWER_PLANT:objects:10"] = "PICKUP:pokered:POWER_PLANT:objects:10",
}
for id, flag in pairs(expected) do
    local meta = LateKantoStory.actorMetadata(id)
    local rule = meta.visibility and meta.visibility[1]
    if not rule or rule.group ~= "quest" or rule.id ~= flag or rule.equals ~= false then
        io.stderr:write(id .. " visibility " .. tostring(rule and rule.id) .. "\n")
        os.exit(1)
    end
end
print("postgame-statics-hidden-before-postgame")
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
        self.assertIn("postgame-statics-hidden-before-postgame", result.stdout)


if __name__ == "__main__":
    unittest.main()
