"""Player decision policy; runtime journeys prove the actual item input flow."""
import unittest

from tools.harness.brock_journey import BrockJourney, choose_battle_medicine
from tools.harness.parcel_journey import Geometry


class BattleMedicinePolicyTests(unittest.TestCase):
    def choose(self, hp=20, status="none", potion=2, antidote=3):
        return choose_battle_medicine(
            {"hp": hp, "maxHP": 23, "status": status},
            {"quantities": {"potion": potion, "antidote": antidote}},
        )

    def test_cure_poison_before_spending_more_turns_attacking(self):
        self.assertEqual(self.choose(hp=14, status="poison"), "antidote")
        self.assertEqual(self.choose(hp=14, status="badPoison"), "antidote")

    def test_critical_health_prioritizes_surviving_the_enemy_response(self):
        self.assertEqual(self.choose(hp=3, status="poison"), "potion")

    def test_heal_damaged_member_without_wasting_full_health_item(self):
        self.assertEqual(self.choose(hp=12), "potion")
        self.assertIsNone(self.choose(hp=23))

    def test_actual_stock_limits_every_choice(self):
        self.assertIsNone(self.choose(hp=3, status="poison", potion=0, antidote=0))
        self.assertEqual(self.choose(hp=3, status="poison", potion=0), "antidote")
        self.assertEqual(self.choose(hp=12, status="poison", antidote=0), "potion")

    def test_fainted_member_requires_replacement_instead_of_potion(self):
        self.assertIsNone(self.choose(hp=0, status="poison"))


class InteractionReplanningTests(unittest.TestCase):
    def journey(self, target):
        source = "pokered:VIRIDIAN_FOREST:objects:2"
        model = Geometry("forest", [[0] * 7], events={
            "objects": [{"id": source, "x": target, "y": 0}],
            "warps": [], "background_events": [],
        })
        journey = BrockJourney(None, "/private/tmp", {"max_steps": 10})
        journey.state = {
            "root": "overworld", "overworld": "explore", "zone_id": "forest",
            "player": {"x": 0, "y": 0, "facing": "right", "settled": True},
            "npcs": [{"source_event_id": source, "x": target, "y": 0}],
            "session": {"flags": {"trainers": {}}},
        }
        journey.model = lambda: model
        commands = []

        def send(command):
            self.assertEqual(command, "press a")
            self.assertEqual(journey.position(), (journey.state["npcs"][0]["x"] - 1, 0))
            commands.append(command)
            journey.state["root"] = "dialog"

        def drain(stop_phase=None):
            journey.state["root"] = "overworld"

        journey.send, journey.drain = send, drain
        return journey, source, commands

    def test_replans_when_battle_return_moves_actor_away_from_cached_target(self):
        journey, source, commands = self.journey(2)
        steps = []

        def step(action):
            journey.state["player"]["x"] = action.destination[0]
            steps.append(action.destination)
            if len(steps) == 1:
                journey.state["npcs"][0]["x"] = 5

        journey.step = step
        journey.interact(source_id=source)
        self.assertEqual(steps, [(1, 0), (2, 0), (3, 0), (4, 0)])
        self.assertEqual(commands, ["press a"])

    def test_actual_trainer_defeat_during_navigation_fulfills_first_interaction(self):
        journey, source, commands = self.journey(5)
        journey.source_trainers[source] = {}

        def step(action):
            journey.state["player"]["x"] = action.destination[0]
            journey.state["session"]["flags"]["trainers"][source] = True

        journey.step = step
        journey.interact(source_id=source)
        self.assertEqual(commands, [])


if __name__ == "__main__":
    unittest.main()
