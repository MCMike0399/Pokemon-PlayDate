import json
from pathlib import Path
import tempfile
import threading
import time
import unittest

from tools.harness.protocol import Client, OwnerLock, ProtocolError, atomic_json


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data'
        self.data.mkdir()
        self.client = Client(self.data, 'build-a', 'session-a', self.root / 'evidence')
        self.addCleanup(self.client.close)

    def response(self, **fields):
        return self.client.envelope(**fields)

    def runtime(self, callback):
        errors = []
        def serve():
            try:
                deadline = time.monotonic() + 2
                while not (self.data / 'request.json').exists():
                    if time.monotonic() >= deadline:
                        raise AssertionError('no request published')
                    time.sleep(.005)
                callback(json.loads((self.data / 'request.json').read_text()))
            except BaseException as error:
                errors.append(error)
        thread = threading.Thread(target=serve)
        thread.start()
        self.addCleanup(lambda: self.assertEqual(errors, []))
        self.addCleanup(thread.join, 3)
        return thread

    def test_unicode_request_uses_literal_utf8_and_matching_evidence_bytes(self):
        text = "RED threw a POKé BALL!"
        commands = [{'op': 'assert', 'path': 'battle.message', 'equals': text}]
        def reply(request):
            wire = (self.data / 'request.json').read_bytes()
            saved = (self.root / 'evidence/00001-request.json').read_bytes()
            self.assertEqual(wire, saved)
            self.assertIn(b'POK\xc3\xa9 BALL', wire)
            self.assertNotIn(b'\\u00e9', wire)
            self.assertEqual(request['commands'], commands)
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='ok',
                results=[{'command':1,'status':'ok'}], snapshot={'message':text}))
        self.runtime(reply)
        result = self.client.send(commands, timeout=1)
        self.assertEqual(result['snapshot']['message'], text)

    def test_atomic_json_preserves_multibyte_text_and_json_escaping(self):
        value = {'text': 'POKé BALL / 海 / 😀', 'control': 'line\n"quote"\\slash'}
        path = self.root / 'unicode.json'
        atomic_json(path, value)
        wire = path.read_bytes()
        self.assertIn('POKé BALL / 海 / 😀'.encode('utf-8'), wire)
        self.assertEqual(json.loads(wire.decode('utf-8')), value)
        self.assertEqual(list(self.root.glob('unicode.json.*.tmp')), [])

    def test_invalid_single_byte_utf8_result_is_still_rejected_and_pending(self):
        def reply(request):
            # The exact invalid E9 class observed after SDK decoding \u00e9.
            wire = json.dumps(self.response(id=request['id'], status='ok',
                results=[{'command':1,'status':'ok'}], snapshot={'message':'MARKER'})).encode('ascii')
            (self.data / 'result.json').write_bytes(wire.replace(b'MARKER', b'POK\xe9 BALL'))
        self.runtime(reply)
        with self.assertRaisesRegex(ProtocolError, 'malformed result.json'):
            self.client.send(['gamestate'], timeout=1)
        self.assertIsNotNone(self.client._pending_id)

    def test_ready_handshake_and_wrong_build(self):
        atomic_json(self.data / 'ready.json', self.response(status='ready'))
        self.assertEqual(self.client.ready(.1)['status'], 'ready')
        atomic_json(self.data / 'ready.json', dict(self.response(status='ready'), build_id='old'))
        with self.assertRaisesRegex(ProtocolError, 'wrong build_id'):
            self.client.ready(.1)

    def test_malformed_reply_fails(self):
        (self.data / 'ready.json').write_text('{broken')
        with self.assertRaisesRegex(ProtocolError, 'malformed'):
            self.client.ready(.1)

    def test_non_object_reply_fails(self):
        (self.data / 'ready.json').write_text('[]')
        with self.assertRaisesRegex(ProtocolError, 'object required'):
            self.client.ready(.1)

    def test_stale_id_is_never_accepted(self):
        atomic_json(self.data / 'result.json', self.response(id='old-id', status='ok'))
        def reply(request):
            time.sleep(.08)
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='ok', results=[{'command':1,'status':'ok'}], snapshot={}))
        self.runtime(reply)
        result = self.client.send(['snapshot'], timeout=1)
        self.assertNotEqual(result['id'], 'old-id')
        self.assertTrue((self.root / 'evidence/stale-result.json').exists())

    def test_invalid_command_runtime_error_is_failure(self):
        def reply(request):
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='error', error='invalid command'))
        self.runtime(reply)
        with self.assertRaisesRegex(ProtocolError, 'invalid command'):
            self.client.send(['bogus'], timeout=1)

    def test_incomplete_success_is_failure(self):
        def reply(request):
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='ok', results=[], snapshot={}))
        self.runtime(reply)
        with self.assertRaisesRegex(ProtocolError, 'incomplete per-command'):
            self.client.send(['snapshot'], timeout=1)

    def test_success_missing_snapshot_is_failure(self):
        def reply(request):
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='ok', results=[{'command':1,'status':'ok'}]))
        self.runtime(reply)
        with self.assertRaisesRegex(ProtocolError, 'missing final snapshot'):
            self.client.send(['snapshot'], timeout=1)

    def test_wrong_session_fails(self):
        atomic_json(self.data / 'result.json', dict(self.response(id='old', status='ok'), session_id='other'))
        with self.assertRaisesRegex(ProtocolError, 'wrong session_id'):
            self.client.send(['snapshot'], timeout=.1)

    def test_timeout_sends_cancel_and_requires_ack(self):
        def reply(request):
            deadline = time.monotonic() + 1
            while not (self.data / 'cancel.json').exists() and time.monotonic() < deadline:
                time.sleep(.005)
            cancel = json.loads((self.data / 'cancel.json').read_text())
            self.assertEqual(cancel['id'], request['id'])
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='cancelled'))
        self.runtime(reply)
        with self.assertRaisesRegex(ProtocolError, 'cancellation acknowledged'):
            self.client.send(['wait 1000'], timeout=.04)

    def test_quiescence_is_terminal_and_idempotent(self):
        def reply(request):
            self.assertEqual(request['commands'], ['quiesce'])
            atomic_json(self.data / 'result.json', self.response(id=request['id'], status='ok',
                results=[{'command':1,'status':'ok'}], snapshot={}, quiescent=True))
        self.runtime(reply)
        result = self.client.quiesce()
        self.assertEqual(self.client.quiesce(), result)
        with self.assertRaisesRegex(ProtocolError, 'runtime is quiescent'):
            self.client.send(['snapshot'])

    def test_unconfirmed_timeout_blocks_reuse(self):
        with self.assertRaisesRegex(ProtocolError, 'cancellation unconfirmed'):
            self.client.send(['wait 1000'], timeout=.001)
        cancel = json.loads((self.data / 'cancel.json').read_text())
        self.assertEqual(cancel['session_id'], 'session-a')
        with self.assertRaisesRegex(ProtocolError, 'unconfirmed pending request'):
            self.client.send(['snapshot'])

    def test_exclusive_lock_and_recovery(self):
        lock = self.data / 'independent.lock'
        with OwnerLock(lock):
            with self.assertRaisesRegex(ProtocolError, 'already has an owner'):
                with OwnerLock(lock):
                    self.fail('two owners')
        with OwnerLock(lock):
            pass

    def test_second_client_cannot_bypass_ownership(self):
        with self.assertRaisesRegex(ProtocolError, 'already has an owner'):
            Client(self.data, 'build-a', 'session-a', self.root / 'other-evidence')
        self.client.close()
        with Client(self.data, 'build-a', 'session-a', self.root / 'other-evidence'):
            pass

    def test_closed_owner_cannot_send(self):
        self.client.close()
        with self.assertRaisesRegex(ProtocolError, 'no longer held'):
            self.client.send(['snapshot'])

    def test_second_runner_rejected_before_prepare(self):
        import importlib
        from argparse import Namespace
        from unittest.mock import patch
        runner = importlib.import_module('tools.harness.run')
        sdk = self.root / 'sdk'
        private_lock = self.root / 'simulator-global.lock'
        with OwnerLock(private_lock):
            with patch.object(runner, 'runtime_lock_path', return_value=private_lock), patch.object(runner, 'sdk_path', return_value=sdk), patch.object(runner, '_run') as prepare:
                with self.assertRaisesRegex(ProtocolError, 'already has an owner'):
                    runner.run(Namespace(sdk=str(sdk), build_only=False))
                prepare.assert_not_called()

    def test_corrupt_reply_blocks_next_send_until_recovery(self):
        atomic_json(self.data / 'result.json', dict(self.response(status='ok', id='wrong'), build_id='wrong'))
        with self.assertRaisesRegex(ProtocolError, 'wrong build_id'):
            self.client.send(['snapshot'])
        with self.assertRaisesRegex(ProtocolError, 'unconfirmed pending request'):
            self.client.send(['hold right'])

    def test_fingerprint_uses_staged_source_after_copy(self):
        import importlib
        import shutil
        from unittest.mock import patch
        runner = importlib.import_module('tools.harness.run')
        project = self.root / 'project'
        source = project / 'Source'
        (source / 'dev').mkdir(parents=True)
        (source / 'main.lua').write_text('original staged bytes')
        (source / 'pdxinfo').write_text('bundleID=original\n')
        (source / 'dev/harness_build.lua').write_text('default config')
        expected_hash = runner.fingerprint(project)
        sdk = self.root / 'sdk'
        sdk.mkdir()
        (sdk / 'VERSION.txt').write_text('3.1.2')
        output = self.root / 'build'
        output.mkdir()
        real_copy = shutil.copytree
        def mutate_after_copy(src, dest, *args, **kwargs):
            real_copy(src, dest, *args, **kwargs)
            if Path(src) == source:
                (source / 'main.lua').write_text('live source changed after staging')
        with patch.object(runner.shutil, 'copytree', side_effect=mutate_after_copy), patch.object(runner.subprocess, 'check_output', side_effect=['revision\n', ' M Source/main.lua\n']), patch.object(runner.subprocess, 'run'):
            metadata = runner.prepare(project, sdk, output, 'session')
        self.assertEqual(metadata['source_sha256'], expected_hash)
        self.assertNotEqual(metadata['source_sha256'], runner.fingerprint(project))
        self.assertEqual((output / 'Source/main.lua').read_text(), 'original staged bytes')
        self.assertEqual(metadata['compiled_source_sha256'], runner.fingerprint(output, exclude_generated=False))

    def test_atomic_json_overwrites_complete_object(self):
        path = self.data / 'test.json'
        atomic_json(path, {'a': list(range(100))})
        atomic_json(path, {'b': 2})
        self.assertEqual(json.loads(path.read_text()), {'b': 2})
        self.assertEqual(list(self.data.glob('*.tmp')), [])


if __name__ == '__main__':
    unittest.main()
