"""Sound-fidelity handoffs. Each test fails until its patch is applied.

No skip and no expectedFailure. The patches are not applied on this branch.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LaneEAudioFidelityTests(unittest.TestCase):
    def test_center_heal_repeats_the_machine_once_per_party_member(self):
        text = (ROOT / 'Source/game/kantoAudio.lua').read_text()
        self.assertIn('local count = healing.healCount', text)
        self.assertIn('names[#names + 1] = "healing_machine"', text)
        self.assertIn('names[#names + 1] = "heal"', text)

    def test_source_audio_steps_play_the_script_cry(self):
        text = (ROOT / 'Source/game/eventState.lua').read_text()
        self.assertIn('KantoAudio.playCry(step.species)', text)

    def test_pokedex_entry_plays_the_shown_species_cry(self):
        text = (ROOT / 'Source/game/pokedexState.lua').read_text()
        self.assertIn('function PokedexState:playShownCry()', text)
        self.assertIn('KantoAudio.playCry(view.species)', text)
        self.assertEqual(text.count('self:playShownCry()'), 2)

    def test_boulder_and_earth_badges_play_the_item_fanfare(self):
        events = (ROOT / 'Source/audio/events.lua').read_text()
        generator = (ROOT / 'tools/audio/events.py').read_text()
        self.assertIn(
            '["badge"] = {score="item", kind="jingle", source="home/text.asm:546", token="SFX_GET_ITEM_1"}',
            events)
        self.assertIn("('badge', 'item', 'jingle', 'home/text.asm', 'SFX_GET_ITEM_1')", generator)

    def test_player_faint_plays_the_battle_mon_cry(self):
        # engine/battle/core.asm:1042 PlayCry of wBattleMonSpecies.
        # tools/notes/lane-e-audio-player-faint-cry.patch
        text = (ROOT / 'Source/game/kantoAudio.lua').read_text()
        self.assertIn('observer.pendingCry = species', text)
        self.assertIn('KantoAudio.playCry(observer.pendingCry)', text)
        self.assertNotIn('playSequence({moveCue, "faint"})', text)
        self.assertNotIn("The player's own faint is the thud alone.", text)

    def test_move_sfx_table_is_imported_at_file_scope(self):
        # pdc compiles import strings it can see at file scope. The lazy
        # import inside moveScore leaves KantoMoveSfx nil and the first
        # move crashes. tools/notes/lane-e-audio-movesfx-import.patch
        text = (ROOT / 'Source/game/kantoAudio.lua').read_text()
        head = text.split('function KantoAudio', 1)[0]
        self.assertIn('import "audio/moveSfx"', head)


if __name__ == '__main__':
    unittest.main()
