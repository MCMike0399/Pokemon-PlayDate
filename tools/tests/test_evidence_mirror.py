"""The earned-evidence mirror redirects only the frozen namespace."""
from pathlib import Path
import os
import tempfile
import unittest

from tools.harness.evidence_mirror import ORIGINAL_EVIDENCE, mirrored_evidence_reads
from tools.harness.protocol import ProtocolError


class EvidenceMirrorTests(unittest.TestCase):
    def test_unset_mirror_reads_the_given_path(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'note.txt'
            path.write_text('local')
            env = os.environ.pop('POKEMON_EVIDENCE_MIRROR', None)
            try:
                with mirrored_evidence_reads():
                    self.assertEqual(path.read_text(), 'local')
            finally:
                if env is not None:
                    os.environ['POKEMON_EVIDENCE_MIRROR'] = env

    def test_mirror_serves_frozen_evidence_bytes_without_rewriting_them(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            relative = Path('checkpoint/partial-save.json')
            source = root / relative
            source.parent.mkdir()
            source.write_bytes(b'cabin-marker')
            os.environ['POKEMON_EVIDENCE_MIRROR'] = str(root)
            try:
                frozen = ORIGINAL_EVIDENCE / relative
                with mirrored_evidence_reads():
                    self.assertTrue(frozen.is_file())
                    self.assertFalse(frozen.is_symlink())
                    self.assertEqual(frozen.read_bytes(), b'cabin-marker')
                self.assertEqual(source.read_bytes(), b'cabin-marker')
            finally:
                os.environ.pop('POKEMON_EVIDENCE_MIRROR', None)

    def test_missing_mirror_file_stays_missing(self):
        with tempfile.TemporaryDirectory() as temporary:
            os.environ['POKEMON_EVIDENCE_MIRROR'] = temporary
            try:
                frozen = ORIGINAL_EVIDENCE / 'missing-slot.json'
                with mirrored_evidence_reads():
                    self.assertFalse(frozen.is_file())
                    with self.assertRaises(FileNotFoundError):
                        frozen.read_bytes()
            finally:
                os.environ.pop('POKEMON_EVIDENCE_MIRROR', None)

    def test_symlink_mirror_root_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            real = root / 'real'
            real.mkdir()
            link = root / 'link'
            link.symlink_to(real, target_is_directory=True)
            os.environ['POKEMON_EVIDENCE_MIRROR'] = str(link)
            try:
                with self.assertRaises(ProtocolError):
                    with mirrored_evidence_reads():
                        pass
            finally:
                os.environ.pop('POKEMON_EVIDENCE_MIRROR', None)


if __name__ == '__main__':
    unittest.main()
