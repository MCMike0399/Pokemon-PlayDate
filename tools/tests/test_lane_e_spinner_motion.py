"""Viridian Gym arrow tiles redirect and change frame.

pret/pokered af519899 scripts/ViridianGym.asm
ViridianGymArrowTilePlayerMovement is the twelve RLE paths.
engine/overworld/spinners.asm LoadSpinnerArrowTiles advances
SpinnerPlayerFacingDirections (down to left, left to up, up to right,
right to down) and swaps the arrow graphic with bit 0 of the remaining
simulated steps. This host check runs that facing cycle and the before/after
tile swap. It does not re-hand the sight patch.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.tests.test_lane_d_endgame import lua_binary, lua_literal

ROOT = Path(__file__).resolve().parents[2]

# scripts/ViridianGym.asm ViridianGymArrowMovement1 through 12.
PATHS = [
    (19, 11, "up", 9),
    (19, 1, "left", 8),
    (18, 2, "down", 9),
    (11, 2, "right", 6),
    (16, 10, "down", 2),
    (4, 6, "down", 7),
    (5, 13, "right", 8),
    (4, 14, "right", 9),
    (0, 15, "up", 8),
    (1, 15, "up", 6),
    (13, 16, "left", 6),
    (13, 17, "left", 12),
]

PROBE = r'''
json = { decodeFile = function(path)
    if string.find(path, "play.json", 1, true) then return play end
    if string.find(path, "visual.json", 1, true) then return visual end
    return story
end }
dofile(module_path)
local function check(actual, expected, label)
    if actual ~= expected then
        error(label .. " got " .. tostring(actual) .. " expected " .. tostring(expected))
    end
end
local drawn = {}
SpriteFactory = { makeSprite = function(grid) return grid end }
TILE_SIZE = 32
playdate = { graphics = { sprite = { new = function(image)
    local sprite = { image = image }
    function sprite:setCenter() end
    function sprite:moveTo(x, y) self.x, self.y = x, y end
    function sprite:setZIndex() end
    function sprite:add() drawn[#drawn + 1] = self end
    function sprite:remove() end
    return sprite
end } } }
local data = EndgameStory.story()
check(#data.viridian_gym.arrows, 12, "twelve arrow tiles")
for index, tile in ipairs(data.viridian_gym.arrows) do
    local plan = EndgameStory.plan("pokered:VIRIDIAN_GYM:script:arrow",
        {arrow_x = tile.x, arrow_y = tile.y, flags = {}})
    check(plan.spin, true, "spin")
    check(plan.audio.source, "SFX_ARROW_TILES", "cue")
    local total, direction = 0, nil
    for _, step in ipairs(plan.steps) do
        check(step.op, "move", "redirect is a move")
        direction = direction or step.direction
        check(step.direction, direction, "one direction")
        total = total + step.count
    end
    check(tile.x .. "," .. tile.y .. " " .. direction .. " " .. total,
        paths[index], "rle")
end
local facing = "down"
local order = {"left", "up", "right", "down"}
for _, expected in ipairs(order) do
    facing = EndgameStory.spinnerFacing(facing)
    check(facing, expected, "facing cycle")
end
local state = {
    player = { facing = "down", updateSprite = function() end },
    plan = { spin = true },
    index = 1,
    ops = { {op = "move"}, {op = "move"} },
}
EndgameStory.spinTick(state)
check(state.player.facing, "left", "first tick turns")
check(state.spinAnim, false, "even remaining steps use the resting arrow")
check(drawn[1].image[1], visual.spinner.cells[1].before[1], "resting frame")
check(drawn[1].x, visual.spinner.cells[1].x * 32, "arrow x")
check(drawn[1].y, visual.spinner.cells[1].y * 32, "arrow y")
state.index = 2
EndgameStory.spinTick(state)
check(state.player.facing, "up", "second tick turns again")
check(state.spinAnim, true, "odd remaining step uses the other arrow")
check(drawn[#drawn].image[1], visual.spinner.cells[1].after[1], "moved frame")
print("spinner-motion-ok")
'''


class SpinnerMotionTests(unittest.TestCase):
    def test_arrows_redirect_and_swap_frames(self):
        story = json.loads((ROOT / "Source/data/endgame/story.json").read_text())
        play = json.loads((ROOT / "Source/data/endgame/play.json").read_text())
        visual = json.loads((ROOT / "Source/data/endgame/visual.json").read_text())
        paths = [f"{x},{y} {direction} {count}" for x, y, direction, count in PATHS]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.lua"
            path.write_text(
                "story = " + lua_literal(story)
                + "\nplay = " + lua_literal(play)
                + "\nvisual = " + lua_literal(visual)
                + "\npaths = " + lua_literal(paths)
                + "\nmodule_path = " + json.dumps(str(ROOT / "Source/game/endgameStory.lua"))
                + "\n" + PROBE)
            completed = subprocess.run(
                [lua_binary(), str(path)], check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        self.assertIn("spinner-motion-ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
