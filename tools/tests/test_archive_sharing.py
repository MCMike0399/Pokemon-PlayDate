"""Filesystem sharing preserves evidence bytes; no game or SDK execution."""
from contextlib import redirect_stderr
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from tools.harness import share_archives as sharing


class ArchiveSharingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.source = self.root / 'source'
        self.target = self.root / 'target'
        self.payload = b'exact retained archive bytes\n'
        self.source.write_bytes(self.payload)
        self.target.write_bytes(self.payload)
        self.checksum = hashlib.sha256(self.payload).hexdigest()

    def test_independent_copy_preserves_bytes_mode_and_mtime(self):
        self.target.chmod(0o640)
        before = self.target.stat()
        sharing.share_pair(self.source, self.target, self.checksum, clone=shutil.copyfile)
        self.assertEqual(self.target.read_bytes(), self.payload)
        self.assertEqual(self.target.stat().st_mode, before.st_mode)
        self.assertEqual(self.target.stat().st_mtime_ns, before.st_mtime_ns)
        self.assertNotEqual(self.source.stat().st_ino, self.target.stat().st_ino)
        self.target.write_bytes(b'independent edit')
        self.assertEqual(self.source.read_bytes(), self.payload)

    def test_corrupt_clone_keeps_original_and_cleans_temporary(self):
        def corrupt(source, target):
            target.write_bytes(b'wrong bytes')
        with self.assertRaisesRegex(ValueError, 'cloned bytes differ'):
            sharing.share_pair(self.source, self.target, self.checksum, clone=corrupt)
        self.assertEqual(self.target.read_bytes(), self.payload)
        self.assertEqual(list(self.root.glob('*.cow-*')), [])

    def test_destination_changed_during_copy_is_not_overwritten(self):
        def concurrent_edit(source, temporary):
            shutil.copyfile(source, temporary)
            self.target.write_bytes(b'new user bytes')
        with self.assertRaisesRegex(ValueError, 'destination changed'):
            sharing.share_pair(self.source, self.target, self.checksum, clone=concurrent_edit)
        self.assertEqual(self.target.read_bytes(), b'new user bytes')
        self.assertEqual(list(self.root.glob('*.cow-*')), [])

    def test_aliases_and_hard_links_are_refused(self):
        self.target.unlink()
        self.target.symlink_to(self.source)
        with self.assertRaisesRegex(ValueError, 'independent regular'):
            sharing.share_pair(self.source, self.target, self.checksum)
        self.target.unlink()
        os.link(self.source, self.target)
        with self.assertRaisesRegex(ValueError, 'independent regular'):
            sharing.share_pair(self.source, self.target, self.checksum)

    def test_same_file_is_not_a_sharing_destination(self):
        with self.assertRaisesRegex(ValueError, 'different files'):
            sharing.share_pair(self.source, self.source, self.checksum)

    def test_extended_attributes_are_retained_by_refusing_the_pair(self):
        if sys.platform == 'darwin':
            subprocess.run(['/usr/bin/xattr', '-w', 'user.pokemon-retained', 'original', str(self.target)], check=True)
        else:
            os.setxattr(self.target, 'user.pokemon-retained', b'original')
        with self.assertRaisesRegex(ValueError, 'metadata'):
            sharing.share_pair(self.source, self.target, self.checksum, clone=shutil.copyfile)
        if sys.platform == 'darwin':
            value = subprocess.check_output(['/usr/bin/xattr', '-p', 'user.pokemon-retained', str(self.target)]).rstrip(b'\n')
        else:
            value = os.getxattr(self.target, 'user.pokemon-retained')
        self.assertEqual(value, b'original')
        self.assertEqual(self.target.read_bytes(), self.payload)

    def test_acl_metadata_is_refused(self):
        actual = sharing.metadata
        def acl(path):
            result = actual(path)
            return result[:-1] + (True,) if path == self.target else result
        with patch.object(sharing, 'metadata', side_effect=acl):
            with self.assertRaisesRegex(ValueError, 'metadata'):
                sharing.share_pair(self.source, self.target, self.checksum, clone=shutil.copyfile)

    def test_nested_mount_is_excluded_even_on_the_same_device(self):
        folder = self.run_folder({'status': 'exited', 'returncode': 0})
        actual = Path.is_mount
        with patch.object(Path, 'is_mount', lambda path: path == folder or actual(path)):
            self.assertEqual(list(sharing.closed_trace_groups(self.root)), [])

    def test_caller_can_exclude_recently_shared_archives(self):
        self.run_folder({'status': 'exited', 'returncode': 0})
        report = sharing.share_closed_traces(self.root, True, lambda: False,
                                             minimum_size=1, allowed_roots=set())
        self.assertEqual(report['files'], [])

    def run_folder(self, process):
        folder = self.root / 'run'
        folder.mkdir(exist_ok=True)
        (folder / 'run.json').write_text(json.dumps({'processes': [process]}))
        for relative in ('runtime-data/trace.jsonl', 'processes/0001/trace.jsonl'):
            path = folder / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(self.payload)
        return folder

    def test_only_confirmed_exits_qualify(self):
        self.run_folder({'status': 'ready'})
        self.assertEqual(list(sharing.closed_trace_groups(self.root)), [])
        self.run_folder({'status': 'failed-exited'})
        self.assertEqual(list(sharing.closed_trace_groups(self.root)), [])
        self.run_folder({'status': 'failed-exited', 'returncode': -9})
        self.assertEqual(len(list(sharing.closed_trace_groups(self.root))[0]), 2)

    def test_dry_run_retains_inodes_and_records_exact_digest(self):
        folder = self.run_folder({'status': 'exited', 'returncode': 0})
        path = folder / 'runtime-data/trace.jsonl'
        inode = path.stat().st_ino
        report = sharing.share_closed_traces(self.root, False, lambda: False, minimum_size=1)
        self.assertEqual(len(report['files']), 1)
        self.assertEqual(report['files'][0]['sha256'], self.checksum)
        self.assertEqual(path.stat().st_ino, inode)

    def test_reaching_target_stops_before_any_clone(self):
        self.run_folder({'status': 'exited', 'returncode': 0})
        with redirect_stderr(io.StringIO()):
            report = sharing.share_closed_traces(self.root, True, lambda: True, minimum_size=1)
        self.assertEqual(report['files'], [])

    def test_compressed_traces_are_not_rehashed_or_recloned(self):
        # A logical gigabyte can occupy only a few compressed blocks. Sharing
        # repeatedly expands and hashes it without useful reserve recovery.
        original_stat = Path.stat
        compressed = {self.source, self.target}

        def flags(path, *args, **kwargs):
            result = original_stat(path, *args, **kwargs)
            if path in compressed:
                return SimpleNamespace(st_size=result.st_size, st_flags=32)
            return result

        with patch.object(sharing.sys, 'platform', 'darwin'), \
                patch.object(sharing, 'closed_trace_groups', return_value=[[self.source, self.target]]), \
                patch.object(Path, 'stat', flags), \
                patch.object(sharing, 'digest', side_effect=AssertionError('compressed bytes rehashed')), \
                patch.object(sharing, 'share_pair') as clone:
            report = sharing.share_closed_traces(self.root, True, lambda: False, minimum_size=1)
        clone.assert_not_called()
        self.assertEqual(report['files'], [])
        self.assertEqual(set(report['skipped_compressed']), {str(self.source), str(self.target)})
