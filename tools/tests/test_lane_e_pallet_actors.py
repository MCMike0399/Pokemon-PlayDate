"""Install Pallet actors from the pinned zRemainder strips.

Lane E has not applied this yet. tools/notes/lane-e-pallet-actors.patch
is only the nine Pallet strips. A content-cache hit still wins. Elite
Four, Colosseum and Trade Center actors stay unresolved.
"""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "tools/notes/lane-e-pallet-actors.patch"
ACTORS = (
    "SPRITE_OAK", "SPRITE_BLUE", "SPRITE_SCIENTIST", "SPRITE_MOM", "SPRITE_DAISY",
    "SPRITE_GIRL", "SPRITE_FISHER", "SPRITE_POKEDEX", "SPRITE_POKE_BALL",
)


def assert_pallet_fallback(source):
    for name in ACTORS:
        if f"{name} = true" not in source:
            raise AssertionError(f"missing Pallet fallback for {name}")
    if "SPRITE_RED = true" in source or "SPRITE_AGATHA = true" in source:
        raise AssertionError("fallback includes an actor outside Pallet")
    if "data/zRemainder/sprites.json" not in source:
        raise AssertionError("fallback does not read the pinned sprite catalog")
    if "if found then return found end" not in source:
        raise AssertionError("catalog hit does not win over the fallback")


class LaneEPalletActorTests(unittest.TestCase):
    def test_pallet_actors_patch_applies(self):
        completed = subprocess.run(
            ["git", "apply", "--check", str(PATCH)],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        scratch = Path(tempfile.mkdtemp(prefix="lane-e-pallet-actors-"))
        try:
            completed = subprocess.run(
                ["git", "worktree", "add", "--detach", str(scratch), "HEAD"],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            completed = subprocess.run(
                ["git", "apply", str(PATCH)],
                cwd=scratch, check=False, capture_output=True, text=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            assert_pallet_fallback((scratch / "Source/data/ceruleanContent.lua").read_text())
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(scratch)], cwd=ROOT, check=False)
            shutil.rmtree(scratch, ignore_errors=True)

    @unittest.expectedFailure
    def test_pallet_maps_have_actor_strips(self):
        assert_pallet_fallback((ROOT / "Source/data/ceruleanContent.lua").read_text())


if __name__ == "__main__":
    unittest.main()
