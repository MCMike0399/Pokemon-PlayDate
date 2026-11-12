"""Lane E has not applied the audio hooks. expectedFailure keeps the suite green."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaneEAudioHookTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_main_updates_audio_after_input(self):
        text = (ROOT / 'Source/main.lua').read_text()
        self.assertIn('import "game/kantoAudio"', text)
        self.assertIn('KantoAudio.updateGame(game)', text)

    @unittest.expectedFailure
    def test_trainer_jingle_and_traversal_and_flute_are_hooked(self):
        overworld = (ROOT / 'Source/game/overworldState.lua').read_text()
        travel = (ROOT / 'Source/game/fieldTravelState.lua').read_text()
        gear = (ROOT / 'Source/game/fieldGearState.lua').read_text()
        flute = (ROOT / 'Source/game/snorlaxStory.lua').read_text()
        self.assertIn('KantoAudio.trainerJingle', overworld)
        self.assertIn('KantoAudio.setTraversal', overworld)
        self.assertIn('KantoAudio.setTraversal', travel)
        self.assertIn('KantoAudio.setTraversal', gear)
        self.assertIn('KantoAudio.playCue("flute")', flute)


if __name__ == '__main__':
    unittest.main()
