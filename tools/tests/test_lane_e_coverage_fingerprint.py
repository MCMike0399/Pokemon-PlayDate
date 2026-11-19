"""The coverage snapshot still names the tree from before this lane's audio.

expectedFailure until lane E applies tools/notes/lane-e-coverage-fingerprint.patch.
Do not relabel the matrix from this lane.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CREDITS_AUDIO_FINGERPRINT = '5883c3284cd79f46882ed9f91ec660faa5b3516c9b3821f664a447bf209951e7'


class LaneECoverageFingerprintTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_snapshot_records_the_credits_path_audio(self):
        data = json.loads((ROOT / 'docs/validation/coverage-current.json').read_text())
        self.assertEqual(data['snapshot']['source_sha256'], CREDITS_AUDIO_FINGERPRINT)


if __name__ == '__main__':
    unittest.main()
