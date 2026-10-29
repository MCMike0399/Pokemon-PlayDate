"""Host-only filesystem tests. Never invoke USB commands or Simulator."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from tools import device_cycle as device
from tools.harness import run
from tools.harness.protocol import ProtocolError


class HostCycle(device.Cycle):
    def select_serial(self):
        self.serial = '/host-fixture-only'
        return True

    def command(self, argv):
        self.event('host-mocked-command', argv=argv)
        if argv[0] == 'diskutil':
            self.volume.rename(self.volume.with_name('unmounted'))

    def disk(self):
        unmounted = self.volume.with_name('unmounted')
        if unmounted.exists():
            unmounted.rename(self.volume)
        self.event('host-mocked-disk')


class DeviceCycleTests(unittest.TestCase):
    def test_usb_preflight(self):
        from types import SimpleNamespace
        with patch.object(run.glob, 'glob', return_value=['/dev/cu.usbmodemPDTEST']), patch.object(run.subprocess, 'run') as command:
            command.return_value = SimpleNamespace(returncode=0, stdout='p42\ncreader\nn/dev/cu.usbmodemPDTEST\n', stderr='')
            with self.assertRaisesRegex(ProtocolError, 'occupied.*lsof ownership: p42; creader'):
                run.simulator_usb_preflight()
            command.return_value = SimpleNamespace(returncode=1, stdout='', stderr='')
            run.simulator_usb_preflight()
            command.return_value = SimpleNamespace(returncode=1, stdout='', stderr='permission denied')
            with self.assertRaisesRegex(ProtocolError, 'Cannot verify'):
                run.simulator_usb_preflight()
        with patch.object(run.glob, 'glob', return_value=[]):
            run.simulator_usb_preflight()

    def test_symlink_payload_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)
            (path / 'linked').symlink_to('/tmp')
            with self.assertRaises(ValueError):
                device.inventory(path)

    def test_cycle_archives_before_overwrite_and_preserves_data(self):
        self.exercise(False)

    def test_explicit_save_import_backs_up_and_verifies(self):
        self.exercise(True)

    def exercise(self, import_save):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            sdk = root / 'sdk'
            (sdk / 'bin').mkdir(parents=True)
            (sdk / 'bin/pdc').write_text('host fixture')
            stage = root / 'stage'
            (stage / 'Source').mkdir(parents=True)
            (stage / 'Source/pdxinfo').write_text('bundleID=com.poc.test\n')
            (stage / 'Source/main.lua').write_text('-- host fixture\n')
            pdx = root / 'Test.pdx'
            pdx.mkdir()
            (pdx / 'main.pdz').write_bytes(b'new payload')
            shutil.copytree(pdx, stage / 'Production.pdx')
            (stage / 'build.json').write_text(json.dumps({
                'mode': 'production', 'bundle': str(pdx),
                'source_sha256': run.fingerprint(stage, exclude_generated=False)}))
            volume = root / 'PLAYDATE'
            installed = volume / 'Games/Test.pdx'
            installed.mkdir(parents=True)
            (installed / 'main.pdz').write_bytes(b'old payload')
            (installed / 'obsolete').write_text('old file')
            data = volume / 'Data/com.poc.test'
            data.mkdir(parents=True)
            for name in device.SLOTS:
                (data / name).write_text('old save')
            (data / 'unrelated').write_text('keep')
            (data / 'boot-trace.tsv').write_text('old trace')
            (volume / 'errorlog.txt').write_text('old error')
            previous = device.inventory(installed)
            earned = root / 'earned'
            earned.mkdir()
            for name in device.SLOTS:
                (earned / name).write_text('earned save')
            save_manifest = root / 'save.json'
            save_manifest.write_text(json.dumps({'directory': str(earned), 'files': [
                {'file': name, 'sha256': device.sha(earned / name)} for name in sorted(device.SLOTS)]}))
            gate = root / 'simulator-gate.json'
            names = {'heap_live_bytes', 'heap_peak_bytes', 'map_load_ms', 'battle_start_ms', 'frame_ms', 'slice_ms'}
            gate.write_text(json.dumps({'malloc_pool_mb': 16,
                'pdx_sha256': device.tree_hash(device.inventory(pdx)),
                'source_sha256': run.fingerprint(stage, exclude_generated=False),
                'measurements': dict.fromkeys(names, 1), 'limits': dict.fromkeys(names, 2)}))
            args = argparse.Namespace(simulator_gate=str(gate), output=str(root / 'evidence'), sdk=str(sdk),
                volume=str(volume), serial=None, pdx=str(pdx), build_stage=str(stage),
                earned_save=str(save_manifest) if import_save else None,
                clear_boot_trace=False, disk_timeout=1, run_seconds=0.001)
            with patch.object(device, 'OwnerLock', return_value=contextlib.nullcontext()), patch.object(device, 'simulator_usb_preflight'), contextlib.redirect_stdout(io.StringIO()):
                cycle = HostCycle(args)
                cycle.execute()
            self.assertEqual(device.inventory(installed), device.inventory(pdx))
            before = json.loads((cycle.output / 'before/installed-pdx.json').read_text())
            self.assertEqual(before['files'], previous)
            self.assertEqual((cycle.output / 'before/errorlog.txt').read_text(), 'old error')
            self.assertEqual((data / 'unrelated').read_text(), 'keep')
            self.assertEqual((data / 'boot-trace.tsv').read_text(), 'old trace')
            for name in device.SLOTS:
                self.assertEqual((data / name).read_text(), 'earned save' if import_save else 'old save')
                if import_save:
                    self.assertEqual((cycle.output / 'save-backup' / name).read_text(), 'old save')
            phases = [json.loads(line) for line in (cycle.output / 'phases.jsonl').read_text().splitlines()]
            starts = [row['phase'] for row in phases if row['status'] == 'started']
            self.assertLess(starts.index('archive-current-install-before-write'), starts.index('copy-changed-pdx-files'))


class SmokeCycleTests(unittest.TestCase):
    def setUp(self):
        from types import SimpleNamespace
        self.temp = tempfile.TemporaryDirectory(prefix='device-cycle-host-only-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stage = self.root / 'build'
        source = self.stage / 'Source'
        (source / 'dev').mkdir(parents=True)
        self.identity = 'a' * 32
        self.bundle_id = 'com.poc.pokemon.device-test.' + self.identity
        (source / 'main.lua').write_text('-- host-only private source fixture')
        (source / 'pdxinfo').write_text('bundleID=' + self.bundle_id)
        (source / 'dev/deviceSmoke.lua').write_text('-- host-only module fixture')
        self.pdx = self.stage / 'DeviceSmoke.pdx'
        self.pdx.mkdir()
        (self.pdx / 'main.pdz').write_bytes(b'host filesystem fixture; never executable')
        compiled = device.inventory(source)
        production = {**compiled, 'main.lua': '0' * 64, 'pdxinfo': '1' * 64}
        del production['dev/deviceSmoke.lua']
        self.build = dict(mode='device-test-compile-only', protocol='DS1', build_id=self.identity,
            bundle_id=self.bundle_id, bundle=str(self.pdx), compiled_source_manifest=compiled,
            compiled_source_sha256=device.tree_hash(compiled), source_sha256=run.fingerprint(self.stage, exclude_generated=False),
            production_source_manifest=production, production_source_sha256=device.tree_hash(production),
            pdx_files=device.inventory(self.pdx), pdx_sha256=device.tree_hash(device.inventory(self.pdx)),
            simulator_transport_version=1)
        (self.stage / 'build.json').write_text(json.dumps(self.build))
        self.evidence = self.root / 'simulator-evidence'
        data = self.evidence / 'runtime-data'
        data.mkdir(parents=True)
        phases = [('title.live.after_gc', 1), ('Continue.live.after_gc', 2),
                  ('door.map.begin', 3), ('door.map.end', 4),
                  ('battle.start.begin', 5), ('battle.start.end', 6)]
        self.trace = (f'schema\t1\tbuild\t{self.identity}\tplatform\tsimulator\nheader\n' + ''.join(
            f'{i}\t{phase}\t{clock}\t1\t1\t1000\t2000\n'
            for i, (phase, clock) in enumerate(phases, 1)))
        (data / 'boot-trace.tsv').write_text(self.trace)
        (data / 'device-smoke-frames.tsv').write_text(f'{self.identity}\t1\t1\treturn\t1\t1000\t0\t3\n')
        self.bodies = ['press a 1', 'state']
        responses = [dict(build=self.identity, seq=i, status='done', value=dict(
            ready=True, state='title', continue_available=True, loaded=1, saved=1)) for i in range(1, 5)]
        responses.insert(1, dict(build=self.identity, seq=2, status='accepted', value='press'))
        (self.evidence / 'responses.json').write_text(json.dumps(responses))
        (data / 'device-smoke-replies.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in responses))
        from tools.device import simulator_smoke as smoke
        self.report = dict(build=self.build, status='simulator-smoke-passed', device_gate_passed=False,
            malloc_pool_mb=16, malloc_pool_preflight=16645684, commands=self.bodies,
            commands_sha256=device.tree_hash(self.bodies), observations=smoke.observations(responses))
        self.report.update(smoke.measurements(data, self.identity, 2))
        (self.evidence / 'run.json').write_text(json.dumps(self.report))
        self.path = self.evidence / 'simulator-smoke.json'
        self.save = self.root / 'earned-save.json'
        self.save.write_text(json.dumps({'files': []}))
        (self.evidence / 'earned-save.json').write_text(self.save.read_text())
        self.args = SimpleNamespace(simulator_smoke=str(self.path), earned_save=str(self.save))
        self.write_report()

    def write_report(self):
        self.path.write_text(json.dumps(self.report))

    def gate(self):
        return device.smoke_gate(self.args, self.stage, self.pdx)

    def test_exact_gate_and_command_hash(self):
        self.assertEqual(self.gate()[2]['commands'], self.bodies)
        self.report['commands_sha256'] = 'forged'
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.gate()

    def test_diagnostic_build_is_not_hardware_admission(self):
        self.build['diagnostic_only'] = True
        (self.stage / 'build.json').write_text(json.dumps(self.build))
        (self.evidence / 'run.json').write_text(json.dumps(self.report))
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'diagnostic'):
            self.gate()

    def test_failed_status_or_forged_measurement_rejected(self):
        self.report['status'] = 'failed'
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'passed report'):
            self.gate()
        self.report['status'] = 'simulator-smoke-passed'
        self.report['measurements']['frame_ms'] = 0
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'measurements'):
            self.gate()

    def test_measurement_safety_gate_keeps_runtime_and_slice_guards(self):
        from tools.device import simulator_smoke as smoke
        self.args.safety_only = True
        frames = self.evidence / 'runtime-data/device-smoke-frames.tsv'
        frames.write_text(frames.read_text().replace('return\t1\t', 'return\t100\t'))
        self.report.update(smoke.measurements(frames.parent, self.identity, 2))
        self.report['status'] = 'failed'
        self.write_report()
        self.assertTrue(self.gate()[2]['safety_only'])
        frames.write_text(frames.read_text().replace('return\t100\t', 'return\t151\t'))
        self.report.update(smoke.measurements(frames.parent, self.identity, 2))
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'budgets failed'):
            self.gate()

    def test_failed_gate_precedes_locks_and_device_access(self):
        from types import SimpleNamespace
        self.report['status'] = 'failed'
        self.write_report()
        args = SimpleNamespace(simulator_smoke=str(self.path), earned_save=str(self.save),
            output=str(self.root / 'rejected'), volume=str(self.root / 'untouched-volume'),
            build_stage=str(self.stage), pdx=str(self.pdx), sdk=str(run.sdk_path()))
        cycle = device.Cycle(args)
        with patch.object(device, 'OwnerLock') as lock, patch.object(cycle, 'disk') as disk, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, 'passed report'):
                cycle.execute()
        lock.assert_not_called()
        disk.assert_not_called()
        self.assertFalse(cycle.volume.exists())

    def test_raw_budget_failure_rejected_even_if_report_claims_pass(self):
        frames = self.evidence / 'runtime-data/device-smoke-frames.tsv'
        frames.write_text(frames.read_text().replace('return\t1\t', 'return\t1001\t'))
        with self.assertRaisesRegex(ValueError, 'budgets failed'):
            self.gate()

    def test_source_bundle_or_observation_tamper_rejected(self):
        for path in (self.stage / 'Source/dev/deviceSmoke.lua', self.pdx / 'main.pdz'):
            before = path.read_bytes()
            path.write_bytes(before + b'changed')
            with self.assertRaisesRegex(ValueError, 'changed'):
                self.gate()
            path.write_bytes(before)
        self.report['observations']['saved'] = 0
        self.write_report()
        with self.assertRaisesRegex(ValueError, 'observations'):
            self.gate()

    def test_invalid_commands_refused(self):
        for body in ('eval x', 'press a 0', 'press a 121', 'wait 301', 'state\n'):
            self.report['commands'] = [body]
            self.write_report()
            with self.assertRaisesRegex(ValueError, 'invalid frozen'):
                self.gate()

    def transport(self, chunks):
        from types import SimpleNamespace
        cycle = SimpleNamespace(output=self.root, select_serial=lambda: True, event=lambda *a, **k: None)
        serial = device.SmokeSerial(cycle, 123, self.identity, device.time.monotonic() + 2)
        def read(*args):
            if chunks:
                return chunks.pop(0)
            raise TimeoutError('uncertain completion')
        return serial, read

    def response(self, sequence, status, value):
        return ('DS1 ' + json.dumps(dict(build=self.identity, seq=sequence, status=status, value=value)) + '\n').encode()

    def test_serial_command_echo_is_not_a_game_reply(self):
        serial, read = self.transport([b'\r\nmsg DS1 1 state\r\n' + self.response(1, 'done', {'ready': True})])
        with patch.object(device.select, 'select', return_value=([123], [], [])), patch.object(device.os, 'read', side_effect=read):
            rows = serial.read()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['seq'], 1)

    def test_transport_fragmented_boottrace_and_single_command(self):
        trace = self.trace.replace('platform\tsimulator', 'platform\tdevice')
        payload = b''.join(('BOOTTRACE\t' + line + '\n').encode() for line in trace.splitlines())
        payload += self.response(0, 'ready', 'gameplay pending')
        payload += self.response(1, 'accepted', 'press') + self.response(1, 'done', {'ready': True})
        serial, read = self.transport([payload[:17], payload[17:]])
        with patch.object(device.os, 'write', return_value=len(b'msg DS1 1 press a 1\n')) as write, patch.object(device.os, 'read', side_effect=read), patch.object(device.select, 'select', return_value=([123], [], [])):
            self.assertTrue(serial.command('press a 1')['ready'])
        write.assert_called_once_with(123, b'msg DS1 1 press a 1\n')
        self.assertTrue(serial.trace_identity)

    def test_wrong_identity_sequence_and_errors_stop_replay(self):
        for reply in (self.response(2, 'done', {}), self.response(1, 'error', 'guard'),
                      self.response(1, 'done', {}).replace(self.identity.encode(), b'wrong-build')):
            serial, read = self.transport([reply])
            with patch.object(device.os, 'write', side_effect=lambda fd, b: len(b)) as write, patch.object(device.os, 'read', side_effect=read), patch.object(device.select, 'select', return_value=([123], [], [])):
                with self.assertRaises(ValueError):
                    serial.command('press a 1')
                self.assertEqual(write.call_count, 1)

    def test_partial_write_or_uncertain_completion_never_retried(self):
        serial, read = self.transport([self.response(1, 'accepted', 'press')])
        with patch.object(device.os, 'write', return_value=1) as write:
            with self.assertRaisesRegex(RuntimeError, 'write uncertain'):
                serial.command('press a 1')
            self.assertEqual(write.call_count, 1)
        serial, read = self.transport([self.response(1, 'accepted', 'press')])
        with patch.object(device.os, 'write', side_effect=lambda fd, b: len(b)) as write, patch.object(device.os, 'read', side_effect=read), patch.object(device.select, 'select', return_value=([123], [], [])):
            with self.assertRaises(TimeoutError):
                serial.command('press a 1')
            self.assertEqual(write.call_count, 1)

    def test_raw_socket_transport_uses_real_nonblocking_io(self):
        import socket
        import threading
        client, server = socket.socketpair()
        self.addCleanup(client.close)
        self.addCleanup(server.close)
        client.setblocking(False)
        received = []
        def respond():
            received.append(server.recv(1024))
            server.sendall(self.response(1, 'accepted', 'press'))
            server.sendall(self.response(1, 'done', {'ready': True}))
        worker = threading.Thread(target=respond)
        worker.start()
        serial, _ = self.transport([])
        serial.descriptor = client.fileno()
        try:
            self.assertTrue(serial.command('press a 1')['ready'])
        finally:
            worker.join(timeout=2)
        self.assertFalse(worker.is_alive())
        self.assertEqual(received, [b'msg DS1 1 press a 1\n'])

    def test_deadline_sends_no_new_input(self):
        serial, _ = self.transport([])
        serial.deadline = 0
        with patch.object(device.os, 'write') as write:
            with self.assertRaises(TimeoutError):
                serial.command('press a 1')
            write.assert_not_called()

    def test_only_actual_ready_allows_frozen_route(self):
        from types import SimpleNamespace
        cycle = device.Cycle(SimpleNamespace(output=str(self.root / 'cycle'), volume=str(self.root / 'volume')))
        cycle.serial = '/host-fixture'
        cycle.smoke_build, cycle.smoke_report = self.build, self.report
        with patch.object(device, 'simulator_usb_preflight'), patch.object(device.os, 'open', return_value=123), patch.object(device.os, 'close') as close, patch.object(device.SmokeSerial, 'read', return_value=[{'seq': 0, 'status': 'ready'}]), patch.object(device.SmokeSerial, 'command', side_effect=[{'ready': False}, {'ready': True}, {}, {}, {}]) as command:
            cycle.wait_smoke(device.time.monotonic() + 2)
        self.assertEqual([row.args[0] for row in command.call_args_list], ['state', 'state', *self.bodies, 'state'])
        close.assert_called_once_with(123)

    def test_missing_usb_is_immediate_hard_stop(self):
        serial, _ = self.transport([])
        serial.cycle.select_serial = lambda: False
        with patch.object(device.select, 'select') as select_call:
            with self.assertRaisesRegex(RuntimeError, 'needs one A press'):
                serial.read()
            select_call.assert_not_called()

    def test_reader_closes_after_failure(self):
        from types import SimpleNamespace
        args = SimpleNamespace(output=str(self.root / 'cycle'), volume=str(self.root / 'volume'))
        cycle = device.Cycle(args)
        cycle.serial = '/host-fixture'
        cycle.smoke_build, cycle.smoke_report = self.build, self.report
        with patch.object(device, 'simulator_usb_preflight'), patch.object(device.os, 'open', return_value=123), patch.object(device.os, 'close') as close, patch.object(device.SmokeSerial, 'read', return_value=[{'seq': 0, 'status': 'ready'}]), patch.object(device.SmokeSerial, 'command', side_effect=TimeoutError('uncertain')):
            with self.assertRaises(TimeoutError):
                cycle.wait_smoke(device.time.monotonic() + 1)
            close.assert_called_once_with(123)
        self.assertTrue((cycle.output / 'device-responses.json').exists())

    def test_archive_uses_installed_bundle_id_and_full_data(self):
        from types import SimpleNamespace
        cycle = device.Cycle(SimpleNamespace(output=str(self.root / 'cycle'), volume=str(self.root / 'volume')))
        installed = cycle.volume / 'Games/DeviceSmoke.pdx'
        installed.mkdir(parents=True)
        (installed / 'pdxinfo').write_text('bundleID=old.actual.id')
        (installed / 'main.pdz').write_bytes(b'old binary')
        data = cycle.volume / 'Data/old.actual.id'
        data.mkdir(parents=True)
        (data / 'adventure.a.json').write_text('previous installed save')
        (data / 'boot-trace.tsv').write_text('previous installed trace')
        cycle.archive('before', installed, cycle.volume / 'Data/new.id')
        self.assertEqual((cycle.output / 'before/Data/old.actual.id/adventure.a.json').read_text(), 'previous installed save')

    def test_bounded_cycle_archives_uncertain_attempt_without_relaunch(self):
        from types import SimpleNamespace
        sdk = run.sdk_path()
        self.build.update(compiler_sha256=device.sha(sdk / 'bin/pdc'),
                          sdk_version=(sdk / 'VERSION.txt').read_text().strip())
        (self.stage / 'build.json').write_text(json.dumps(self.build))
        self.write_report()
        (self.evidence / 'run.json').write_text(json.dumps(self.report))
        slots = self.root / 'slots'
        slots.mkdir()
        rows = []
        for name in sorted(device.SLOTS):
            (slots / name).write_bytes(b'host-only opaque slot transfer fixture')
            rows.append(dict(file=name, sha256=device.sha(slots / name)))
        self.save.write_text(json.dumps(dict(directory=str(slots), files=rows)))
        (self.evidence / 'earned-save.json').write_text(self.save.read_text())
        volume = self.root / 'PLAYDATE'
        (volume / 'Games').mkdir(parents=True)
        args = SimpleNamespace(simulator_smoke=str(self.path), earned_save=str(self.save),
            output=str(self.root / 'cycle'), volume=str(volume), build_stage=str(self.stage),
            pdx=str(self.pdx), sdk=str(sdk), serial=None, clear_boot_trace=False,
            disk_timeout=1, run_seconds=1, leave_running=True)
        cycle = HostCycle(args)
        def uncertain(deadline):
            cycle.smoke_transport = SimpleNamespace(responses=[])
            data = volume.with_name('unmounted') / 'Data' / self.bundle_id
            (data / 'boot-trace.tsv').write_text(self.trace.replace('platform\tsimulator', 'platform\tdevice'))
            raise TimeoutError('completion uncertain; no replay')
        with patch.object(device, 'OwnerLock', return_value=contextlib.nullcontext()), patch.object(device, 'simulator_usb_preflight'), patch.object(cycle, 'wait_smoke', side_effect=uncertain), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(TimeoutError, 'completion uncertain'):
                cycle.execute()
        self.assertTrue((cycle.output / 'after/Data' / self.bundle_id / 'boot-trace.tsv').exists())
        phases = [json.loads(line) for line in (cycle.output / 'phases.jsonl').read_text().splitlines()]
        launches = [r for r in phases if r['status'] == 'host-mocked-command' and 'run' in r['argv']]
        self.assertEqual(len(launches), 1)
        self.assertTrue(volume.exists())

    def test_missing_metrics_cannot_claim_acceptance(self):
        from types import SimpleNamespace
        cycle = device.Cycle(SimpleNamespace(output=str(self.root / 'cycle'), volume=str(self.root / 'volume')))
        cycle.smoke_build, cycle.smoke_report = self.build, self.report
        cycle.smoke_transport = SimpleNamespace(responses=[])
        cycle.report_smoke(self.bundle_id)
        report = json.loads((cycle.output / 'device-smoke.json').read_text())
        self.assertFalse(report['device_gate_passed'])
        self.assertTrue(report['failures'])


class DeviceMetricsCompileTests(unittest.TestCase):
    def test_device_metrics_compile_with_simulator_only_mailbox(self):
        import subprocess
        from tools.device import build_smoke
        from tools.device import simulator_smoke
        project = Path(__file__).resolve().parents[2]
        original = (project / 'Source/dev/deviceSmoke.lua').read_bytes()
        with tempfile.TemporaryDirectory(prefix='device-metrics-compile-only-') as root:
            root = Path(root)
            candidate = root / 'candidate'
            shutil.copytree(project / 'Source', candidate / 'Source')
            module = (candidate / 'Source/dev/deviceSmoke.lua').read_text()
            self.assertIn('local function poll()\n        if not playdate.isSimulator then', module)
            observer = module.split('function DeviceSmoke.installSimulatorObserver()', 1)[1]
            self.assertFalse(observer.lstrip().startswith('if not playdate.isSimulator'))
            with patch.object(build_smoke.subprocess, 'check_output', return_value='309194ee0b35f329426d21f8c19b9c0442780d11\n'):
                metadata = build_smoke.prepare(candidate, run.sdk_path(), root / 'build')
            self.assertEqual(simulator_smoke.verify(root / 'build'), metadata)
        self.assertEqual((project / 'Source/dev/deviceSmoke.lua').read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
