"""Host-only archive fencing checks; no SSH, Pi access or SDK execution."""
from contextlib import contextmanager, nullcontext, redirect_stdout, redirect_stderr
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


class ArchiveFixture:
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
        patch.object(archive, 'LOCK_DIRECTORY', self.root / 'locks').start()
        patch.object(archive, 'read_policy', return_value=self.policy).start()

    def write_receipt(self):
        (self.receipts / (self.archive_id + '.json')).write_text(json.dumps(self.receipt))


class ArchiveTests(ArchiveFixture, unittest.TestCase):
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

    def test_changed_shared_helper_pin_refuses_before_any_invocation(self):
        helper = Path(self.policy['shared_helper'])
        helper.write_text('print("original")\n')
        self.policy.update(execution_enabled=True, shared_helper_sha256=archive.digest(helper))
        helper.write_text('print("changed")\n')
        with patch.object(archive.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'shared helper changed'):
                archive.execute('archive', 'cold-run', None)
            run.assert_not_called()

    def test_successful_cold_run_requires_explicit_reviewed_result_in_allowlist(self):
        proof = self.source / 'suite.json'
        proof.write_text(json.dumps({'complete': True, 'ok': True, 'not_run': []}))
        entry = self.policy['candidates']['cold-run']
        entry['proof_sha256'] = archive.digest(proof)
        with self.assertRaisesRegex(ValueError, 'explicitly reviewed'):
            archive.plan('archive', 'cold-run', None, self.policy)
        entry['expected_ok'] = True
        self.assertEqual(archive.plan('archive', 'cold-run', None, self.policy)['action'], 'archive')

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

    def test_manual_restore_and_rehearsal_refuse_existing_source_scoped_partials(self):
        self.write_receipt()
        partial = self.source.with_name('..cold-run.rehearsal-' + self.archive_id + '.restore-' + 'd' * 32)
        partial.mkdir()
        self.policy['execution_enabled'] = True
        with patch.object(archive, 'call_shared', side_effect=AssertionError('manual helper bypassed partial guard')):
            with self.assertRaisesRegex(archive.OwnerAttention, 'deferred-with-partial'):
                archive.execute('rehearse', 'cold-run', self.archive_id)
        (self.source / 'suite.json').unlink()
        self.source.rmdir()
        # An original-path partial has no ID: even a different selected
        # receipt must conservatively refuse another copy for this source.
        self.archive_id = 'playdate-' + 'f' * 32
        self.receipt['id'] = self.archive_id
        self.write_receipt()
        original = self.source.with_name('.cold-run.restore-' + 'e' * 32)
        original.mkdir()
        with patch.object(archive, 'call_shared', side_effect=AssertionError('manual helper bypassed partial guard')):
            with self.assertRaisesRegex(archive.OwnerAttention, 'deferred-with-partial'):
                archive.execute('restore', 'cold-run', self.archive_id)
        self.assertTrue(partial.is_dir())
        self.assertTrue(original.is_dir())

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

        with tempfile.TemporaryFile() as parent_lock, patch.object(archive, 'inherited_lock', redirected), patch.dict(
                os.environ, {'PLAYDATE_ARCHIVE_TEST_REPORT': str(report),
                             'PI_ARTIFACT_LOCK_FDS': str(parent_lock.fileno())}):
            self.assertEqual(archive.execute('archive', 'cold-run', None), 0)
        self.assertEqual([p.name for p in paths[:4]],
                         [f'pokemon-playdate-{name}-{os.getuid()}.lock' for name in archive.LOCK_ORDER])
        self.assertEqual(json.loads(report.read_text()), [True] * 6)

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

    def test_forbidden_names_refuse_without_removal_helper_or_global_lock(self):
        nested = self.source / 'nested'
        nested.mkdir()
        (nested / '.git').write_text('gitdir: elsewhere')
        (nested / 'Docker.raw').write_text('not a VM image')
        with patch.object(archive, 'producer_locks', side_effect=AssertionError('lock used')), \
                patch.object(archive, 'call_shared', side_effect=AssertionError('helper used')), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(archive.main(['preflight', 'cold-run']), 1)
        self.assertEqual(len(archive.forbidden_entries(self.source)), 2)
        self.assertTrue((nested / '.git').exists())
        self.assertTrue((nested / 'Docker.raw').exists())

    def test_existing_maintenance_entry_never_runs_legacy_age_deletion(self):
        from tools.harness import maintain_storage
        with patch.object(maintain_storage, 'maintain', side_effect=AssertionError('legacy deletion called')), \
                patch.object(archive, 'producer_locks', side_effect=AssertionError('scheduler pre-acquired fences')), \
                patch.object(archive.subprocess, 'run') as remote, redirect_stdout(io.StringIO()):
            self.assertEqual(maintain_storage.main(['--execute', '--env', str(self.root)]), 0)
            remote.assert_not_called()
        report = archive.maintenance_status()
        self.assertFalse(report['automatic_transfers'])
        self.assertFalse(report['broad_age_deletion'])
        self.assertEqual((report['trigger_free_gib'], report['stop_free_gib']), (70, 100))


