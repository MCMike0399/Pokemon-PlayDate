"""Pokered af519899 fidelity checks against this tip.

Passing cases are already on the tree. The expected failures are the
gaps in tools/notes/lane-e-viridian-sight.patch and
tools/notes/lane-e-money-yen.patch.
"""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SIGHT = ROOT / "tools/notes/lane-e-viridian-sight.patch"
MONEY = ROOT / "tools/notes/lane-e-money-yen.patch"


class LandedFidelityTests(unittest.TestCase):
    def test_blackout_page_and_checkpoint_warp(self):
        # text/text_2.asm _PlayerBlackedOutText2. OaksLab is the exception.
        # scripts/Route22.asm Route22Rival2AfterBattleScript returns on LOST_BATTLE.
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        branch = battle.split("if not playerTeamAlive then", 1)[1].split('return "defeat"', 1)[0]
        self.assertIn('is out of\\nuseable POKéMON!', branch)
        self.assertIn('blacked\\nout!', branch)
        self.assertIn('intro.stage == "rival_fight"', branch)
        state = (ROOT / "Source/game/battleState.lua").read_text()
        self.assertIn("game:returnToCheckpoint()", state)
        lost = state.split("if not receipt.won then", 1)[1]
        self.assertLess(lost.index("if blackout then return end"), lost.index("descriptor.lost"))

    def test_shift_and_nurse_yes_no(self):
        # text/text_1.asm _TrainerAboutToUseText then TWO_OPTION_MENU.
        battle = (ROOT / "Source/battle/battle.lua").read_text()
        self.assertIn('text = "Will " .. playerName .. "\\nchange POKéMON?"', battle)
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        self.assertIn('self.shiftMenu:show({"YES", "NO"}', scene)
        # scripts/Pokecenter.asm nurse prompt is also TWO_OPTION_MENU.
        heal = (ROOT / "Source/game/eventState.lua").read_text().split("function EventState:heal", 1)[1]
        heal = heal.split("\nfunction ", 1)[0]
        self.assertIn('self.menu:show({"YES","NO"}', heal)

    def test_viridian_arrow_tiles_spin(self):
        # scripts/ViridianGym.asm arrow tiles. SFX_ARROW_TILES.
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        self.assertIn('id == "pokered:VIRIDIAN_GYM:script:arrow"', story)
        self.assertIn("EndgameStory.arrow(x, y)", story)
        visual = (ROOT / "Source/data/endgame/visual.json").read_text()
        self.assertIn('"score": "arrow_tiles"', visual)
        self.assertIn('"source": "SFX_ARROW_TILES"', visual)

    def test_elite_four_and_champion_pics(self):
        # constants/trainer_constants.asm OPP_LORELEI, OPP_BRUNO, OPP_AGATHA,
        # OPP_LANCE, and the champion OPP_RIVAL3.
        story = (ROOT / "Source/data/endgame/story.json").read_text()
        for label in ("OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE", "OPP_RIVAL3"):
            self.assertIn(label, story)
            pic = ROOT / "Source/images/title/trainers" / (label.removeprefix("OPP_") + ".png")
            self.assertTrue(pic.is_file(), pic)
        scene = (ROOT / "Source/battle/battleScene.lua").read_text()
        self.assertIn('gfx.image.new("images/title/trainers/" .. class)', scene)

    def test_prize_and_mart_yen(self):
        # data/text/text_2.asm _MoneyForWinningText uses the charmap yen ($f0).
        play = (ROOT / "Source/data/endgame/play.json").read_text()
        self.assertIn("<PLAYER> got ¥@", play)
        shop = (ROOT / "Source/game/shopState.lua").read_text()
        self.assertIn('GbFont.drawMoneyRight("¥"', shop)
        idle = (ROOT / "Source/game/titleIdle.lua").read_text()
        self.assertIn('["¥"]', idle)


class FidelityGapTests(unittest.TestCase):
    def test_sight_and_yen_patches_apply(self):
        for patch in (SIGHT, MONEY):
            self.assertTrue(patch.is_file(), patch)
            self.assertNotIn("MallocPoolSize", patch.read_text())

    def test_viridian_trainers_are_not_talk_only(self):
        # TrainerEvents rejects sight when talk_only is set
        # (trainer-has-no-sight). scripts/ViridianGym.asm gives the eight
        # trainers a range. Giovanni has none, so he stays talk-only.
        row = (ROOT / "Source/game/endgameStory.lua").read_text()
        row = row.split("local function trainerRow", 1)[1].split("local function trainerEvent", 1)[0]
        self.assertIn("talk_only = (row.sight or 0) == 0", row)

    def test_trainer_card_and_payday_use_yen(self):
        # start_sub_menus.asm TrainerInfo_NameMoneyTimeText.
        card = (ROOT / "Source/game/pauseState.lua").read_text()
        self.assertNotIn("MONEY/$", card)
        self.assertIn('GbFont.drawMoneyLine("¥"', card)
        # data/text/text_2.asm _PickUpPayDayMoneyText, after a win.
        won = (ROOT / "Source/battle/battle.lua").read_text()
        won = won.split("if won then", 1)[1].split('return "victory"', 1)[0]
        self.assertIn("picked up\\n¥", won)


if __name__ == "__main__":
    unittest.main()
