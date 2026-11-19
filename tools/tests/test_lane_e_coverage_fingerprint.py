"""The coverage snapshot still names the tree from before the credits-path audio.

expectedFailure until lane E applies tools/notes/lane-e-coverage-fingerprint.patch.
Do not relabel the matrix from this lane.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CREDITS_AUDIO_FINGERPRINT = 'ff2514c59e73f50bccb2693a8d61b292be493ebaf5c4ae44e607c428a54de668'


class LaneECoverageFingerprintTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_snapshot_records_the_credits_path_audio(self):
        data = json.loads((ROOT / 'docs/validation/coverage-current.json').read_text())
        self.assertEqual(data['snapshot']['source_sha256'], CREDITS_AUDIO_FINGERPRINT)


if __name__ == '__main__':
    unittest.main()
