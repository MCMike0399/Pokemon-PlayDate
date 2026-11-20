#!/usr/bin/env python3
"""Trainer victory text leaves the battle before pokered's three pages.

pret/pokered af519899 engine/battle/core.asm TrainerBattleVictory prints
TrainerDefeatedText ("<PLAYER> defeated" / "<TRAINER>!"), then
PrintEndBattleText, then MoneyForWinningText ("<PLAYER> got ¥@" / "for
winning!"), and only then returns to the map.

Gym leaders save the badge speech as that end-battle text. Brock's script
also prints the Boulder Badge info there. Misty, Lt. Surge, and Erika print
only the "received the badge" page inside the battle. The badge info and the
TM gift are the map script after the fade. A regular trainer's end-battle
text is the EndBattle page. The AfterBattle page is the next conversation.

The port assigns "You defeated <TRAINER>!" and returns. The won pages and
_MoneyForWinningText then play on the overworld, so the prize follows the
fade and, for Lt. Surge, follows the badge text. This test fails until
tools/notes/lane-e-trainer-victory-text.patch is applied. That patch says
the three pages on the battle screen and drops the overworld copy. The
reward and after branches stay on the map.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POKERED = Path("/tmp/pokered")
BATTLE = ROOT / "Source/battle/battle.lua"
EVENTS = ROOT / "Source/game/sourceEvents.lua"
PATCH = ROOT / "tools/notes/lane-e-trainer-victory-text.patch"


def load_events(*relatives):
    found = {}
    for relative in relatives:
        data = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        found.update(data.get("events") or data)
    return found


def script_between(asm, start, stop):
    body = asm.split(start, 1)[1]
    return body.split(stop, 1)[0]


class TrainerVictoryTextTest(unittest.TestCase):
    def test_gym_leaders_and_a_regular_trainer_match_pokered(self):
        pewter = (POKERED / "scripts/PewterGym.asm").read_text(encoding="utf-8")
        cerulean = (POKERED / "scripts/CeruleanGym.asm").read_text(encoding="utf-8")
        vermilion = (POKERED / "scripts/VermilionGym.asm").read_text(encoding="utf-8")
        celadon = (POKERED / "scripts/CeladonGym.asm").read_text(encoding="utf-8")
        text = (POKERED / "data/text/text_2.asm").read_text(encoding="utf-8")
        defeated = script_between(text, "_TrainerDefeatedText::", "_PlayerMonFaintedText::")
        prize = script_between(text, "_MoneyForWinningText::", "_TrainerDefeatedText::")
        self.assertIn('text "<PLAYER> defeated"', defeated)
        self.assertIn('text_ram wTrainerName', defeated)
        self.assertIn('text "<PLAYER> got ¥@"', prize)
        self.assertIn('line "for winning!"', prize)

        brock_end = script_between(
            pewter, "PewterGymBrockReceivedBoulderBadgeText:", "PewterGymCooltrainerMText:")
        self.assertIn("_PewterGymBrockReceivedBoulderBadgeText", brock_end)
        self.assertIn("_PewterGymBrockBoulderBadgeInfoText", brock_end)
        self.assertIn("TEXT_PEWTERGYM_BROCK_WAIT_TAKE_THIS", pewter)
        self.assertIn(
            "PewterGymCooltrainerMBattleText, PewterGymCooltrainerMEndBattleText, PewterGymCooltrainerMAfterBattleText",
            pewter,
        )

        self.assertIn("CeruleanGymMistyReceivedCascadeBadgeText", cerulean)
        self.assertIn("TEXT_CERULEANGYM_MISTY_CASCADE_BADGE_INFO", cerulean)
        self.assertIn("TEXT_CERULEANGYM_MISTY_RECEIVED_TM11", cerulean)
        misty_end = script_between(
            cerulean, "CeruleanGymMistyReceivedCascadeBadgeText:", "CeruleanGymCooltrainerFText:")
        self.assertNotIn("CascadeBadgeInfo", misty_end)

        self.assertIn("VermilionGymLTSurgeReceivedThunderBadgeText", vermilion)
        self.assertIn("TEXT_VERMILIONGYM_LT_SURGE_THUNDER_BADGE_INFO", vermilion)
        self.assertIn("TEXT_VERMILIONGYM_LT_SURGE_RECEIVED_TM24", vermilion)
        surge_end = script_between(
            vermilion, "VermilionGymLTSurgeReceivedThunderBadgeText:", "VermilionGymGentlemanText:")
        self.assertNotIn("ThunderBadgeInfo", surge_end)
        self.assertIn(
            "VermilionGymGentlemanBattleText, VermilionGymGentlemanEndBattleText, VermilionGymGentlemanAfterBattleText",
            vermilion,
        )

        self.assertIn(".ReceivedRainbowBadgeText", celadon)
        self.assertIn("TEXT_CELADONGYM_RAINBOWBADGE_INFO", celadon)
        self.assertIn("TEXT_CELADONGYM_RECEIVED_TM21", celadon)
        erika_end = script_between(celadon, ".ReceivedRainbowBadgeText:", ".PostBattleAdviceText:")
        self.assertNotIn("RainbowBadgeInfo", erika_end)

        events = load_events(
            "Source/data/sourceEvents.json",
            "Source/data/ceruleanStory/events.json",
            "Source/data/vermilionStory/events.json",
            "Source/data/vermilionPreparation/events.json",
            "Source/data/midgameGymStory/events.json",
        )
        brock = events["pokered:PEWTER_GYM:objects:1"]
        junior = events["pokered:PEWTER_GYM:objects:2"]
        misty = events["pokered:CERULEAN_GYM:objects:1"]
        surge = events["pokered:VERMILION_GYM:objects:1"]
        gentleman = events["pokered:VERMILION_GYM:objects:2"]
        erika = events["pokered:CELADON_GYM:objects:1"]
        self.assertEqual(brock["won"], [
            "_PewterGymBrockReceivedBoulderBadgeText",
            "_PewterGymBrockBoulderBadgeInfoText",
        ])
        self.assertEqual(brock["reward"]["before"], ["_PewterGymBrockWaitTakeThisText"])
        self.assertIn("_PewterGymReceivedTM34Text", brock["reward"]["success"])
        self.assertEqual(misty["won"], ["_CeruleanGymMistyReceivedCascadeBadgeText"])
        self.assertEqual(misty["reward"]["before"], ["_CeruleanGymMistyCascadeBadgeInfoText"])
        self.assertIn("_CeruleanGymMistyReceivedTM11Text", misty["reward"]["success"])
        self.assertEqual(surge["won"], ["_VermilionGymLTSurgeReceivedThunderBadgeText"])
        self.assertEqual(surge["reward"]["before"], ["_VermilionGymLTSurgeThunderBadgeInfoText"])
        self.assertIn("_VermilionGymLTSurgeReceivedTM24Text", surge["reward"]["success"])
        self.assertEqual(erika["won"], ["_CeladonGymErikaReceivedRainbowBadgeText"])
        self.assertEqual(erika["reward"]["before"], ["_CeladonGymRainbowBadgeInfoText"])
        self.assertIn("_CeladonGymReceivedTM21Text", erika["reward"]["success"])
        self.assertEqual(junior["won"], ["_PewterGymCooltrainerMEndBattleText"])
        self.assertEqual(junior["after"], ["_PewterGymCooltrainerMAfterBattleText"])
        self.assertIsNone(junior.get("reward"))
        self.assertEqual(gentleman["won"], ["_VermilionGymGentlemanEndBattleText"])
        self.assertEqual(gentleman["after"], ["_VermilionGymGentlemanAfterBattleText"])
        self.assertIsNone(gentleman.get("reward"))

    def test_victory_pages_are_said_inside_the_battle(self):
        patch = PATCH.read_text(encoding="utf-8")
        battle = BATTLE.read_text(encoding="utf-8")
        events = EVENTS.read_text(encoding="utf-8")
        body = battle.split("function Battle:_resolveFaintCheckpoint", 1)[1].split("\nfunction ", 1)[0]
        trainer_fn = events.split("local function trainer(d, state, id)", 1)[1].split("\nlocal function ", 1)[0]
        defeat = 'self:say(playerName .. " defeated " .. self.trainerName .. "!")'
        self.assertIn(defeat, patch)
        self.assertLess(patch.index(defeat), patch.index("self.endBattleLines"))
        self.assertLess(patch.index("self.endBattleLines"), patch.index("self:say(self.prizeLine)"))
        self.assertIn("said on the battle screen before the fade", patch)
        self.assertNotIn('dialog({ "_MoneyForWinningText" }', trainer_fn,
            "Drop the overworld prize. Say the defeat line, the end-battle "
            "text, and the prize before returning victory. "
            "Apply tools/notes/lane-e-trainer-victory-text.patch")
        self.assertIn(defeat, body)
        self.assertLess(body.index(defeat), body.index("self.endBattleLines"))
        self.assertLess(body.index("self.endBattleLines"), body.index("self:say(self.prizeLine)"))
        self.assertLess(body.index("self:say(self.prizeLine)"), body.index('return "victory"'))
        self.assertIn("dialog(r.before)", trainer_fn)
        self.assertIn("dialog(d.after)", trainer_fn)


if __name__ == "__main__":
    unittest.main()