FAKE_SHARED = r'''
import hashlib,json,os,shutil,sys,time
from pathlib import Path
state=Path(os.environ['PLAYDATE_FAKE_ARCHIVE_STATE'])
command=sys.argv[1]
with (state/'calls').open('a') as log:log.write(command+'\n')
failure=(state/'fail').read_text() if (state/'fail').exists() else ''
if (state/'delay').exists() and (state/'delay').read_text()==command:time.sleep(.1)
if failure=='busy':
    print('busy/offline/pressure',file=sys.stderr)
    sys.exit(1)
def save(value):
    (state/(value['id']+'.json')).write_text(json.dumps(value))
def emit(value):print(json.dumps(value),flush=True)
if command=='list':
    for file in sorted(state.glob('playdate-*.json')):emit(json.loads(file.read_text()))
    sys.exit(0)
if command=='archive':
    source=Path(sys.argv[sys.argv.index('--source')+1])
    identifier='playdate-'+hashlib.md5(str(source).encode()).hexdigest()
    value={'id':identifier,'project':'playdate','source':str(source),
           'manifest_sha256':'b'*64,'status':'copying','restore_rehearsed':False}
    save(value)
    if failure=='archive-offline':
        print('offline before ID publication',file=sys.stderr)
        sys.exit(1)
    value['status']='verified'
else:
    identifier=sys.argv[sys.argv.index('--id')+1]
    value=json.loads((state/(identifier+'.json')).read_text())
    source=Path(value['source'])
    if command=='resume':value['status']='verified'
    elif command=='restore':
        assert '--rehearse' in sys.argv
        if failure=='rehearse-partial':
            partial=source.with_name('..'+source.name+'.rehearsal-'+identifier+'.restore-'+'d'*32)
            partial.mkdir()
            (partial/'incomplete').write_text('partial copy')
            emit({'restore_incomplete':str(partial)})
            sys.exit(1)
        value['restore_rehearsed']=True
    elif command=='release':
        assert value['status']=='verified' and value['restore_rehearsed'] is True
        shutil.rmtree(source)
        value['status']='archived'
        Path(str(source)+'.ARCHIVED.json').write_text(json.dumps(value))
    else:raise RuntimeError('unexpected fake operation')
save(value)
emit(value)
'''


