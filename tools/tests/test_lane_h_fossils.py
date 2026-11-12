"""Fossil lab dialogue, the Mt. Moon choice, and the wFossilItem handoff."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CAVE = importlib.util.spec_from_file_location('lane_h_cave', ROOT / 'tools/tests/test_lane_h_cerulean_cave.py')
CAVE_MODULE = importlib.util.module_from_spec(CAVE)
CAVE.loader.exec_module(CAVE_MODULE)


class FossilLabTests(unittest.TestCase):
    def test_codec_patch_adds_the_fossil_byte_and_is_installed(self):
        live = (ROOT / 'Source/domain/sessionCodec.lua').read_text()
        self.assertIn('wFossilItem=true', live)
        self.assertIn('data.wFossilItem = fossilItemByte(data.questFlags)', live)
        self.assertIn('OLD_AMBER=31,DOME_FOSSIL=41,HELIX_FOSSIL=42', live)
        self.assertIn('if data.wFossilItem~=nil then', live)
        patch = (ROOT / 'tools/notes/lane-e-fossil-item.patch').read_text()
        self.assertIn('wFossilItem=true', patch)
        completed = subprocess.run(['patch', '--dry-run', '--fuzz=0', '-p1'], input=patch, text=True,
                                   cwd=ROOT, capture_output=True, check=False)
        self.assertNotEqual(completed.returncode, 0, completed.stdout)

    def test_lab_dialogue_writes_the_fossil_before_yes_and_clears_on_the_island(self):
        story = json.loads((ROOT / 'Source/data/postgame/story.json').read_text())
        play = json.loads((ROOT / 'Source/data/postgame/play.json').read_text())
        self.assertEqual(story['fossil']['scientist']['id'], 'pokered:CINNABAR_LAB_FOSSIL_ROOM:objects:1')
        self.assertEqual(play['texts']['_CinnabarLabFossilRoomScientist1Text']['recipe'][0]['text'], 'Hiya!')
        probe = r'''
json = { decodeFile = function(path)
    if string.find(path, "play.json", 1, true) then return play end
    return story
end }
dofile(module_path)
local calls = {}
FossilRevival = {
    talk = function() return {status = "offer", fossils = {"DOME_FOSSIL", "OLD_AMBER"}} end,
    confirm = function(_, symbol, accepted)
        calls[#calls + 1] = symbol .. ":" .. tostring(accepted)
        if accepted then return {ok = true, status = "reviving"} end
        return {ok = true, status = "cancelled"}
    end,
    cancel = function()
        calls[#calls + 1] = "cancel"
        return {ok = true, status = "cancelled"}
    end,
    onMapLoad = function(_, map)
        calls[#calls + 1] = "map:" .. map
        return {ok = true, status = "cleared"}
    end,
}
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local opened = PostgameStory.fossilOpen({})
check(opened.status, "offer", "offer")
check(opened.labels[1], "_CinnabarLabFossilRoomScientist1Text", "intro")
check(opened.fossils[1], "DOME_FOSSIL", "first fossil")
local selected = PostgameStory.fossilSelect({}, "DOME_FOSSIL")
check(calls[1], "DOME_FOSSIL:false", "byte before yes")
check(selected.labels[1], "_CinnabarLabFossilRoomScientist1SeesFossilText", "sees")
local accepted = PostgameStory.fossilAnswer({}, "DOME_FOSSIL", true)
check(calls[2], "DOME_FOSSIL:true", "yes removes it")
check(accepted.labels[1], "_CinnabarLabFossilRoomScientist1TakesFossilText", "takes")
check(accepted.labels[2], "_CinnabarLabFossilRoomScientist1GoForAWalkText2", "walk")
local declined = PostgameStory.fossilAnswer({}, "HELIX_FOSSIL", false)
check(declined.labels[1], "_CinnabarLabFossilRoomScientist1ComeAgainText", "no")
check(calls[3], "cancel", "no does not confirm again")
local empty = PostgameStory.fossilOpen({})
FossilRevival.talk = function() return {status = "no-fossils"} end
empty = PostgameStory.fossilOpen({})
check(empty.labels[1], "_CinnabarLabFossilRoomScientist1NoFossilsText", "none")
FossilRevival.talk = function() return {status = "still-reviving"} end
check(PostgameStory.fossilOpen({}).labels[1], "_CinnabarLabFossilRoomScientist1GoForAWalkText", "waiting")
FossilRevival.talk = function() return {status = "revived", species = "KABUTO"} end
check(PostgameStory.fossilOpen({}).labels[1], "_CinnabarLabFossilRoomScientist1FossilIsBackToLifeText", "alive")
check(PostgameStory.fossilPlan("pokered:CINNABAR_LAB_FOSSIL_ROOM:objects:1").scene_script, "fossil", "scene")
currentZone = {stableID = "pokered:CINNABAR_ISLAND"}
PostgameStory.onEnter({session = {}})
check(calls[#calls], "map:CINNABAR_ISLAND", "island clears the revival")
currentZone = {stableID = "pokered:PALLET_TOWN"}
PostgameStory.onEnter({session = {}})
check(calls[#calls], "map:CINNABAR_ISLAND", "other maps leave the flag")
print("lane-h fossil ok")
'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'probe.lua'
            path.write_text('story = ' + CAVE_MODULE.lua_literal(story)
                            + '\nplay = ' + CAVE_MODULE.lua_literal(play)
                            + '\nmodule_path = ' + json.dumps(str(ROOT / 'Source/game/postgameStory.lua'))
                            + '\n' + probe)
            completed = subprocess.run([CAVE_MODULE.lua_binary(), str(path)], check=False,
                                       capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn('lane-h fossil ok', completed.stdout)


if __name__ == '__main__':
    unittest.main()
