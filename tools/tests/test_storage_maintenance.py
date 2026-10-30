"""Storage policy checks use disposable trees and no SDK or device operations."""
from contextlib import redirect_stderr
import fcntl
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

from tools.harness import maintain_storage as storage


class StorageMaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.project = self.base / 'repo'
        self.validation = self.project / 'docs/validation'
        self.validation.mkdir(parents=True)
        self.env = self.base / 'env'
        self.root = self.env / 'evidence'
        self.root.mkdir(parents=True)
        self.locks = self.base / 'locks'
        self.locks.mkdir()
        self.git('init', '-b', 'main')
        self.git('config', 'commit.gpgsign', 'false')
        self.git('config', 'core.hooksPath', str(self.base / 'no-hooks'))
        self.git('config', 'user.name', 'Storage Test')
        self.git('config', 'user.email', 'storage@example.invalid')
        self.write(self.validation / 'chain-saves.json', {})
        (self.validation / 'progress.md').write_text('No evidence yet.\n')
        self.commit()
        self.git('branch', 'checkpoint')
        self.refs = ('main', 'checkpoint')
        self.addCleanup(patch.stopall)
        self.now = time.time() + 7 * 24 * 3600
        patch.object(storage.time, 'time_ns', return_value=int(self.now * 1e9)).start()
        patch.object(storage, 'live_paths', return_value='').start()
        patch.object(storage, 'free_bytes', return_value=0).start()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.project, text=True,
                                       stderr=subprocess.DEVNULL)

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-m', 'Test retention records')

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def old(self, path, age=48):
        stamp = self.now - age * 3600
        for item in [*path.rglob('*'), path]:
            os.utime(item, (stamp, stamp), follow_symlinks=False)
        return path

    def journey(self, name, ok=True, age=48, key='natural', extra=None):
        path = self.root / name
        self.write(path / 'scenario.json', {'journey': {'name': key, 'starter': 'bulbasaur'}})
        self.write(path / 'outcome.json', {'ok': ok})
        self.write(path / 'process.json', {'pid': os.getpid()})  # Deliberate recycled PID.
        if extra:
            self.write(path / 'provenance.json', extra)
        return self.old(path, age)

    def stage(self, name, age=48):
        path = self.root / name
        self.write(path / 'build.json', {'simulator_executed': False, 'mode': 'compile-only'})
        bundle = path / 'Harness.pdx'
        bundle.mkdir()
        (bundle / 'main.pdz').write_bytes(b'compiled bytes')
        return self.old(path, age)

    def plan(self):
        return {Path(e['path']).name: e for e in storage.plan(self.project, self.root, self.refs, 24)}

    def maintain(self, execute=False):
        with redirect_stderr(io.StringIO()):
            return storage.maintain(self.project, self.env, self.refs, 150, 170, 24,
                                    execute, self.locks)

    def test_superseded_failures_and_successes_only(self):
        self.journey('old-pass', age=72)
        self.journey('old-failure', False, age=70)
        self.journey('latest', age=48)
        self.journey('unreplaced', False, key='other')
        result = self.plan()
        self.assertEqual(result['old-pass']['action'], 'remove')
        self.assertEqual(result['old-failure']['action'], 'remove')
        self.assertEqual(result['latest']['action'], 'keep')
        self.assertEqual(result['unreplaced']['action'], 'keep')

    def test_both_committed_branches_progress_and_transitive_ancestry(self):
        for name in ('main-ref', 'checkpoint-ref', 'progress-ref', 'ancestor', 'grandparent'):
            self.stage(name)
        self.write(self.root / 'ancestor/provenance.json', {'save': '../grandparent/save.json'})
        self.old(self.root / 'ancestor')
        self.write(self.validation / 'acceptance.json', {'path': 'evidence/main-ref/result.json'})
        self.commit()
        self.git('checkout', 'checkpoint')
        self.write(self.validation / 'pending.json', {'path': 'evidence/checkpoint-ref'})
        (self.validation / 'progress.md').write_text('evidence/progress-ref\n')
        self.commit()
        self.git('checkout', 'main')
        # HEAD and worktree alone cannot supply these checkpoint protections.
        self.write(self.root / 'chain/save.json', {'source': 'evidence/ancestor/partial-save.json'})
        self.old(self.root / 'chain')
        self.stage('deletable')
        result = self.plan()
        for name in ('main-ref', 'checkpoint-ref', 'progress-ref', 'ancestor', 'grandparent', 'chain'):
            self.assertEqual(result[name]['action'], 'keep', name)
        self.assertEqual(result['deletable']['action'], 'remove')

    def test_approximate_measurement_text_is_not_a_user_home(self):
        self.stage('referenced-stage')
        self.stage('deletable')
        self.write(self.validation / 'measurements.json', {
            'note': '~1.5s/load; evidence/referenced-stage/result.json',
        })
        self.commit()
        result = self.plan()
        self.assertEqual(result['referenced-stage']['action'], 'keep')
        self.assertEqual(result['deletable']['action'], 'remove')

    def test_schema_evidence_property_does_not_retain_the_entire_root(self):
        self.stage('deletable')
        self.write(self.validation / 'coverage.schema.json', {
            'required': ['evidence'], 'properties': {'evidence': {'type': 'object'}},
        })
        self.commit()
        self.assertEqual(self.plan()['deletable']['action'], 'remove')

    def test_packages_acceptance_unknown_and_latest_device_builds(self):
        for name in ('player-packages', 'acceptance-packet', 'Source', 'references', 'Data'):
            self.stage(name)
        self.write(self.root / 'unknown/readme.json', {})
        self.old(self.root / 'unknown')
        for name, age, build in [('device-old', 72, 'same'), ('device-new', 48, 'same'),
                                 ('device-other', 96, 'other')]:
            path = self.journey(name, age=age)
            self.write(path / 'device-smoke.json', {'build_id': build})
            self.old(path, age)
        result = self.plan()
        self.assertEqual(result['device-old']['action'], 'remove')
        for name in ('device-new', 'device-other', 'unknown', 'player-packages',
                     'acceptance-packet', 'Source', 'references', 'Data'):
            self.assertEqual(result[name]['action'], 'keep', name)

    def test_age_current_paths_and_existing_sdk_data(self):
        self.stage('recent', age=1)
        self.stage('open-archive')
        path = self.stage('data-owner')
        sdk_data = self.base / 'SDK/Data/private'
        sdk_data.mkdir(parents=True)
        self.write(path / 'process.json', {'data_dir': str(sdk_data)})
        self.old(path)
        with patch.object(storage, 'live_paths', return_value='n' + str(self.root / 'open-archive/log')):
            result = self.plan()
        for name in ('recent', 'open-archive', 'data-owner'):
            self.assertEqual(result[name]['action'], 'keep')

    def test_old_mtimes_do_not_bypass_new_copy_grace(self):
        archive = self.stage('new-copy-with-old-times')
        old_stamp = time.time() - 72 * 3600
        for item in [*archive.rglob('*'), archive]:
            os.utime(item, (old_stamp, old_stamp))
        with patch.object(storage.time, 'time_ns', return_value=int(time.time() * 1e9)):
            self.assertEqual(self.plan()[archive.name]['action'], 'keep')

    def test_default_is_dry_run_and_healthy_reserve_skips_scan(self):
        archive = self.stage('old-stage')
        report = self.maintain()
        self.assertTrue(archive.exists())
        self.assertEqual(report['removed'], [])
        with patch.object(storage, 'free_bytes', return_value=160), patch.object(storage, 'plan') as scan:
            self.assertEqual(self.maintain(True)['status'], 'reserve already met')
            scan.assert_not_called()
        with patch.object(storage, 'maintain', return_value={'minimum_met': True}) as maintain:
            with patch('sys.stdout', io.StringIO()):
                self.assertEqual(storage.main(['--env', str(self.env)]), 0)
            self.assertFalse(maintain.call_args.args[-1])
            self.assertEqual(maintain.call_args.args[3:5], (150 * storage.GIB, 170 * storage.GIB))

    def test_execution_stops_at_target_and_repeated_call_does_nothing(self):
        first = self.stage('a-stage')
        second = self.stage('b-stage')
        def space(_):
            return 170 if not first.exists() else 0
        with patch.object(storage, 'free_bytes', side_effect=space):
            report = self.maintain(True)
            repeated = self.maintain(True)
        self.assertFalse(first.exists())
        self.assertTrue(second.exists())
        self.assertEqual(report['observed_free_bytes_delta'], 170)
        self.assertEqual(repeated['removed'], [])

    def test_revalidation_catches_new_reference_and_same_size_edit(self):
        archive = self.stage('old-stage')
        original = storage.plan
        for mutation in ('reference', 'edit'):
            calls = 0
            def changed(*args):
                nonlocal calls
                calls += 1
                if calls == 2:
                    if mutation == 'reference':
                        self.write(self.validation / 'new.json', {'path': str(archive)})
                    else:
                        (archive / 'Harness.pdx/main.pdz').write_bytes(b'different byte')
                        self.old(archive)
                return original(*args)
            with patch.object(storage, 'plan', side_effect=changed):
                with self.assertRaisesRegex(ValueError, 'changed|retained'):
                    self.maintain(True)
            self.assertTrue(archive.exists())
            (self.validation / 'new.json').unlink(missing_ok=True)

    def test_runtime_suite_device_and_maintenance_locks_refuse(self):
        archive = self.stage('old-stage')
        for owner in ('suite', 'simulator', 'device', 'storage-maintenance'):
            lock = self.locks / f'pokemon-playdate-{owner}-{os.getuid()}.lock'
            with lock.open('a+') as stream:
                stream.write('owner record')
                stream.flush()
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with self.assertRaises(BlockingIOError):
                    self.maintain(True)
            self.assertEqual(lock.read_text(), 'owner record')
            self.assertTrue(archive.exists())

    def test_symlinks_hardlinks_mounts_and_missing_refs_fail_closed(self):
        archive = self.stage('old-stage')
        outside = self.base / 'outside'
        outside.write_text('never delete')
        link = archive / 'alias'
        link.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.maintain(True)
        self.assertEqual(outside.read_text(), 'never delete')
        link.unlink()
        os.link(outside, link)
        with self.assertRaises(ValueError):
            self.maintain(True)
        link.unlink()
        root_link = self.root / 'archive-alias'
        root_link.symlink_to(archive, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.maintain(True)
        root_link.unlink()
        with patch.object(Path, 'is_mount', return_value=True):
            with self.assertRaises(ValueError):
                self.maintain(True)
        with patch.object(self, 'refs', ('main', 'missing-checkpoint')):
            with self.assertRaises(subprocess.CalledProcessError):
                self.maintain(True)
        self.assertTrue(archive.exists())

    def test_complete_journey_suites_retain_latest_pass_per_result(self):
        def suite(name, results, age, complete=True):
            path = self.root / name
            self.write(path / 'suite.json', {'complete': complete, 'not_run': [],
                       'results': [{'name': key, 'ok': ok} for key, ok in results]})
            for key, _ in results:
                self.write(path / key / 'scenario.json', {'journey': {'name': key}})
            return self.old(path, age)
        suite('suite-old', [('first', True), ('second', False)], 72)
        suite('suite-new', [('first', True), ('second', True)], 48)
        suite('suite-other', [('third', True)], 96)
        suite('suite-incomplete', [('first', False)], 80, complete=False)
        result = self.plan()
        self.assertEqual(result['suite-old']['action'], 'remove')
        for name in ('suite-new', 'suite-other', 'suite-incomplete'):
            self.assertEqual(result[name]['action'], 'keep', name)

    def test_compile_stage_needs_declaration_no_runtime_and_no_acceptance(self):
        plain = self.stage('plain')
        accepted = self.stage('accepted')
        self.write(accepted / 'acceptance.json', {'status': 'accepted'})
        self.old(accepted)
        runtime = self.stage('runtime')
        self.write(runtime / 'outcome.json', {'ok': False})
        self.old(runtime)
        undeclared = self.stage('undeclared')
        (undeclared / 'build.json').unlink()
        self.old(undeclared)
        result = self.plan()
        self.assertEqual(result['plain']['action'], 'remove')
        for name in ('accepted', 'runtime', 'undeclared'):
            self.assertEqual(result[name]['action'], 'keep', name)
        alias = self.base / 'env-alias'
        alias.symlink_to(self.env, target_is_directory=True)
        with self.assertRaises(ValueError):
            storage.maintain(self.project, alias, self.refs, 150, 170, 24, True, self.locks)
        self.assertTrue(plain.exists())

    def test_process_scan_failure_and_new_live_path_stop_execution(self):
        archive = self.stage('old-stage')
        with patch.object(storage, 'live_paths', side_effect=ValueError('process inventory failed')):
            with self.assertRaisesRegex(ValueError, 'process inventory'):
                self.maintain(True)
        with patch.object(storage, 'live_paths', side_effect=['', str(archive)]):
            with self.assertRaisesRegex(ValueError, 'retained'):
                self.maintain(True)
        self.assertTrue(archive.exists())

    def test_templates_escaped_json_and_malformed_reference(self):
        self.stage('retry-bulbasaur')
        self.stage('retry-squirtle')
        self.stage('space stage')
        self.stage('unicode-stage-ñ')
        (self.validation / 'progress.md').write_text('Archive: evidence/space stage/file\n')
        self.write(self.validation / 'paths.json', {'path': 'evidence/retry-<starter>/file',
                                                  'escaped': 'evidence/unicode-stage-ñ/file'})
        self.assertTrue(all(e['action'] == 'keep' for e in self.plan().values()))
        (self.validation / 'paths.json').write_text('{malformed')
        with self.assertRaises(ValueError):
            self.maintain(True)


if __name__ == '__main__':
    unittest.main()
