"""Hall of Fame and credits capture log, checked against pret/pokered af519899.

The Simulator is not required. A frame log is a JSON list of beats. When a
beat names a PNG, that file has to be a 400x240 capture.
"""

import json
import os
from pathlib import Path
import unittest

from tools.tests.lane_g_hall_of_fame import (
    COPYRIGHT_LINES,
    check_log,
    credits_from_pokered,
    expected_beats,
    money_text,
    play_time_text,
    rating_lines,
)

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "tools/tests/fixtures/lane_g_hall_of_fame_credits.json"


def _party():
    return [
        {"species": "CHARMANDER", "nickname": "CHAR", "level": 62, "types": ["FIRE"]},
        {"species": "PIDGEOT", "nickname": "PIDGEOT", "level": 61, "types": ["NORMAL", "FLYING"]},
    ]


def _player(owned=60):
    return {"name": "BLUE", "hours": 8, "minutes": 5, "money": 1234, "seen": 80, "owned": owned}


def _log(credits, **changes):
    party = changes.get("party", _party())
    player = changes.get("player", _player())
    beats = expected_beats(party, player, credits)
    frames = []
    for beat in beats:
        if not beat["text"]:
            continue
        frames.append({
            "beat": beat["id"],
            "text": list(beat["text"]),
            "species": beat.get("species"),
            "gb_frames": beat.get("gb_frames"),
        })
    return {"version": "blue", "party": party, "player": player, "frames": frames}


class HallOfFameSequenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.credits = json.loads(FIXTURE.read_text())

    def test_fixture_matches_pokered(self):
        roots = [os.environ.get("POKERED"), "/tmp/pokered"]
        root = next((Path(item) for item in roots if item and (Path(item) / "engine/movie/credits.asm").is_file()), None)
        if root is None:
            self.skipTest("pret/pokered af519899 is required to re-read the credits")
        parsed = credits_from_pokered(root)
        self.assertEqual(parsed, self.credits)
        self.assertEqual(parsed[0]["species"], "VENUSAUR")
        self.assertEqual(parsed[0]["lines"], ["#MON", "BLUE VERSION STAFF"])
        self.assertEqual(parsed[-2]["species"], "PARASECT")
        self.assertEqual(parsed[-2]["lines"], list(COPYRIGHT_LINES))
        self.assertEqual(parsed[-1], {
            "kind": "the_end",
            "lines": ["THE END"],
            "gb_frames": 16,
            "fade_gb_frames": 20,
        })
        self.assertEqual(
            [screen["species"] for screen in parsed if "species" in screen],
            ["VENUSAUR", "ARBOK", "RHYHORN", "FEAROW", "ABRA", "GRAVELER", "HITMONLEE",
             "TANGELA", "STARMIE", "GYARADOS", "DITTO", "OMASTAR", "VILEPLUME", "NIDOKING", "PARASECT"],
        )

    def test_rating_band_and_card_numbers(self):
        self.assertIn("grassy areas!", " ".join(rating_lines(0)))
        self.assertIn("grassy areas!", " ".join(rating_lines(9)))
        self.assertIn("FLASH HM", " ".join(rating_lines(10)))
        self.assertIn("geting", " ".join(rating_lines(60)))
        self.assertEqual(rating_lines(151)[0], "Your PokéDEX is")
        self.assertEqual(money_text(0), "¥0")
        self.assertEqual(money_text(1234), "¥1234")
        self.assertEqual(play_time_text(8, 5), "8:05")

    def test_log_that_follows_the_party_and_the_credits_passes(self):
        self.assertEqual(check_log(_log(self.credits), self.credits), [])

    def test_single_type_keeps_type2_erased(self):
        log = _log(self.credits)
        log["frames"][0]["text"] = ["CHAR", "LEVEL/", "62", "TYPE1/", "FIRE", "TYPE2/"]
        errors = check_log(log, self.credits)
        self.assertTrue(any("TYPE2/" in error for error in errors))

    def test_dual_type_requires_type2(self):
        log = _log(self.credits)
        banner = next(frame for frame in log["frames"] if frame["beat"] == "hof-banner-1")
        banner["text"] = [item for item in banner["text"] if item != "TYPE2/"]
        errors = check_log(log, self.credits)
        self.assertTrue(any("TYPE2/" in error for error in errors))

    def test_credits_mon_order_is_checked(self):
        log = _log(self.credits)
        first = next(frame for frame in log["frames"] if frame["beat"] == "credits-00")
        first["species"] = "ARBOK"
        errors = check_log(log, self.credits)
        self.assertTrue(any("VENUSAUR" in error for error in errors))

    def test_missing_the_end_fails(self):
        log = _log(self.credits)
        log["frames"] = [frame for frame in log["frames"] if frame["beat"] != "the-end"]
        errors = check_log(log, self.credits)
        self.assertIn("missing beat the-end", errors)

    def test_hold_must_match_delay_frames(self):
        log = _log(self.credits)
        log["frames"][0]["gb_frames"] = 10
        errors = check_log(log, self.credits)
        self.assertTrue(any("gb_frames" in error and "80" in error for error in errors))

    def test_red_staff_line(self):
        beats = expected_beats(_party(), _player(), self.credits, version="red")
        staff = next(beat for beat in beats if beat["id"] == "credits-00")
        self.assertIn("RED VERSION STAFF", staff["text"])
        self.assertNotIn("BLUE VERSION STAFF", staff["text"])
        self.assertIn("POKéMON", staff["text"])
        self.assertNotIn("#MON", staff["text"])

    def test_species_name_is_not_credits_text(self):
        log = _log(self.credits)
        first = next(frame for frame in log["frames"] if frame["beat"] == "credits-00")
        first["text"] = list(first["text"]) + ["venusaur"]
        errors = check_log(log, self.credits)
        self.assertTrue(any("scrolling sprite" in error for error in errors))

    def test_literal_hash_is_rejected(self):
        log = _log(self.credits)
        first = next(frame for frame in log["frames"] if frame["beat"] == "credits-00")
        first["text"] = ["#MON", "BLUE VERSION STAFF"]
        errors = check_log(log, self.credits)
        self.assertTrue(any("literal hash" in error for error in errors))

    def test_dex_rating_keeps_the_accent(self):
        log = _log(self.credits, player=_player(owned=2))
        rating = next(frame for frame in log["frames"] if frame["beat"] == "hof-dex-rating")
        rating["text"] = [line.replace("é", "e").replace("Poké", "Poke") for line in rating["text"]]
        errors = check_log(log, self.credits)
        self.assertTrue(any("é" in error for error in errors))

    def test_png_must_be_400x240(self):
        import tempfile
        from PIL import Image
        log = _log(self.credits)
        log["frames"][0]["png"] = "missing.png"
        errors = check_log(log, self.credits, root=ROOT)
        self.assertTrue(any("missing frame" in error for error in errors))
        with tempfile.TemporaryDirectory() as folder:
            good = Path(folder) / "hof-mon-0.png"
            Image.new("1", (400, 240), 0).save(good)
            log["frames"][0]["png"] = str(good)
            self.assertEqual(check_log(log, self.credits, root=ROOT), [])
            Image.new("1", (200, 120), 0).save(good)
            errors = check_log(log, self.credits, root=ROOT)
            self.assertTrue(any("400x240" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
