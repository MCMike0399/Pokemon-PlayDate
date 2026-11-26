"""Lane E's audio hooks and the title cue are installed. The cry hook is not."""
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

    def test_cry_hook_is_unapplied_and_the_title_cue_is_installed(self):
        subprocess.run(['git', 'apply', '--check', 'tools/audio/cry-hooks.patch'], cwd=ROOT, check=True)
        title = (ROOT / 'Source/game/titleState.lua').read_text()
        self.assertIn('KantoAudio.playCue("title")', title)
        pause = (ROOT / 'Source/game/pauseState.lua').read_text()
        self.assertNotIn('playSFX("start_menu")', pause)
        # The lane G note also adds the pause jingle. The title cue is already
        # in titleState, so that combined patch does not apply again.
        for name in ('tools/notes/lane-g-audio-hooks.patch',
                     'tools/notes/lane-e-audio-hooks.patch',
                     'tools/audio/root-hooks.patch'):
            completed = subprocess.run(
                ['git', 'apply', '--check', name],
                cwd=ROOT, check=False, capture_output=True, text=True)
            self.assertNotEqual(completed.returncode, 0, name)


if __name__ == '__main__':
    unittest.main()
