#!/usr/bin/env python3
"""The Route 22 rematch keeps the walk lease into the trainer step.

Talking to BLUE from the tile above him walks him east, then the trainer
step claims that same actor again. claimScript rejects the second lease
with source-actor-already-claimed, so the battle never starts. The event
already owns the actor; the trainer step must leave that lease alone.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Route22RivalTests(unittest.TestCase):
    def test_trainer_step_keeps_the_event_lease(self):
        trainers = (ROOT / "Source/game/trainerEvents.lua").read_text()
        prepare = trainers.split("function TrainerEvents:prepare(npc,mode,scriptOwner)", 1)[1].split(
            "function TrainerEvents:", 1)[0]
        self.assertIn("scriptHeldBy", prepare)
        held = prepare.index("scriptHeldBy")
        claim = prepare.index("claimScript")
        self.assertLess(held, claim)
        self.assertIn("if not motion:scriptHeldBy(npc, scriptOwner) then", prepare)
        motion = (ROOT / "Source/world/npcMotion.lua").read_text()
        self.assertIn("function NPCMotion:scriptHeldBy(npc, owner)", motion)
        self.assertLess(
            motion.index("function NPCMotion:scriptHeldBy"),
            motion.index("function NPCMotion:isScriptOwner"))


if __name__ == "__main__":
    unittest.main()
