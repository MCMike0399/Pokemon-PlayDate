"""The coverage snapshot must name this Source tree.

Lane E sets snapshot.source_sha256 from tools.harness.run.fingerprint and
nests the previous snapshot. Do not relabel the matrix from this lane, and
do not hand-edit the pin. Any Source change, including the credits-path
audio, fails this check until that pin is regenerated.
"""
import json
import unittest
from pathlib import Path

from tools.harness.run import fingerprint

ROOT = Path(__file__).resolve().parents[2]


class LaneECoverageFingerprintTests(unittest.TestCase):
    def test_snapshot_records_the_credits_path_audio(self):
        data = json.loads((ROOT / 'docs/validation/coverage-current.json').read_text())
        self.assertEqual(data['snapshot']['source_sha256'], fingerprint(ROOT))


if __name__ == '__main__':
    unittest.main()
