"""The root calls KantoAudio after input, and the field hooks play the cues."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaneEAudioHookTests(unittest.TestCase):
    def test_main_updates_audio_after_input(self):
        text = (ROOT / 'Source/main.lua').read_text()
        self.assertIn('import "game/kantoAudio"', text)
        self.assertIn('KantoAudio.updateGame(game)', text)

    def test_trainer_jingle_and_traversal_and_flute_are_hooked(self):
        overworld = (ROOT / 'Source/game/overworldState.lua').read_text()
        travel = (ROOT / 'Source/game/fieldTravelState.lua').read_text()
        gear = (ROOT / 'Source/game/fieldGearState.lua').read_text()
        flute = (ROOT / 'Source/game/snorlaxStory.lua').read_text()
        self.assertIn('KantoAudio.trainerJingle', overworld)
        self.assertIn('KantoAudio.setTraversal', overworld)
        self.assertIn('KantoAudio.setTraversal', travel)
        self.assertIn('KantoAudio.setTraversal', gear)
        self.assertEqual(flute.count('KantoAudio.playCue("flute")'), 1)

    def test_hall_flute_arrow_and_denied_call_sites(self):
        endgame = (ROOT / 'Source/game/endgameStory.lua').read_text()
        event = (ROOT / 'Source/game/eventState.lua').read_text()
        flute = (ROOT / 'Source/game/snorlaxStory.lua').read_text()
        self.assertIn('KantoAudio.playCue("hall_of_fame")', endgame)
        self.assertIn('KantoAudio.playCry(entry.cry)', endgame)
        self.assertIn('KantoAudio.playCue(step.audio.name)', endgame)
        self.assertIn('KantoAudio.playCue(state.plan.audio.name)', endgame)
        self.assertIn('KantoAudio.playSFX("arrow_tiles")', event)
        self.assertEqual(flute.count('KantoAudio.playCue("flute")'), 1)


if __name__ == '__main__':
    unittest.main()
