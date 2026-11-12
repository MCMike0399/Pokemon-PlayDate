"""Title music is TitleState's call. The start-menu sound stays on lane F's
observer, which already plays SFX_START_MENU when the pause menu opens.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaneGAudioHookTests(unittest.TestCase):
    def test_title_calls_the_title_cue(self):
        title = (ROOT / "Source/game/titleState.lua").read_text()
        pause = (ROOT / "Source/game/pauseState.lua").read_text()
        self.assertIn('KantoAudio.playCue("title")', title)
        self.assertNotIn('KantoAudio.playSFX("start_menu")', pause)


if __name__ == "__main__":
    unittest.main()
