"""Lane E's audio hooks are installed. The cry hook and lane G's hooks are not."""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class AudioHookPatchTests(unittest.TestCase):
    def test_lane_e_hooks_are_installed_once(self):
        main = (ROOT / 'Source/main.lua').read_text()
        self.assertEqual(main.count('import "game/kantoAudio"'), 1)
        self.assertEqual(main.count('KantoAudio.updateGame(game)'), 1)
        overworld = (ROOT / 'Source/game/overworldState.lua').read_text()
        self.assertEqual(overworld.count('KantoAudio.trainerJingle(class, nil)'), 1)
        self.assertEqual(overworld.count('KantoAudio.setTraversal(travel and travel.mode)'), 1)
        scene = (ROOT / 'Source/battle/battleScene.lua').read_text()
        self.assertNotIn('KantoAudio.playCry', scene)

    def test_cry_and_lane_g_hooks_are_still_unapplied(self):
        for name in ('tools/audio/cry-hooks.patch', 'tools/notes/lane-g-audio-hooks.patch'):
            subprocess.run(['git', 'apply', '--check', name], cwd=ROOT, check=True)
        completed = subprocess.run(
            ['git', 'apply', '--check', 'tools/notes/lane-e-audio-hooks.patch'],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertNotEqual(completed.returncode, 0)
        completed = subprocess.run(
            ['git', 'apply', '--check', 'tools/audio/root-hooks.patch'],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertNotEqual(completed.returncode, 0)


if __name__ == '__main__':
    unittest.main()
