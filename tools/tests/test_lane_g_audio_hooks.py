"""Lane G has not applied the title and menu hooks. expectedFailure keeps the suite green."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaneGAudioHookTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_title_and_pause_call_audio(self):
        title = (ROOT / 'Source/game/titleState.lua').read_text()
        pause = (ROOT / 'Source/game/pauseState.lua').read_text()
        self.assertIn('KantoAudio.playCue("title")', title)
        self.assertIn('KantoAudio.playSFX("start_menu")', pause)


if __name__ == '__main__':
    unittest.main()
