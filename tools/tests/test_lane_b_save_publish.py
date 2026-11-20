#!/usr/bin/env python3
"""Earned save files are never overwritten, and sequence numbers only rise."""

import json
import tempfile
import unittest
from pathlib import Path

from tools.lane_b_publish import SavePublishError, highest_sequence, publish_save, rewrite_sequence


def envelope(sequence, payload='{"location":{"x":1}}'):
    raw = json.dumps({
        'checksum': '00000000',
        'schema': 1,
        'sequence': str(sequence),
        'format': 'pokemon-playdate-save',
        'payload': payload,
    }, separators=(',', ':')).encode()
    return rewrite_sequence(raw, sequence)


class SavePublishTest(unittest.TestCase):
    def test_publish_refuses_to_overwrite_an_existing_save(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            original = envelope(66, '{"place":"route-20"}')
            kept = root / 'seq66-adventure.b.json'
            kept.write_bytes(original)
            incoming = root / 'incoming.json'
            incoming.write_bytes(envelope(79, '{"place":"seafoam"}'))
            with self.assertRaises(SavePublishError):
                publish_save(incoming, root, 'seq66-adventure.b.json')
            self.assertEqual(kept.read_bytes(), original)
            published = publish_save(incoming, root, 'seq79-adventure.a.json')
            self.assertEqual(published.read_bytes(), incoming.read_bytes())
            self.assertEqual(highest_sequence(root), 79)

    def test_rewrite_keeps_the_payload_and_raises_the_sequence(self):
        payload = '{"location":{"zone_id":"pokered:SEAFOAM_ISLANDS_1F","x":26,"y":6}}'
        rewritten = json.loads(rewrite_sequence(envelope(67, payload), 79))
        self.assertEqual(rewritten['sequence'], '79')
        self.assertEqual(rewritten['payload'], payload)
        self.assertNotEqual(rewritten['checksum'], '00000000')


if __name__ == '__main__':
    unittest.main()
