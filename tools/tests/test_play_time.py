"""Play time is a v4 session field and ticks like TrackPlayTime."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def lua_binary():
    for name in ("lua", "lua5.4"):
        found = shutil.which(name)
        if found:
            return found
    raise AssertionError("Lua 5.4 is required")


class PlayTimeTest(unittest.TestCase):
    def test_track_play_time_rolls_and_stops_at_hour_255(self):
        completed = subprocess.run(
            [lua_binary(), "tools/tests/play_time_probe.lua"],
            cwd=ROOT, check=False, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("play-time-ok", completed.stdout)

    def test_save_schema_keeps_play_time(self):
        codec = (ROOT / "Source/domain/sessionCodec.lua").read_text()
        session = (ROOT / "Source/domain/gameSession.lua").read_text()
        story = (ROOT / "Source/game/endgameStory.lua").read_text()
        main = (ROOT / "Source/main.lua").read_text()
        overworld = (ROOT / "Source/game/overworldState.lua").read_text()
        title = (ROOT / "Source/game/titleState.lua").read_text()
        self.assertEqual(codec.count("VERSION=4"), 1)
        self.assertIn("hallOfFame=true,playTime=true", codec)
        self.assertIn('legacy session cannot contain play time', codec)
        self.assertIn("playTime=session:playTime()", codec)
        self.assertIn("playTime=prepared.playTime", codec)
        self.assertIn("playTime = PlayTime.empty()", session)
        self.assertIn("values.playTime = PlayTime.normalize(values.playTime)", session)
        self.assertIn("values.playTimeCounting = false", session)
        self.assertIn("function GameSession:playTime()", session)
        self.assertIn("function GameSession:trackPlayTime()", session)
        self.assertIn("PlayTime.advance(current.playTime)", session)
        self.assertIn("session:playTime()", story)
        self.assertIn("game.session:trackPlayTime()", main)
        self.assertIn("game.session:enablePlayTime()", overworld)
        self.assertIn("self.game.session:disablePlayTime()", title)


if __name__ == "__main__":
    unittest.main()
