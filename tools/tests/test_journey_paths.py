import unittest
from tools.harness.journeys import lookup


class JourneySnapshotPaths(unittest.TestCase):
    def test_one_based_moves_match_runtime_paths(self):
        state = {"pokemon": {"moves": ["scratch", "growl", "ember"]}}
        self.assertEqual(lookup(state, "pokemon.moves.1"), "scratch")
        self.assertEqual(lookup(state, "pokemon.moves.3"), "ember")
        self.assertIsNone(lookup(state, "pokemon.moves.0"))
        self.assertIsNone(lookup(state, "pokemon.moves.4"))

    def test_nested_records_and_false_values_are_retained(self):
        state = {"party": [{"hp": 0, "alive": False}]}
        self.assertEqual(lookup(state, "party.1.hp"), 0)
        self.assertIs(lookup(state, "party.1.alive"), False)
        self.assertIsNone(lookup(state, "party.2.hp"))
        self.assertIsNone(lookup(state, "missing.path"))
