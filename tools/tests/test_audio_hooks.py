"""The lane handoff patches apply cleanly and are not already in production."""
import subprocess
import unittest
from pathlib import Path

from tools.audio.lane_hooks import payloads

ROOT = Path(__file__).resolve().parents[2]


class AudioHookPatchTests(unittest.TestCase):
    def test_patches_match_the_generator_and_apply(self):
        for name, text in payloads().items():
            path = ROOT / name
            self.assertEqual(path.read_text(), text, name)
            subprocess.run(['git', 'apply', '--check', name], cwd=ROOT, check=True)


if __name__ == '__main__':
    unittest.main()
