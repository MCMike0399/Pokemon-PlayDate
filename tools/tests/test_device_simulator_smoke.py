"""Host checks only: real compilation, fake process transport, no SDK execution/USB."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tools.device import build_smoke, simulator_smoke as smoke
from tools.harness.run import sdk_path
from tools.tests.test_production_build import pdz_modules

PROJECT = Path(__file__).resolve().parents[2]
BUILD = 'a' * 32


class SmokeBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='device-smoke-host-')
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        candidate = cls.root / 'candidate'
        cls.original_module = (PROJECT / 'Source/dev/deviceSmoke.lua').read_bytes()
        shutil.copytree(PROJECT / 'Source', candidate / 'Source')
        # Apply only to a disposable host fixture; checked-in Source stays untouched.
        if b'DeviceSmoke.simulatorTransportVersion = 1' not in cls.original_module:
            with (PROJECT / 'tools/device/device-smoke-simulator.patch').open() as stream:
                subprocess.run(['patch', '-p1'], cwd=candidate, stdin=stream, check=True, capture_output=True)
        cls.stage = cls.root / 'build'
        with patch.object(build_smoke.subprocess, 'check_output', return_value='33f778389ffbd8baac19fefd965da74748577cff\n'):
            cls.metadata = build_smoke.prepare(candidate, sdk_path(), cls.stage)

    def test_compiled_private_bundle_retains_only_one_dev_module(self):
        self.assertEqual(smoke.verify(self.stage), self.metadata)
        modules = pdz_modules(self.stage / 'DeviceSmoke.pdx/main.pdz')
        self.assertEqual([name for name in modules if name.startswith('dev/')], ['dev/deviceSmoke'])
        self.assertEqual(self.metadata['simulator_transport_version'], 1)
        main = (self.stage / 'Source/main.lua').read_text()
        self.assertTrue(main.endswith('DeviceSmoke.installSimulatorObserver()\n'))
        self.assertEqual((PROJECT / 'Source/dev/deviceSmoke.lua').read_bytes(), self.original_module)

    def test_changed_bundle_and_source_rejected(self):
        for name in ('DeviceSmoke.pdx/main.pdz', 'Source/main.lua'):
            path = self.stage / name
            before = path.read_bytes()
            try:
                path.write_bytes(before + b'changed')
                with self.assertRaisesRegex(ValueError, 'changed'):
                    smoke.verify(self.stage)
            finally:
                path.write_bytes(before)

    def test_verify_only_never_launches(self):
        with patch.object(smoke.subprocess, 'Popen', side_effect=AssertionError('no launch')), patch.object(smoke.sys, 'argv', ['smoke', '--build-stage', str(self.stage)]), patch('builtins.print'):
            smoke.main()


class SmokeHostTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_command_allowlist(self):
        path = self.root / 'commands.json'
        valid = ['state', 'press a 1', 'press down 120', 'wait 300', 'release all']
        path.write_text(json.dumps(valid))
        self.assertEqual(smoke.commands(path), valid)
        for value in ('press a 0', 'press a 121', 'wait 301', 'eval x', 'DS1 1 state', 'state\n', 1):
            path.write_text(json.dumps([value]))
            with self.assertRaises(ValueError):
                smoke.commands(path)

    def test_verified_earned_import_and_bad_hash(self):
        source, data, output = [self.root / name for name in ('earned', 'data', 'output')]
        for folder in (source, data, output):
            folder.mkdir()
        rows = []
        for name in sorted(smoke.SLOTS):
            (source / name).write_text('real earned slot bytes')
            rows.append({'file': name, 'sha256': smoke.sha(source / name)})
        record = self.root / 'save.json'
        record.write_text(json.dumps({'directory': str(source), 'files': rows}))
        smoke.import_saves(record, data, output)
        self.assertEqual(smoke.inventory(source), smoke.inventory(data))
        (source / rows[0]['file']).write_text('tampered')
        with self.assertRaises(ValueError):
            smoke.import_saves(record, data, output)

    def test_mailbox_dispatches_ds1_and_waits_for_done(self):
        box = smoke.Mailbox(self.root, BUILD, SimpleNamespace(poll=lambda: None), 1)
        called = []
        def respond(_):
            command = self.root / 'device-smoke-command.txt'
            called.append(command.read_text())
            command.unlink()
            rows = [{'build': BUILD, 'seq': 1, 'status': status, 'value': value}
                    for status, value in [('accepted', 'press'), ('done', {'state': 'title'})]]
            (self.root / 'device-smoke-replies.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in rows))
        with patch.object(smoke.time, 'sleep', side_effect=respond):
            self.assertEqual(box.command('press a 1'), {'state': 'title'})
        self.assertEqual(called, ['DS1 1 press a 1'])
        self.assertEqual(len(box.responses), 2)

    def test_mailbox_rejects_error_wrong_build_and_overwrite(self):
        replies = self.root / 'device-smoke-replies.jsonl'
        for row in ({'build': BUILD, 'seq': 0, 'status': 'error', 'value': 'guard'},
                    {'build': 'wrong', 'seq': 1, 'status': 'done'}):
            command = self.root / 'device-smoke-command.txt'
            command.unlink(missing_ok=True)
            replies.write_text(json.dumps(row) + '\n')
            with self.assertRaises(ValueError):
                smoke.Mailbox(self.root, BUILD, SimpleNamespace(poll=lambda: None), 1).command('state')
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            smoke.Mailbox(self.root, BUILD, None, 1).command('state')

    def trace(self):
        phases = [('title.live.after_gc', 0), ('Continue.live.after_gc', 1),
                  ('door.map.begin', 2), ('door.map.end', 402),
                  ('battle.start.begin', 403), ('battle.start.end', 404)]
        (self.root / 'boot-trace.tsv').write_text(
            f'schema\t1\tbuild\t{BUILD}\tplatform\tsimulator\nheader\n' + ''.join(
                f'{i}\t{phase}\t{clock}\t1\t1\t5000\t8000\n' for i, (phase, clock) in enumerate(phases)))
        # Same update suspended for 400ms, but only two 1ms active segments.
        (self.root / 'device-smoke-frames.tsv').write_text(
            f'{BUILD}\t1\t1\tyield\t1\t5000\n{BUILD}\t1\t2\treturn\t1\t5000\n')

    def test_active_frame_duration_does_not_use_suspended_phase_gap(self):
        self.trace()
        report = smoke.measurements(self.root, BUILD, 1)
        self.assertEqual(report['measurements']['frame_ms'], 1)
        self.assertEqual(report['measurements']['map_load_ms'], 400)
        self.assertEqual(report['budget_failures'], [])
        self.assertIn('map_load_ms', smoke.measurements(self.root, BUILD, 2)['budget_failures'])

    def test_timestamped_phase_scales_work_without_scaling_suspension(self):
        self.trace()
        frames = self.root / 'device-smoke-frames.tsv'
        frames.write_text(
            f'{BUILD}\t1\t1\tyield\t1\t5000\t1\t2\n'
            f'{BUILD}\t1\t2\treturn\t1\t5000\t1\t401\n'
            f'{BUILD}\t2\t1\treturn\t1\t5000\t0\t403\n')
        report = smoke.measurements(self.root, BUILD, 2)
        self.assertEqual(report['measurements']['map_device_estimate_ms'], 404)
        self.assertEqual(report['budget_failures'], [])
        frames.write_text(frames.read_text().replace('yield\t1\t', 'yield\t300\t'))
        self.assertIn('map_device_estimate_ms', smoke.measurements(self.root, BUILD, 2)['budget_failures'])

    def test_budget_failure_and_missing_evidence_never_pass(self):
        self.trace()
        frames = self.root / 'device-smoke-frames.tsv'
        frames.write_text(f'{BUILD}\t1\t1\terror\t1001\t10000\n')
        report = smoke.measurements(self.root, BUILD, 1)
        for failure in ('frame_ms', 'slice_ms', 'heap_peak_bytes', 'runtime-error-or-no-frames'):
            self.assertIn(failure, report['budget_failures'])
        frames.write_text('')
        self.assertIn('frame_ms', smoke.measurements(self.root, BUILD, 1)['budget_failures'])

    def test_reads_are_observations_not_continue_or_save(self):
        value = smoke.observations([{'status': 'done', 'value': {'state': 'title', 'continue_available': True}}])
        self.assertTrue(value['title'])
        self.assertEqual((value['loaded'], value['saved']), (0, 0))


if __name__ == '__main__':
    unittest.main()
