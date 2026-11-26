#!/usr/bin/env python3
"""The Hall continue fixture must carry the flags a champion has set.

A real run cannot reach the Hall of Fame without Oak's Parcel, the Pokédex,
and the awake old man. Those are the same pokered events the generator cites.
The fixture file is the generator output. A hand-edited pin fails this test.
"""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.generate_hall_continue_fixture import (
    BROCK,
    CATCH_BALL,
    FIXTURE,
    QUEST_FLAGS,
    bound_checksum,
    champion_hall_save,
)


class HallContinueFixtureTest(unittest.TestCase):
    def test_fixture_matches_the_generator_and_has_the_dex(self):
        raw = FIXTURE.read_bytes()
        generated = champion_hall_save(raw)
        self.assertEqual(raw, generated)
        envelope = json.loads(raw)
        payload = json.loads(envelope["payload"])
        self.assertEqual(
            envelope["checksum"],
            bound_checksum(envelope["schema"], envelope["sequence"], envelope["payload"]),
        )
        for flag in QUEST_FLAGS:
            self.assertIs(payload["questFlags"].get(flag), True, flag)
        self.assertIs(payload["trainerFlags"].get(BROCK), True)
        self.assertIn(CATCH_BALL, payload["inventory"]["slots"])
        # The Hall reset clears the indigo range. A continue save keeps that.
        self.assertIs(payload["questFlags"].get("EVENT_BEAT_LANCE"), False)
        self.assertIs(payload["questFlags"].get("TOGGLE_CERULEAN_CAVE_GUY"), True)

    def test_dropping_the_dex_flag_is_not_the_published_fixture(self):
        envelope = json.loads(FIXTURE.read_bytes())
        payload = json.loads(envelope["payload"])
        payload["questFlags"]["EVENT_GOT_POKEDEX"] = False
        envelope["payload"] = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
        envelope["checksum"] = bound_checksum(envelope["schema"], envelope["sequence"], envelope["payload"])
        stripped = json.dumps(envelope, separators=(",", ":"), ensure_ascii=False).encode()
        restored = champion_hall_save(stripped)
        self.assertNotEqual(stripped, restored)
        self.assertEqual(restored, FIXTURE.read_bytes())


if __name__ == "__main__":
    unittest.main()
