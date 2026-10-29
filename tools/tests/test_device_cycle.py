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


if __name__ == '__main__':
    unittest.main()
