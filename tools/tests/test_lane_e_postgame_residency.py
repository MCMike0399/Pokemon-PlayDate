#!/usr/bin/env python3
"""A normal field boot must not keep PostgameStory resident.

KantoScenes.install used to call ensureRuntime on every contract shard.
That decoded data/postgame/story.json and retained the event copy, and
field-moves and grass-cut then failed copyImage with not enough memory.
The chunk loads for a Hall-team Continue and for the Hall of Fame ceremony.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PROBE = r"""
local root = arg[1]
local decoded = {}
import = function(name)
    if name == "game/postgameStory" then
        error("field install loaded postgameStory")
    end
end
json = {
    decodeFile = function(path)
        decoded[#decoded + 1] = path
        if path:find("postgame", 1, true) then
            error("field install decoded " .. path)
        end
        return {
            schema = 1,
            source_revision = "af519899719f0754965776faac0e836a3b906e6d",
            scenes = { cerulean_cave = { hide = "HIDE", guard_id = "pokered:CERULEAN_CAVE:guard" } },
        }
    end,
}
local source = assert(io.open(root .. "/Source/game/lateKantoStory.lua")):read("a")
assert(load(source, "@lateKantoStory.lua"))()
assert(PostgameStory == nil, "PostgameStory resident after late Kanto load")
local metadata = LateKantoStory.actorMetadata("pokered:PALLET_TOWN:objects:1")
assert(type(metadata) == "table", "actor metadata")
assert(PostgameStory == nil, "actor metadata loaded PostgameStory")
local hits = 0
PostgameStory = {
    ensureRuntime = function()
        hits = hits + 1
    end,
}
LateKantoStory.actorMetadata("pokered:PALLET_TOWN:objects:1")
assert(hits == 0, "actor metadata ensured the postgame runtime")
io.write("RESIDENT 0\n")
io.write("DECODED " .. table.concat(decoded, ",") .. "\n")
"""


class PostgameResidencyTests(unittest.TestCase):
    def test_field_install_does_not_keep_postgame_resident(self):
        scenes = (ROOT / "Source/game/kantoScenes.lua").read_text(encoding="utf-8")
        install = scenes.split("function KantoScenes.install()", 1)[1]
        install = install.split("installed = true", 1)[0]
        self.assertNotIn("ensureRuntime", install)
        self.assertNotIn("postgameStory", install)
        main = (ROOT / "Source/main.lua").read_text(encoding="utf-8")
        content = main.split("CoastStoryWorld.install()", 1)[1]
        content = content.split("CopycatService.install()", 1)[0]
        self.assertNotIn("ensureRuntime", content)
        self.assertNotIn("postgameStory", content)
        completed = subprocess.run(
            ["lua5.4", "-", str(ROOT)], input=PROBE, text=True, capture_output=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stderr + completed.stdout)
        self.assertIn("RESIDENT 0", completed.stdout)
        self.assertNotIn("postgame", completed.stdout.split("DECODED", 1)[1])


if __name__ == "__main__":
    unittest.main()
