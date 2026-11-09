"""Platform dispatch for the official Simulator binary and its 16MB pool file.

These checks never launch the Simulator. Darwin keeps the macOS preferences
path. Other platforms read the ini Linux SDK 3.1.2 writes.
"""
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

from tools.harness import protocol, run
from tools.harness.protocol import ProtocolError, shared_lock_directory


class SimulatorPlatformTests(unittest.TestCase):
    def test_darwin_settings_path_stays_the_library_preferences_file(self):
        with patch.object(run.sys, 'platform', 'darwin'):
            self.assertEqual(
                run.simulator_settings_file(),
                Path.home() / 'Library/Preferences/com.panic.Playdate Simulator.ini')

    def test_linux_settings_path_is_the_sdk_config_file(self):
        with patch.object(run.sys, 'platform', 'linux'):
            self.assertEqual(
                run.simulator_settings_file(),
                Path.home() / '.config/Playdate Simulator/Playdate Simulator.ini')

    def test_preflight_requires_the_exact_16mb_pool_value(self):
        with tempfile.TemporaryDirectory() as temporary:
            settings = Path(temporary) / 'Playdate Simulator.ini'
            settings.write_text('ShowPerfWarning=0\nMallocPoolSize=0\n')
            with patch.object(run, 'simulator_usb_preflight'), \
                    patch.object(run, 'simulator_settings_file', return_value=settings):
                with self.assertRaisesRegex(ProtocolError, '16MB'):
                    run.simulator_preflight()
            settings.write_text('[LastUsed]\nPDXDirectory=/tmp/Launcher.pdx/\n')
            with patch.object(run, 'simulator_usb_preflight'), \
                    patch.object(run, 'simulator_settings_file', return_value=settings):
                with self.assertRaisesRegex(ProtocolError, '16MB'):
                    run.simulator_preflight()
            settings.write_text('MallocPoolSize=16645684\n[LastUsed]\nRelease=3.1.2\n')
            with patch.object(run, 'simulator_usb_preflight'), \
                    patch.object(run, 'simulator_settings_file', return_value=settings):
                run.simulator_preflight()

    def test_executable_prefers_an_existing_macos_bundle_then_the_linux_binary(self):
        with tempfile.TemporaryDirectory() as temporary:
            sdk = Path(temporary)
            mac = sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'
            linux = sdk / 'bin/PlaydateSimulator'
            self.assertEqual(run.simulator_executable(sdk), mac)
            linux.parent.mkdir(parents=True)
            linux.write_text('#!/bin/sh\n')
            linux.chmod(linux.stat().st_mode | stat.S_IEXEC)
            self.assertEqual(run.simulator_executable(sdk), linux)
            mac.parent.mkdir(parents=True)
            mac.write_text('#!/bin/sh\n')
            mac.chmod(mac.stat().st_mode | stat.S_IEXEC)
            self.assertEqual(run.simulator_executable(sdk), mac)

    def test_lock_directory_stays_private_tmp_on_darwin_and_tmp_on_linux(self):
        with patch.object(protocol.sys, 'platform', 'darwin'), patch.object(run.sys, 'platform', 'darwin'):
            self.assertEqual(shared_lock_directory(), Path('/private/tmp'))
            self.assertEqual(run.runtime_lock_path(Path('/sdk')).parent, Path('/private/tmp'))
            self.assertEqual(run.device_lock_path().parent, Path('/private/tmp'))
            self.assertEqual(run.eject_argv(Path('/Volumes/PLAYDATE'))[0], 'diskutil')
        with patch.object(protocol.sys, 'platform', 'linux'), patch.object(run.sys, 'platform', 'linux'):
            self.assertEqual(shared_lock_directory(), Path('/tmp'))
            self.assertEqual(run.runtime_lock_path(Path('/sdk')).parent, Path('/tmp'))
            self.assertEqual(run.device_lock_path().parent, Path('/tmp'))
            self.assertEqual(run.eject_argv(Path('/media/PLAYDATE'))[:3], ['udisksctl', 'unmount', '-p'])

    def test_linux_serial_scan_rejects_an_unusable_playdate_node(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sysfs = root / 'sys'
            device = sysfs / 'ttyACM0' / 'device'
            device.mkdir(parents=True)
            (device / 'manufacturer').write_text('Panic Inc\n')
            (device / 'product').write_text('Playdate\n')
            dev = root / 'dev'
            dev.mkdir()
            node = dev / 'ttyACM0'
            node.write_text('')
            node.chmod(0)
            with self.assertRaisesRegex(ProtocolError, 'not readable and writable'):
                run.linux_playdate_serial_ports(sysfs, dev)
            node.chmod(0o600)
            self.assertEqual(run.linux_playdate_serial_ports(sysfs, dev), [str(node)])

    def test_linux_serial_scan_ignores_other_acm_devices(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sysfs = root / 'sys'
            device = sysfs / 'ttyACM0' / 'device'
            device.mkdir(parents=True)
            (device / 'manufacturer').write_text('Arduino\n')
            (device / 'product').write_text('Uno\n')
            dev = root / 'dev'
            dev.mkdir()
            (dev / 'ttyACM0').write_text('')
            self.assertEqual(run.linux_playdate_serial_ports(sysfs, dev), [])


if __name__ == '__main__':
    unittest.main()