class QueueTests(ArchiveFixture, unittest.TestCase):
    def setUp(self):
        super().setUp()
        helper = Path(self.policy['shared_helper'])
        helper.write_text(FAKE_SHARED)
        self.policy.update(execution_enabled=True, queue_enabled=True,
                           shared_helper_sha256=archive.digest(helper))
        patch.dict(os.environ, {'PLAYDATE_FAKE_ARCHIVE_STATE': str(self.receipts),
                                'PI_ARTIFACT_LOCK_FDS': ''}).start()
        self.space = patch.object(archive, 'free_space_gib', return_value=60).start()
        archive.enqueue('cold-run', 'Owner reviewed: immutable failed fixture, no active/pinned input.')

    def calls(self):
        file = self.receipts / 'calls'
        return file.read_text().splitlines() if file.exists() else []

    def job(self):
        return archive.read_queue()['jobs']['cold-run']

    def test_one_phase_per_tick_requires_copy_then_rehearsal_before_release(self):
        self.assertEqual(archive.maintenance_tick()['action'], 'archive')
        self.assertTrue(self.source.is_dir())
        self.assertEqual(archive.maintenance_tick()['action'], 'rehearse')
        self.assertTrue(self.source.is_dir())
        self.assertNotIn('release', self.calls())
        self.assertEqual(archive.maintenance_tick()['action'], 'release')
        self.assertFalse(self.source.exists())
        self.assertEqual(self.job()['status'], 'done')
        self.assertEqual(self.calls(), ['list', 'archive', 'restore', 'release'])

    def test_offline_copy_recovers_id_and_resumes_without_duplicate_archive(self):
        (self.receipts / 'fail').write_text('archive-offline')
        self.assertEqual(archive.maintenance_tick()['status'], 'deferred')
        self.assertTrue(self.source.exists())
        self.assertEqual(self.job()['status'], 'pending')
        self.assertIsNone(self.job()['archive_id'])
        (self.receipts / 'fail').unlink()
        self.assertEqual(archive.maintenance_tick()['action'], 'resume')
        self.assertEqual(self.calls().count('archive'), 1)
        self.assertEqual(self.calls().count('resume'), 1)

    def test_busy_and_disabled_gates_leave_original_and_pending_job(self):
        self.policy['queue_enabled'] = False
        self.assertIn('disabled', archive.maintenance_tick()['status'])
        self.assertEqual(self.calls(), [])
        self.policy['queue_enabled'] = True
        (self.receipts / 'fail').write_text('busy')
        self.assertEqual(archive.maintenance_tick()['status'], 'deferred')
        self.assertTrue(self.source.exists())
        self.assertEqual(self.job()['status'], 'pending')
        self.assertEqual(self.calls(), ['list'])

    def test_archive_cycle_starts_below70_continues_to100_then_stops(self):
        self.space.return_value = 90
        self.assertIn('outside archive cycle', archive.maintenance_tick()['status'])
        self.assertEqual(self.calls(), [])
        self.space.return_value = 60
        archive.maintenance_tick()
        self.space.return_value = 90
        self.assertEqual(archive.maintenance_tick()['action'], 'rehearse')
        self.space.return_value = 101
        self.assertIn('outside archive cycle', archive.maintenance_tick()['status'])
        self.assertTrue(self.source.exists())
        self.assertNotIn('release', self.calls())

    def test_interrupted_rehearsal_is_retained_and_never_copied_again_automatically(self):
        archive.maintenance_tick()
        (self.receipts / 'fail').write_text('rehearse-partial')
        self.assertEqual(archive.maintenance_tick()['status'], 'deferred-with-partial')
        job = self.job()
        partial = Path(job['partial_paths'][0])
        self.assertTrue(partial.is_dir())
        self.assertTrue(self.source.is_dir())
        self.assertTrue(job['owner_attention'])
        # Simulate a parent lost before its failure annotation was committed.
        state = archive.read_queue()
        state['jobs']['cold-run']['owner_attention'] = False
        archive.atomic_json(archive.QUEUE, state)
        before = self.calls()
        self.assertEqual(archive.maintenance_tick()['status'], 'deferred-with-partial')
        self.assertEqual(self.calls(), before)
        self.assertTrue(partial.is_dir())
        self.assertEqual(self.calls().count('restore'), 1)

    def test_unknown_partial_for_other_id_is_never_deleted(self):
        archive.maintenance_tick()
        unknown = self.evidence / ('.cold-run.rehearsal-playdate-'+'e'*32+'.restore-'+'f'*32)
        unknown.mkdir()
        self.assertEqual(archive.maintenance_tick()['action'], 'rehearse')
        self.assertTrue(unknown.is_dir())

    def test_changed_source_or_producer_lock_prevents_data_phase(self):
        path = archive.LOCK_DIRECTORY / f'pokemon-playdate-storage-maintenance-{os.getuid()}.lock'
        with OwnerLock(path):
            self.assertIn('producer busy', archive.maintenance_tick()['status'])
        self.assertEqual(self.calls(), [])
        (self.source / 'suite.json').write_text('{}')
        self.assertEqual(archive.maintenance_tick()['status'], 'deferred')
        self.assertTrue(self.job()['owner_attention'])
        self.assertNotIn('archive', self.calls())

    def test_completed_release_receipt_recovers_after_parent_journal_loss(self):
        for _ in range(3):
            archive.maintenance_tick()
        before = self.calls()
        state = archive.read_queue()
        state['jobs']['cold-run']['status'] = 'pending'
        archive.atomic_json(archive.QUEUE, state)
        self.assertEqual(archive.maintenance_tick()['status'], 'already released')
        self.assertEqual(self.job()['status'], 'done')
        self.assertEqual(self.calls(), before)

    def test_healthy_data_writer_is_not_killed_by_metadata_observation_timeout(self):
        self.receipt['status'] = 'copying'
        self.write_receipt()
        archive.enqueue('cold-run', 'Owner reviewed: bind the existing interrupted-copy receipt.', self.archive_id)
        (self.receipts / 'delay').write_text('resume')
        with patch.object(archive, 'MAX_METADATA_SECONDS', .01):
            self.assertEqual(archive.maintenance_tick()['action'], 'resume')
        self.assertTrue(self.source.is_dir())

    def test_ambiguous_release_failure_requires_owner_recovery_without_another_data_step(self):
        self.receipt.update(status='release_failed', restore_rehearsed=True)
        self.write_receipt()
        archive.enqueue('cold-run', 'Owner reviewed: retain ambiguous failed-release receipt for recovery.', self.archive_id)
        self.assertEqual(archive.maintenance_tick()['status'], 'deferred')
        self.assertTrue(self.source.is_dir())
        self.assertTrue(self.job()['owner_attention'])
        self.assertEqual(self.calls(), [])


if __name__ == '__main__':
    unittest.main()
