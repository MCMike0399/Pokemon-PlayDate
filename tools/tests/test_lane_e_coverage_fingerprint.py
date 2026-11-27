"""The coverage snapshot still names the tree from before this lane's audio.

This fails until lane E regenerates the snapshot. Do not relabel the matrix
from this lane, and do not hand-edit the pin.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CREDITS_AUDIO_FINGERPRINT = 'aee32b591b3202898ab28d254ee376750c0ea6a58793735a495dde4f24016e27'


class LaneECoverageFingerprintTests(unittest.TestCase):
    def test_snapshot_records_the_credits_path_audio(self):
        data = json.loads((ROOT / 'docs/validation/coverage-current.json').read_text())
        self.assertEqual(data['snapshot']['source_sha256'], CREDITS_AUDIO_FINGERPRINT)


if __name__ == '__main__':
    unittest.main()
