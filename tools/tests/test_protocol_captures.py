import importlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from tools.harness.protocol import atomic_json

runner = importlib.import_module('tools.harness.run')


def png():
    def chunk(kind, content):
        return struct.pack('>I', len(content)) + kind + content + struct.pack('>I', zlib.crc32(kind + content))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 400, 240, 1, 0, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\0' + b'\xff' * 50) * 240)) + chunk(b'IEND', b''))


class CaptureBarrierTests(unittest.TestCase):
    def test_final_verification_waits_for_producer_quiescence(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            data = output / 'data'
            frames = output / 'frames'
            data.mkdir(); frames.mkdir()
            capture = {'raw': 'last.png', 'presentation': 'last-display.png', 'tick': 9}
            # Deterministically pause a producer after truncating its rolling
            # PNG, exactly the race observed in the real Charmander run.
            (frames / 'last.png').write_bytes(b'\x89PNG\r\n\x1a\n')
            (data / 'captures.jsonl').write_text(json.dumps(capture) + '\n')
            class Producer:
                quiesced = False
                def quiesce(self):
                    (frames / 'last.png').write_bytes(png())
                    (frames / 'last-display.png').write_bytes(png())
                    atomic_json(data / 'captures-final.json', {'schema': 1, 'quiescent': True, 'captures': [capture], 'capture_count': 1, 'recent_frames': [], 'recent_count': 0})
                    self.quiesced = True
                    return {'quiescent': True}
                def read(self, filename):
                    return json.loads((data / filename).read_text())
            producer = Producer()
            runner.finalize_captures(producer, data, output)
            self.assertTrue(producer.quiesced)
            self.assertTrue((output / 'captures.json').exists())

    def test_missing_quiescent_manifest_cannot_succeed(self):
        with tempfile.TemporaryDirectory() as directory:
            class Producer:
                def quiesce(self): return {'quiescent': True}
                def read(self, filename): return None
            from tools.harness.protocol import ProtocolError
            with self.assertRaisesRegex(ProtocolError, 'missing stable final'):
                runner.finalize_captures(Producer(), Path(directory), Path(directory))

    def test_recent_ring_retains_only_manifest_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            data = output / 'data'
            (data / 'recent').mkdir(parents=True)
            (output / 'frames').mkdir()
            recent = []
            for tick in range(100, 108):
                raw, display = f'recent/frame-{tick:08d}.png', f'recent/frame-{tick:08d}-display.png'
                for name in (raw, display): (data / name).write_bytes(png())
                recent.append({'raw':raw, 'presentation':display, 'tick':tick, 'storage':'runtime-data'})
            manifest = {'quiescent':True, 'captures':{}, 'capture_count':0, 'recent_frames':recent, 'recent_count':8}
            class Producer:
                def quiesce(self): return {'quiescent':True}
                def read(self, filename): return manifest
            runner.finalize_captures(Producer(), data, output)
            saved = json.loads((output / 'captures.json').read_text())
            self.assertEqual([frame['tick'] for frame in saved['recent_frames']], list(range(100,108)))
            self.assertEqual(len(list((output / 'frames/recent').glob('*.png'))),16)
