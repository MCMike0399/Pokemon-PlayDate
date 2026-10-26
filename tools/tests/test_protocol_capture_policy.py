"""Host staging/CLI checks only; sampling behavior requires the native SDK."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.harness import run, suite
from tools.harness.protocol import ProtocolError


class CapturePolicyTests(unittest.TestCase):
    def test_option_bounds_and_types(self):
        for value in (1, '60', 2147483647):
            self.assertEqual(run.validate_recent_interval(value), int(value))
        for value in (0, -1, 2147483648, True, 1.5, '1.5', 'no'):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                run.validate_recent_interval(value)
        for script in ('run.py', 'suite.py'):
            result = subprocess.run([sys.executable, str(run.PROJECT / 'tools/harness' / script),
                                     '--recent-interval', '0'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('recent interval must be in', result.stderr)

    def stage(self, root, interval):
        project, sdk, output = (root / name for name in ('project', 'sdk', 'output'))
        (project / 'Source/dev').mkdir(parents=True)
        sdk.mkdir()
        output.mkdir()
        original = (run.PROJECT / 'Source/main.lua').read_bytes()
        (project / 'Source/main.lua').write_bytes(original)
        (project / 'Source/pdxinfo').write_text('bundleID=original\n')
        (project / 'Source/dev/harness_build.lua').write_text('HarnessBuild = {enabled=false}\n')
        (sdk / 'VERSION.txt').write_text('3.1.2')
        expected_hash = run.fingerprint(project)
        copytree = shutil.copytree

        def copied(source, destination, *args, **kwargs):
            copytree(source, destination, *args, **kwargs)
            # Any later live Source read would misidentify the build.
            if Path(source) == project / 'Source':
                (project / 'Source/main.lua').write_bytes(b'live edit after snapshot')

        with patch.object(run.shutil, 'copytree', side_effect=copied), \
             patch.object(run.subprocess, 'check_output', side_effect=['revision\n', 'dirty\n']), \
             patch.object(run.subprocess, 'run') as compile_job:
            metadata = run.prepare(project, sdk, output, 'session', interval)
        self.assertEqual(compile_job.call_args.args[0][0], str(sdk / 'bin/pdc'))
        self.assertEqual(metadata['source_sha256'], expected_hash)
        self.assertEqual(metadata['build_id'], 'revision:' + expected_hash)
        self.assertEqual(metadata['compiled_source_sha256'], run.fingerprint(output, False))
        self.assertEqual((output / metadata['original_main_file']).read_bytes(), original)
        manifest = json.loads((output / 'source-manifest.json').read_text())
        self.assertEqual(manifest['main.lua'], hashlib.sha256(original).hexdigest())
        self.assertNotIn('dev/capture_policy.lua', manifest)
        # Reconstruct the original hash from retained bytes, without live Source.
        reconstructed = root / 'reconstructed'
        shutil.copytree(output / 'Source', reconstructed / 'Source')
        (reconstructed / 'Source/main.lua').write_bytes(original)
        (reconstructed / 'Source/pdxinfo').write_text(metadata['original_pdxinfo'])
        (reconstructed / 'Source/dev/capture_policy.lua').unlink(missing_ok=True)
        self.assertEqual(run.fingerprint(reconstructed), expected_hash)
        return output, metadata, original

    def test_default_preserves_runtime_source_path(self):
        with tempfile.TemporaryDirectory() as directory:
            output, metadata, original = self.stage(Path(directory), 1)
            self.assertNotIn(b'import "dev/capture_policy"', (output / 'Source/main.lua').read_bytes())
            self.assertNotIn(b'-- @harness ', (output / 'Source/main.lua').read_bytes())
            self.assertFalse((output / 'Source/dev/capture_policy.lua').exists())
            self.assertNotIn('recent_interval', (output / 'Source/dev/harness_build.lua').read_text())
            self.assertEqual(metadata['generated_overlays'], ['Source/main.lua', 'Source/dev/harness_build.lua', 'Source/pdxinfo'])
            self.assertFalse(metadata['capture_policy']['final_completed_sample'])

    def test_overlay_identity_and_original_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            default, _, _ = self.stage(Path(directory) / 'default', 1)
            output, metadata, original = self.stage(Path(directory) / 'sampled', 60)
            self.assertEqual((output / 'Source/main.lua').read_bytes(),
                             (default / 'Source/main.lua').read_bytes() + b'\nimport "dev/capture_policy"\n')
            self.assertEqual((output / 'Source/dev/capture_policy.lua').read_bytes(),
                             Path(run.__file__).with_name('capture_policy.lua').read_bytes())
            self.assertIn('recent_interval = 60,', (output / 'Source/dev/harness_build.lua').read_text())
            self.assertEqual(metadata['capture_policy'], {'recent_interval': 60, 'recent_limit': 8,
                                                         'final_completed_sample': True})
            self.assertIn('Source/main.lua', metadata['generated_overlays'])
            self.assertIn('Source/dev/capture_policy.lua', metadata['generated_overlays'])
            (output / 'Source/dev/capture_policy.lua').write_text('-- changed')
            self.assertNotEqual(metadata['compiled_source_sha256'], run.fingerprint(output, False))

    def test_suite_propagates_and_records_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            args = argparse.Namespace(output=str(root / 'suite'), only=['smoke'], mutations=False,
                                      plan_only=False, continue_on_failure=False, job_timeout=1,
                                      sdk=None, recent_interval=60)
            commands = []

            def launch(command, wrapper, timeout):
                commands.append(command)
                return {'returncode': 1, 'timed_out': False}

            with patch.object(suite, 'suite_lock_path', return_value=root / 'lock'):
                self.assertEqual(suite.execute_suite(args, launch), 1)
            self.assertEqual(commands[0][commands[0].index('--recent-interval') + 1], '60')
            for name in ('suite-plan.json', 'suite.json'):
                self.assertEqual(json.loads((root / 'suite' / name).read_text())['recent_interval'], 60)
            args.only, args.mutations = ['mutations'], True
            with self.assertRaisesRegex(ProtocolError, 'separate mutation builder'):
                suite.execute_suite(args, launch)

    def test_no_host_relabeling_of_capture_metadata(self):
        # finalize_captures must preserve native tick/phase/offset even for an
        # unusual diagnostic entry; these tests cannot certify SDK semantics.
        from tools.tests.test_protocol_captures import png
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'frames').mkdir()
            (root / 'frames/raw.png').write_bytes(png())
            (root / 'frames/display.png').write_bytes(png())
            capture = {'tick': 137, 'phase': 'partial-error', 'display': {'offsetX': -3, 'offsetY': 2},
                       'raw': 'raw.png', 'presentation': 'display.png', 'storage': 'frames'}
            expected = json.loads(json.dumps(capture))
            manifest = {'quiescent': True, 'captures': [capture], 'capture_count': 1,
                        'recent_frames': [], 'recent_count': 0}
            from unittest.mock import Mock
            client = Mock()
            client.quiesce.return_value = {'quiescent': True}
            client.read.return_value = manifest
            self.assertEqual(run.finalize_captures(client, root, root)['captures'][0], expected)
            self.assertEqual(json.loads((root / 'captures.json').read_text())['captures'][0], expected)


if __name__ == '__main__':
    unittest.main()
