"""The audio handoff applies to clean main 247d60a9 and compiles.

Lane K's stack rehearsal applied the six fidelity patches onto main without
the sequencer or the move-sfx files. pdc then failed on audio/moveSfx, heal
called playSequence before it existed, and badge-item plus player-faint-cry
needed a 3-way against cues and functions main does not have. This test
applies the ordered series onto a detached 247d60a9 worktree, compiles it
with pdc, and runs LaneEAudioFidelityTests there. No skip and no xfail.
"""

import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = "247d60a9216307c0e1b15316f2b052ae10d23a6c"
NOTES = ROOT / "tools/notes"
SERIES = (
    "lane-e-audio-sequencer.patch",
    "lane-e-audio-movesfx-import.patch",
    "lane-e-audio-heal-count.patch",
    "lane-e-audio-pokedex-cry.patch",
    "lane-e-audio-source-cries.patch",
    "lane-e-audio-badge-item.patch",
    "lane-e-audio-player-faint-cry.patch",
)


def cue_keys(events_text):
    block = events_text.split("cues = {", 1)[1].split("\n  },", 1)[0]
    return re.findall(r'\["([^"]+)"\]', block)


class LaneEAudioHandoffTests(unittest.TestCase):
    def test_series_applies_to_main_compiles_and_passes_fidelity(self):
        sdk = Path.home() / "Developer/PlaydateSDK"
        pdc = sdk / "bin/pdc"
        self.assertTrue(pdc.is_file(), f"pdc missing at {pdc}")
        for name in SERIES:
            text = (NOTES / name).read_text(errors="surrogateescape")
            self.assertIn("diff --git", text)
            self.assertNotIn("MallocPoolSize", text)

        work = Path(tempfile.mkdtemp(prefix="audio-handoff-"))
        try:
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(work), MAIN],
                cwd=ROOT, check=True, capture_output=True, text=True,
            )
            head = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=work, check=True, capture_output=True, text=True,
            ).stdout.strip()
            self.assertEqual(head, MAIN)

            before = (work / "Source/audio/events.lua").read_text()
            before_keys = cue_keys(before)
            self.assertEqual(before_keys, sorted(before_keys))

            for name in SERIES:
                subprocess.run(
                    ["git", "apply", str(NOTES / name)],
                    cwd=work, check=True, capture_output=True, text=True,
                )

            after = (work / "Source/audio/events.lua").read_text()
            after_keys = cue_keys(after)
            self.assertEqual(after_keys, before_keys)
            self.assertEqual(after_keys, sorted(after_keys))
            self.assertIn(
                '["badge"] = {score="item", kind="jingle", source="home/text.asm:546", token="SFX_GET_ITEM_1"}',
                after,
            )
            audio = (work / "Source/game/kantoAudio.lua").read_text()
            self.assertIn("local function sfxFrames(name)", audio)
            self.assertIn("local function playSequence(names)", audio)
            self.assertIn("local function moveScore(key)", audio)
            self.assertTrue((work / "Source/audio/moveSfx.lua").is_file())
            self.assertTrue((work / "Source/audio/moveSfxData.lua").is_file())
            self.assertTrue((work / "Source/audio/eventMaps.bin").is_file())

            compiled = work / "build.pdx"
            proc = subprocess.run(
                [str(pdc), "-q", "Source", str(compiled)],
                cwd=work, check=False, capture_output=True, text=True,
            )
            self.assertEqual(
                proc.returncode, 0,
                (proc.stdout or "") + (proc.stderr or ""),
            )
            self.assertTrue(compiled.is_dir())

            tests = work / "tools/tests"
            tests.mkdir(parents=True, exist_ok=True)
            shutil.copy(
                ROOT / "tools/tests/test_lane_e_audio_fidelity.py",
                tests / "test_lane_e_audio_fidelity.py",
            )
            fidelity = subprocess.run(
                [sys.executable, "-m", "unittest", "tools.tests.test_lane_e_audio_fidelity"],
                cwd=work, check=False, capture_output=True, text=True,
            )
            self.assertEqual(
                fidelity.returncode, 0,
                (fidelity.stdout or "") + (fidelity.stderr or ""),
            )
            self.assertIn("Ran 7 tests", fidelity.stderr)
        finally:
            subprocess.run(
                ["git", "worktree", "remove", "--force", str(work)],
                cwd=ROOT, check=False, capture_output=True, text=True,
            )
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
