"""Host protocol tests only. No fake SDK, Lua interpreter or Simulator."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import wave

from tools.harness.protocol import OwnerLock, ProtocolError, atomic_json

SPEC = importlib.util.spec_from_file_location('sdk_probe', Path(__file__).parents[1] / 'audio/sdk_probe.py')
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class ProbeTests(unittest.TestCase):
    def test_command_defaults_and_bounds(self):
        args = probe.parse_args([])
        self.assertFalse(args.execute)
        self.assertFalse(args.audible)
        self.assertEqual(args.mode, 'both')
        for value in ('nan', 'inf', '-1', '19.9', '90.1', 'abc'):
            with self.assertRaises(Exception):
                probe.bounded_seconds(value)
        for value in ('20', '90'):
            self.assertEqual(probe.bounded_seconds(value), float(value))
        for argv in (['--execute'], ['--audible'], ['--mode', 'bogus']):
            with self.assertRaises(SystemExit), patch('sys.stderr'):
                probe.parse_args(argv)
        self.assertTrue(probe.parse_args(['--execute', '--runtime-owner', 'root', '--audible']).audible)

    def test_synthetic_pcm_is_bounded_deterministic_and_distinct(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            hashes = []
            for voice in range(1, 5):
                path = root / f'{voice}.wav'
                probe.marker(path, voice)
                hashes.append(probe.sha(path))
                with wave.open(str(path)) as sample:
                    self.assertEqual(sample.getparams()[:4], (1, 2, 44100, 5292))
                probe.marker(root / 'again.wav', voice)
                self.assertEqual(probe.sha(path), probe.sha(root / 'again.wav'))
            self.assertEqual(len(set(hashes)), 4)

    def test_result_requires_exact_identity_and_stopped_producer(self):
        identity = dict(mode='streams', session_id='a', source_sha256='s', tool_sha256='t', asset_sha256='x')
        result = dict(identity=identity, quiescent=True, publication='producer-stopped-v1', status='complete')
        probe.validate_result(result, identity)
        for key in identity:
            changed = copy.deepcopy(result)
            changed['identity'][key] += 'wrong'
            with self.assertRaises(ProtocolError):
                probe.validate_result(changed, identity)
        for key, value in [('quiescent', False), ('publication', 'running'), ('status', 'running')]:
            with self.assertRaises(ProtocolError):
                probe.validate_result(dict(result, **{key: value}), identity)

    def test_final_read_requires_last_barrier_and_matching_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            data = Path(temporary)
            result = dict(identity={'probe_id': 'a'}, status='complete', quiescent=True,
                          publication='producer-stopped-v1')
            atomic_json(data / 'RuntimeSnapshot.json', result)
            with self.assertRaises(FileNotFoundError):
                probe.read_final(data, result['identity'])
            atomic_json(data / 'done.json', result)
            self.assertEqual(probe.read_final(data, result['identity']), result)
            atomic_json(data / 'RuntimeSnapshot.json', dict(result, identity={'probe_id': 'stale'}))
            with self.assertRaises(ProtocolError):
                probe.read_final(data, result['identity'])

    def test_staging_and_bundle_mutations_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Source').mkdir()
            bundle = root / 'probe.pdx'
            bundle.mkdir()
            (root / 'Source/main.lua').write_text('original')
            (bundle / 'main.pdz').write_bytes(b'compiled')
            metadata = dict(bundle=str(bundle), staged_manifest=probe.inventory(root / 'Source'),
                            compiled_manifest=probe.inventory(bundle))
            probe.verify_staging(metadata, root)
            (bundle / 'main.pdz').write_bytes(b'changed')
            with self.assertRaises(ProtocolError):
                probe.verify_staging(metadata, root)
            (bundle / 'main.pdz').write_bytes(b'compiled')
            (root / 'Source/main.lua').write_text('changed')
            with self.assertRaises(ProtocolError):
                probe.verify_staging(metadata, root)

    def test_no_execution_without_live_global_owner(self):
        with tempfile.TemporaryDirectory() as temporary:
            metadata = {'sdk': temporary}
            with self.assertRaisesRegex(ProtocolError, 'global OwnerLock'):
                probe.execute(metadata, Path(temporary), 20, None)
            with OwnerLock(Path(temporary) / 'wrong.lock') as owner:
                with self.assertRaisesRegex(ProtocolError, 'global OwnerLock'):
                    probe.execute(metadata, Path(temporary), 20, owner)

    def test_global_lock_cannot_be_double_owned(self):
        with tempfile.TemporaryDirectory() as temporary:
            with OwnerLock(Path(temporary) / 'global.lock'):
                with self.assertRaises(ProtocolError):
                    with OwnerLock(Path(temporary) / 'global.lock'):
                        self.fail('second owner acquired lock')

    def test_collision_does_not_adopt_or_clean_foreign_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            sdk = Path(temporary)
            bundle_id = 'com.poc.pokemon.audioprobe.test'
            data = sdk / 'Disk/Data' / bundle_id
            data.mkdir(parents=True)
            (data / 'foreign').write_text('keep')
            metadata = {'sdk': str(sdk), 'data_dir': str(data), 'identity': {'bundle_id': bundle_id}}
            lock = sdk / 'global.lock'
            with OwnerLock(lock) as owner, patch.object(probe, 'runtime_lock_path', return_value=lock):
                with patch.object(probe, 'verify_staging'), self.assertRaises(FileExistsError):
                    probe.execute(metadata, sdk, 20, owner)
            self.assertEqual((data / 'foreign').read_text(), 'keep')

    def test_launch_failure_cleans_only_new_owned_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            sdk = Path(temporary)
            (sdk / 'Disk/Data').mkdir(parents=True)
            sibling = sdk / 'Disk/Data/foreign'
            sibling.mkdir()
            bundle_id = 'com.poc.pokemon.audioprobe.test'
            data = sdk / 'Disk/Data' / bundle_id
            metadata = {'sdk': str(sdk), 'data_dir': str(data), 'identity': {'bundle_id': bundle_id},
                        'simulator': '/never/launched', 'bundle': '/never/opened'}
            lock = sdk / 'global.lock'
            with OwnerLock(lock) as owner, patch.object(probe, 'runtime_lock_path', return_value=lock):
                with patch.object(probe, 'verify_staging'), patch.object(probe.subprocess, 'Popen', side_effect=OSError('launch failed')):
                    with self.assertRaisesRegex(OSError, 'launch failed'):
                        probe.execute(metadata, sdk, 20, owner)
            self.assertFalse(data.exists())
            self.assertTrue(sibling.is_dir())

    def test_timeout_cancellation_is_bounded_and_not_accepted(self):
        from unittest.mock import Mock
        with tempfile.TemporaryDirectory() as temporary:
            sdk = Path(temporary)
            (sdk / 'Disk/Data').mkdir(parents=True)
            bundle_id = 'com.poc.pokemon.audioprobe.timeout'
            data = sdk / 'Disk/Data' / bundle_id
            identity = {'bundle_id': bundle_id, 'probe_id': 'timeout'}
            metadata = {'sdk': str(sdk), 'data_dir': str(data), 'identity': identity,
                        'simulator': '/never/launched', 'bundle': '/never/opened'}
            lock = sdk / 'global.lock'
            child = Mock(pid=123)
            child.poll.return_value = None
            with OwnerLock(lock) as owner, patch.object(probe, 'runtime_lock_path', return_value=lock):
                with patch.object(probe, 'verify_staging'), patch.object(probe.subprocess, 'Popen', return_value=child):
                    with patch.object(probe.time, 'monotonic', side_effect=[0, 21, 21, 25]), patch.object(probe.time, 'sleep'):
                        with self.assertRaisesRegex(ProtocolError, 'cancellation barrier timed out'):
                            probe.execute(metadata, sdk, 20, owner)
            self.assertEqual(json.loads((sdk / 'raw-cancel.json').read_text()), {'identity': identity})
            self.assertFalse((sdk / 'RuntimeSnapshot.json').exists())
            self.assertFalse(data.exists())
            child.terminate.assert_called_once_with()

    def test_exact_child_cleanup_is_bounded(self):
        from unittest.mock import Mock
        child = Mock()
        child.poll.return_value = None
        child.wait.side_effect = [subprocess.TimeoutExpired('owned', 3), 0]
        probe.stop_child(child)
        child.terminate.assert_called_once_with()
        child.kill.assert_called_once_with()
        self.assertEqual(child.wait.call_count, 2)
        probe.stop_child(None)

    def test_output_must_be_durable_environment_evidence(self):
        args = probe.parse_args(['--output', '/private/tmp/forbidden-audio-probe'])
        with patch.object(probe, 'sdk_path', return_value=Path.home() / 'Developer/PlaydateSDK'):
            with self.assertRaisesRegex(ProtocolError, 'environment evidence'):
                probe.run(args)


if __name__ == '__main__':
    unittest.main()
