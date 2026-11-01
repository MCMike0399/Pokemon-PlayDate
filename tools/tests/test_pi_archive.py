"""Host-only archive fencing checks; no SSH, Pi access or SDK execution."""
from contextlib import contextmanager, nullcontext, redirect_stdout
import io
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.harness import pi_archive as archive
from tools.harness.protocol import OwnerLock, ProtocolError


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.evidence = self.root / 'evidence'
        self.evidence.mkdir()
        self.source = self.evidence / 'cold-run'
        self.source.mkdir()
        proof = self.source / 'suite.json'
        proof.write_text(json.dumps({'complete': True, 'ok': False, 'not_run': []}))
        self.policy = {'execution_enabled': False, 'shared_helper': str(self.root / 'shared.py'),
                       'candidates': {'cold-run': {'proof_file': 'suite.json',
                                                  'proof_sha256': archive.digest(proof)}}}
        self.receipts = self.root / 'receipts'
        self.receipts.mkdir()
        self.archive_id = 'playdate-' + 'a' * 32
        self.receipt = {'id': self.archive_id, 'project': 'playdate', 'source': str(self.source),
                        'manifest_sha256': 'b' * 64, 'status': 'verified', 'restore_rehearsed': False}
        self.addCleanup(patch.stopall)
        patch.object(archive, 'EVIDENCE', self.evidence).start()
        patch.object(archive, 'RECEIPTS', self.receipts).start()
        patch.object(archive, 'QUEUE', self.root / 'queue.json').start()
        patch.object(archive, 'read_policy', return_value=self.policy).start()

    def write_receipt(self):
        (self.receipts / (self.archive_id + '.json')).write_text(json.dumps(self.receipt))

    def test_archive_is_copy_only_and_unknown_or_changed_candidates_refuse(self):
        result = archive.plan('archive', 'cold-run', None, self.policy)
        self.assertEqual(result['argv'][2:], ['archive', '--project', 'playdate', '--source',
                                             str(self.source), '--closed'])
        with self.assertRaises(ValueError):
            archive.plan('archive', '../chain', None, self.policy)
        (self.source / 'suite.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'proof changed'):
            archive.plan('archive', 'cold-run', None, self.policy)

    def test_disabled_execution_never_invokes_shared_tool(self):
        with patch.object(archive.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'disabled'):
                archive.execute('archive', 'cold-run', None)
            run.assert_not_called()

    def test_receipt_source_and_rehearsal_gate_release(self):
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, 'rehearsal'):
            archive.plan('release', 'cold-run', self.archive_id, self.policy)
        self.receipt['source'] = str(self.evidence / 'chain')
        self.receipt['restore_rehearsed'] = True
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, 'exact allowlisted source'):
            archive.plan('release', 'cold-run', self.archive_id, self.policy)

    def test_rehearse_resume_and_restore_do_not_overwrite(self):
        self.write_receipt()
        self.assertIn('--rehearse', archive.plan('rehearse', 'cold-run', self.archive_id, self.policy)['argv'])
        with self.assertRaisesRegex(ValueError, 'never overwrites'):
            archive.plan('restore', 'cold-run', self.archive_id, self.policy)
        self.receipt['status'] = 'copying'
        self.write_receipt()
        self.assertEqual(archive.plan('resume', 'cold-run', self.archive_id, self.policy)['argv'][-1], '--closed')
        with self.assertRaises(ValueError):
            archive.plan('release', 'cold-run', self.archive_id, self.policy)

    def test_inherited_child_keeps_lock_after_parent_context_closes(self):
        path = self.root / 'inherited.lock'
        child = None
        try:
            with archive.inherited_lock(path) as descriptor:
                child = subprocess.Popen([sys.executable, '-c',
                    'import os,sys; os.fstat(int(sys.argv[1])); print("ready",flush=True); sys.stdin.read(1)',
                    str(descriptor)], pass_fds=(descriptor,), stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, text=True)
                self.assertTrue(select.select([child.stdout], [], [], 5)[0])
                self.assertEqual(child.stdout.readline().strip(), 'ready')
            with self.assertRaises(ProtocolError):
                with OwnerLock(path):
                    pass
            child.communicate('x', timeout=5)
            self.assertEqual(child.returncode, 0)
            with OwnerLock(path):
                pass
        finally:
            if child and child.poll() is None:
                child.kill()
                child.communicate(timeout=5)

    def test_execute_forwards_all_fences_in_order_and_environment(self):
        helper = Path(self.policy['shared_helper'])
        report = self.root / 'fd-report.json'
        helper.write_text('import os,json\nfrom pathlib import Path\n'
                          'fds=list(map(int,os.environ["PI_ARTIFACT_LOCK_FDS"].split(",")))\n'
                          'Path(os.environ["PLAYDATE_ARCHIVE_TEST_REPORT"]).write_text('
                          'json.dumps([bool(os.fstat(fd)) for fd in fds]))\n')
        self.policy.update(execution_enabled=True, shared_helper_sha256=archive.digest(helper))
        paths = []
        original = archive.inherited_lock

        @contextmanager
        def redirected(path):
            paths.append(path)
            with original(self.root / ('lock-' + str(len(paths)))) as descriptor:
                yield descriptor

        with patch.object(archive, 'inherited_lock', redirected), patch.dict(
                os.environ, {'PLAYDATE_ARCHIVE_TEST_REPORT': str(report)}):
            self.assertEqual(archive.execute('archive', 'cold-run', None), 0)
        self.assertEqual([p.name for p in paths[:4]],
                         [f'pokemon-playdate-{name}-{os.getuid()}.lock' for name in archive.LOCK_ORDER])
        self.assertEqual(json.loads(report.read_text()), [True] * 5)

    def test_explicit_review_enqueues_pending_without_remote_execution(self):
        with patch.object(archive, 'producer_locks', side_effect=lambda _: nullcontext(())), \
                patch.object(archive.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'review note'):
                archive.enqueue('cold-run', '')
            job = archive.enqueue('cold-run', 'Owner reviewed: superseded closed failed run; no current input.')
            self.assertEqual(job['status'], 'pending')
            self.assertEqual(archive.read_queue()['jobs']['cold-run'], job)
            self.assertEqual(archive.enqueue('cold-run', 'Owner reviewed: repeated request is idempotent.'), job)
            run.assert_not_called()

    def test_pinned_inputs_cannot_enter_queue_even_if_added_to_allowlist(self):
        self.policy['candidates']['chain'] = self.policy['candidates']['cold-run']
        with self.assertRaisesRegex(ValueError, 'stay local'):
            archive.source_path('chain', self.policy)

    def test_existing_maintenance_entry_never_runs_legacy_age_deletion(self):
        from tools.harness import maintain_storage
        with patch.object(maintain_storage, 'maintain', side_effect=AssertionError('legacy deletion called')), \
                patch.object(archive.subprocess, 'run') as remote, redirect_stdout(io.StringIO()):
            self.assertEqual(maintain_storage.main(['--execute', '--env', str(self.root)]), 0)
            remote.assert_not_called()
        report = archive.maintenance_status()
        self.assertFalse(report['automatic_transfers'])
        self.assertFalse(report['broad_age_deletion'])
        self.assertEqual((report['trigger_free_gib'], report['stop_free_gib']), (70, 100))


if __name__ == '__main__':
    unittest.main()
