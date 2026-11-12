"""Battle pictures keep interior white and drop exterior white.

Lane E has not applied this yet. tools/notes/lane-e-sprite-mask.patch
flood-fills white from each picture's edges when the sprite is scaled.
White inside the silhouette stays opaque. The mask is cached with the
scaled picture, so it is not recomputed every frame.
"""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-sprite-mask.patch"

# A black ring. The center is white and does not touch the edge.
PROBE = r"""
dofile("Source/battle/spriteMask.lua")
local width, height = 5, 5
local grid = {
    {1, 1, 1, 1, 1},
    {1, 0, 0, 0, 1},
    {1, 0, 1, 0, 1},
    {1, 0, 0, 0, 1},
    {1, 1, 1, 1, 1},
}
local seen = SpriteMask.exterior(width, height, function(x, y)
    return grid[y + 1][x + 1] == 1
end)
assert(seen[0 * width + 0], "exterior white stays transparent")
assert(not seen[2 * width + 2], "interior white stays opaque")
print("mask-pixels-ok")
"""


class LaneESpriteMaskTests(unittest.TestCase):
    def test_sprite_mask_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        scratch = Path(tempfile.mkdtemp(prefix="lane-e-mask-"))
        try:
            completed = subprocess.run(
                ["git", "worktree", "add", "--detach", str(scratch), "HEAD"],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["git", "apply", str(PATCH)],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            scene = (scratch / "Source/battle/battleScene.lua").read_text()
            self.assertIn("SpriteMask.exterior", scene)
            self.assertIn("image:addMask(true)", scene)
            completed = subprocess.run(
                ["lua", "-e", PROBE],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertIn("mask-pixels-ok", completed.stdout)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    @unittest.expectedFailure
    def test_sprites_mask_exterior_white(self):
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        self.assertIn("SpriteMask.exterior", scene)
        self.assertIn("image:addMask(true)", scene)


if __name__ == "__main__":
    unittest.main()
