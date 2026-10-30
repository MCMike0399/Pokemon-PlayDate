"""Disposable native roundtrip and filesystem/fault adapters; no SDK or real archives."""
from contextlib import redirect_stderr
import json
import os
import plistlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

from tools.harness import compress_archives as compression
from tools.harness.share_archives import digest, metadata


class ArchiveCompressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.archive = self.root / 'closed'
        self.folder = self.archive / '01-journey'
        self.path = self.folder / 'runtime-data/trace.jsonl'
        self.path.parent.mkdir(parents=True)
        self.path.write_bytes(b'{"phase":"immutable archived trace"}\n' * 32768)
        self.runfile = self.folder / 'run.json'
        self.runfile.write_text(json.dumps({'processes': [{'status': 'exited', 'returncode': 0}]}))
        self.terminal = self.archive / 'suite.json'
        self.terminal.write_text(json.dumps({'complete': True}))
        self.payload = self.path.read_bytes()
        self.actual_stat = Path.stat
        self.native_copy = compression.copy_compressed
        self.native_detector = compression.unavailable_reason
        self.real_audit = compression.audit_event
        self.audit = []
        self.patches = [
            patch.object(compression, 'unavailable_reason', return_value=None),
            patch.object(compression, 'lower_priority'),
            patch.object(compression, 'audit_event', side_effect=self.audit.append),
            patch.object(compression, 'copy_compressed', side_effect=self.copy),
            # This explicit layout adapter exercises guards without pretending
            # that ordinary copies on unsupported hosts reclaim physical space.
            patch.object(Path, 'stat', lambda path, *a, **kw: self.layout(path, *a, **kw)),
        ]
        for mocked in self.patches:
            mocked.start()
            self.addCleanup(mocked.stop)

    def layout(self, path, *args, **kwargs):
        info = self.actual_stat(path, *args, **kwargs)
        if '.compressed-' not in path.name:
            return info
        fields = {name: getattr(info, name) for name in dir(info) if name.startswith('st_')}
        fields.update(st_flags=32, st_blocks=max(0, info.st_blocks // 2))
        return types.SimpleNamespace(**fields)

    def copy(self, source, destination, timeout):
        self.assertGreater(timeout, 0)
        self.assertLessEqual(timeout, 180)
        if sys.platform == 'darwin':
            subprocess.run(['/usr/bin/ditto', '--rsrc', '--extattr', '--acl',
                            str(source), str(destination)], check=True, capture_output=True, timeout=timeout)
        else:
            shutil.copy2(source, destination)

    def run_compression(self, execute=True, live=None, enough=None, **kwargs):
        return compression.compress_closed_traces(
            self.root, execute, enough or (lambda: False), live or (lambda: ''),
            minimum_size=1, **kwargs)

    def assert_untouched(self, inode):
        self.assertEqual(self.path.stat().st_ino, inode)
        self.assertEqual(self.path.read_bytes(), self.payload)
        self.assertEqual(list(self.root.rglob('*.compressed-*')), [])

    def test_roundtrip_preserves_bytes_metadata_and_independent_inode(self):
        self.path.chmod(0o640)
        if sys.platform == 'darwin':
            subprocess.run(['/usr/bin/xattr', '-w', 'user.archive-test', 'kept', str(self.path)], check=True)
        else:
            os.setxattr(self.path, 'user.archive-test', b'kept')
        before, before_metadata = self.path.stat(), metadata(self.path)
        report = self.run_compression()
        after = self.path.stat()
        self.assertEqual(len(report['files']), 1)
        self.assertEqual(self.path.read_bytes(), self.payload)
        self.assertEqual(metadata(self.path), before_metadata)
        self.assertEqual(after.st_mtime_ns, before.st_mtime_ns)
        self.assertEqual(after.st_atime_ns, before.st_atime_ns)
        self.assertNotEqual(after.st_ino, before.st_ino)
        self.assertEqual(report['files'][0]['sha256'], digest(self.path))
        self.assertIn('compression_prepared', self.audit[0])
        self.assertIn('compressed_archive', self.audit[1])

    def test_live_or_incomplete_archive_never_copied(self):
        inode = self.path.stat().st_ino
        for live in (lambda: str(self.archive), lambda: 'n' + str(self.path)):
            with patch.object(compression, 'copy_compressed') as copy:
                report = self.run_compression(live=live)
                copy.assert_not_called()
                self.assertIn('live/open', report['refusals'][0]['reason'])
        self.terminal.write_text('{"complete":false}')
        with patch.object(compression, 'copy_compressed') as copy:
            report = self.run_compression()
            copy.assert_not_called()
            self.assertIn('not complete', report['refusals'][0]['reason'])
        self.assert_untouched(inode)

    def test_open_archive_at_last_guard_retains_original(self):
        inode = self.path.stat().st_ino
        calls = []
        def live():
            calls.append(1)
            return '' if len(calls) < 3 else 'n' + str(self.path)
        report = self.run_compression(live=live)
        self.assertEqual(report['files'], [])
        self.assertIn('live/open', report['refusals'][0]['reason'])
        self.assert_untouched(inode)

    def test_own_lock_exemption_does_not_hide_other_open_paths(self):
        own = self.path.parent / 'owner.lock'
        compression.reject_open(self.archive, lambda: 'p' + str(os.getpid()) + '\nn' + str(own), own)
        for line in ('p' + str(os.getpid() + 1) + '\nn' + str(own),
                     'n' + str(own), 'n' + str(own) + '.other', 'command ' + str(own),
                     'n' + str(own) + '\nn' + str(self.path)):
            with self.assertRaisesRegex(ValueError, 'live/open'):
                compression.reject_open(self.archive, lambda: line, own)

    def test_copy_fault_corruption_and_metadata_loss_clean_temporary(self):
        inode = self.path.stat().st_ino
        def copy_fault(source, temporary, timeout):
            temporary.write_bytes(b'partial copy')
            raise OSError('copy failed')
        def corrupt(source, temporary, timeout):
            self.copy(source, temporary, timeout)
            temporary.write_bytes(b'X' * len(self.payload))
        def lose_mode(source, temporary, timeout):
            self.copy(source, temporary, timeout)
            temporary.chmod(0o600 if source.stat().st_mode & 0o777 != 0o600 else 0o644)
        for copy in (copy_fault, corrupt, lose_mode):
            with patch.object(compression, 'copy_compressed', side_effect=copy):
                report = self.run_compression()
            self.assertTrue(report['refusals'])
            self.assertEqual(report['files'], [])
            self.assert_untouched(inode)

    def test_source_and_terminal_metadata_races_are_refused(self):
        for victim in (self.path, self.runfile, self.terminal):
            inode = self.path.stat().st_ino
            original = victim.read_bytes()
            def race(source, temporary, timeout):
                self.copy(source, temporary, timeout)
                victim.write_bytes(original + b' ')
            with patch.object(compression, 'copy_compressed', side_effect=race):
                report = self.run_compression()
            self.assertTrue(report['refusals'])
            self.assertEqual(self.path.stat().st_ino, inode)
            self.assertEqual(victim.read_bytes(), original + b' ')
            self.assertEqual(list(self.root.rglob('*.compressed-*')), [])
            victim.write_bytes(original)

    def test_source_inode_replacement_with_identical_bytes_is_not_overwritten(self):
        replacement_inode = []
        def swap(source, temporary, timeout):
            self.copy(source, temporary, timeout)
            replacement = source.with_name('user-replacement')
            shutil.copy2(source, replacement)
            replacement_inode.append(replacement.stat().st_ino)
            os.replace(replacement, source)
        with patch.object(compression, 'copy_compressed', side_effect=swap):
            report = self.run_compression()
        self.assertEqual(report['files'], [])
        self.assertIn('source changed', report['refusals'][0]['reason'])
        self.assertEqual(self.path.stat().st_ino, replacement_inode[0])
        self.assertEqual(self.path.read_bytes(), self.payload)
        self.assertEqual(list(self.root.rglob('*.compressed-*')), [])

    def test_proofs_are_fresh_for_every_file_and_prior_audit_is_preserved(self):
        second = self.folder / 'processes/0001/trace.jsonl'
        second.parent.mkdir(parents=True)
        second.write_bytes(self.payload)
        def audit(event):
            self.audit.append(event)
            if 'compressed_archive' in event:
                self.terminal.write_text('{"complete":false}')
        with patch.object(compression, 'audit_event', side_effect=audit):
            report = self.run_compression()
        self.assertEqual(len(report['files']), 1)
        self.assertEqual(sum('compressed_archive' in event for event in self.audit), 1)
        self.assertTrue(report['refusals'])
        self.assertEqual(second.read_bytes(), self.payload)

    def test_symlink_hardlink_and_nested_mount_boundaries(self):
        outside = self.root / 'outside'
        outside.write_bytes(self.payload)
        inode = self.path.stat().st_ino
        self.path.unlink()
        self.path.symlink_to(outside)
        self.assertEqual(self.run_compression()['files'], [])
        self.path.unlink()
        os.link(outside, self.path)
        self.assertEqual(self.run_compression()['files'], [])
        self.path.unlink()
        self.path.write_bytes(self.payload)
        actual = Path.is_mount
        with patch.object(Path, 'is_mount', lambda p: p == self.path.parent or actual(p)):
            self.assertEqual(self.run_compression()['files'], [])
        self.assertEqual(outside.read_bytes(), self.payload)
        self.assertEqual(list(self.root.rglob('*.compressed-*')), [])

    def test_temporary_mount_or_hardlink_is_never_published(self):
        inode = self.path.stat().st_ino
        def linked(source, temporary, timeout):
            os.link(source, temporary)
        with patch.object(compression, 'copy_compressed', side_effect=linked):
            self.assertTrue(self.run_compression()['refusals'])
        self.assert_untouched(inode)
        actual = Path.is_mount
        with patch.object(Path, 'is_mount', lambda p: '.compressed-' in p.name or actual(p)):
            self.assertTrue(self.run_compression()['refusals'])
        self.assert_untouched(inode)

    def test_budget_and_target_checks_prevent_late_publication(self):
        inode = self.path.stat().st_ino
        enough = [False]
        def copy(source, temporary, timeout):
            self.copy(source, temporary, timeout)
            enough[0] = True
        with patch.object(compression, 'copy_compressed', side_effect=copy):
            report = self.run_compression(enough=lambda: enough[0])
        self.assertEqual(report['status'], 'target met')
        self.assert_untouched(inode)
        clock = [0]
        def overrun(source, temporary, timeout):
            self.copy(source, temporary, timeout)
            clock[0] = 1801
        with patch.object(compression.time, 'monotonic', side_effect=lambda: clock[0]), \
                patch.object(compression, 'copy_compressed', side_effect=overrun):
            report = self.run_compression()
        self.assertEqual(report['status'], 'time budget exhausted')
        self.assert_untouched(inode)
        for budget in (0, 1801, float('inf'), float('nan')):
            with self.assertRaises(ValueError):
                self.run_compression(max_seconds=budget)

    def test_audit_failure_before_and_after_publication_retains_records(self):
        inode = self.path.stat().st_ino
        with patch.object(compression, 'audit_event', side_effect=compression.AuditError('disk full')):
            report = self.run_compression()
        self.assertEqual(report['status'], 'audit unavailable')
        self.assert_untouched(inode)
        def audit(event):
            if 'compressed_archive' in event:
                raise compression.AuditError('audit disk full after publication')
            self.audit.append(event)
        with patch.object(compression, 'audit_event', side_effect=audit):
            report = self.run_compression()
        self.assertEqual(report['status'], 'audit unavailable')
        self.assertEqual(len(report['files']), 1)
        self.assertEqual(self.path.read_bytes(), self.payload)
        self.assertEqual(list(self.root.rglob('*.compressed-*')), [])

    def test_dry_run_and_explicit_platform_unavailability_never_copy(self):
        inode = self.path.stat().st_ino
        with patch.object(compression, 'copy_compressed') as copy:
            report = self.run_compression(execute=False)
            self.assertEqual(report['candidate_files'], 1)
            copy.assert_not_called()
        self.assert_untouched(inode)
        self.assertFalse((self.path.parent / 'owner.lock').exists())
        with patch.object(compression, 'unavailable_reason', return_value='native compression unavailable: requires Darwin/APFS'), \
                patch.object(compression, 'copy_compressed') as copy:
            report = self.run_compression()
            self.assertEqual(report['status'], 'unavailable')
            copy.assert_not_called()
        self.assert_untouched(inode)

    def test_platform_detector_rejects_other_os_and_filesystems(self):
        with patch.object(compression.sys, 'platform', 'linux'), \
                patch.object(compression.subprocess, 'check_output') as probe:
            self.assertIn('Darwin/APFS', self.native_detector(self.root))
            probe.assert_not_called()
        with patch.object(compression.sys, 'platform', 'darwin'), \
                patch.object(compression.subprocess, 'check_output', side_effect=[
                    'Filesystem blocks used available capacity mounted\n/dev/test 1 1 1 1% /\n',
                    plistlib.dumps({'FilesystemType': 'hfs'})]):
            self.assertIn('not APFS', self.native_detector(self.root))

    def test_ordinary_copy_is_never_reported_as_compression(self):
        inode = self.path.stat().st_ino
        with patch.object(Path, 'stat', self.actual_stat):
            report = self.run_compression()
        self.assertEqual(report['files'], [])
        self.assert_untouched(inode)

    def test_real_native_roundtrip_or_explicit_unavailability(self):
        # The native integration case touches only this temporary trace. Other
        # platforms exercise the explicit unavailable branch, never fake gains.
        reason = self.native_detector(self.root)
        if reason:
            self.assertIn('unavailable', reason)
            with patch.object(compression, 'unavailable_reason', self.native_detector):
                self.assertEqual(self.run_compression()['status'], 'unavailable')
            return
        with patch.object(Path, 'stat', self.actual_stat), \
                patch.object(compression, 'copy_compressed', self.native_copy), \
                patch.object(compression, 'unavailable_reason', self.native_detector):
            before = self.path.stat()
            original_metadata = metadata(self.path)
            report = self.run_compression()
            self.assertEqual(len(report['files']), 1, report)
            after = self.path.stat()
            self.assertEqual(after.st_flags, 32)
            self.assertLess(after.st_blocks, before.st_blocks)
            self.assertEqual(self.path.read_bytes(), self.payload)
            self.assertEqual(metadata(self.path)[:3], original_metadata[:3])
            self.assertEqual(metadata(self.path)[4:], original_metadata[4:])
            self.assertEqual(after.st_mtime_ns, before.st_mtime_ns)

    def test_audit_appends_flushes_and_fsyncs_existing_log(self):
        # Invoke the real audit writer with a disposable wrapper-style log.
        writer = self.real_audit
        logfile = self.root / 'audit.log'
        logfile.write_text('earlier published audit\n')
        with logfile.open('a') as stream, redirect_stderr(stream), patch.object(compression.os, 'fsync') as sync:
            writer({'completed': 'one'})
            writer({'refused': 'two'})
            self.assertEqual(sync.call_count, 2)
        lines = logfile.read_text().splitlines()
        self.assertEqual(lines[0], 'earlier published audit')
        self.assertEqual(json.loads(lines[1]), {'completed': 'one'})
        self.assertEqual(json.loads(lines[2]), {'refused': 'two'})
        inode = self.path.stat().st_ino
        with logfile.open('a') as stream, redirect_stderr(stream), \
                patch.object(compression, 'audit_event', self.real_audit), \
                patch.object(compression.os, 'fsync', side_effect=OSError('audit storage full')):
            report = self.run_compression()
        self.assertTrue(report['refusals'])
        self.assert_untouched(inode)


if __name__ == '__main__':
    unittest.main()
