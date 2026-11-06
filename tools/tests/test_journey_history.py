"""Pure owner/protocol rejection checks; no SDK, native AX or global locks."""
import copy
import hashlib
import json
import time
import subprocess
import sys
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from tools.harness import restarting, run
from tools.harness.protocol import Client, OwnerLock, ProtocolError, atomic_json


class JourneyHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.helper = self.root / 'helper'
        self.helper.write_bytes(b'never executable')
        self.args = SimpleNamespace(history_helper=self.helper,
            history_helper_sha256=hashlib.sha256(self.helper.read_bytes()).hexdigest())
        self.result = dict(id='request', tick=12, status='ok', history_paused=True,
            snapshot=dict(root='overworld', overworld='explore',
                          player=dict(settled=True, moving=False, isJumping=False, pendingEdgeDoor=False)))
        self.pause = dict(id='request', tick=12)

    def test_explicit_pin_and_journey_required(self):
        self.assertFalse(restarting.history_options(SimpleNamespace()))
        self.assertTrue(restarting.history_options(self.args, {'processes': [{'journey': {'name': 'midgame-natural'}}]}))
        for change in ({'history_helper_sha256': None}, {'history_helper_sha256': '0'*64}):
            with self.subTest(change=change), self.assertRaises(ProtocolError):
                restarting.history_options(SimpleNamespace(**(vars(self.args) | change)))
        for scenario in ({'commands': []}, {'processes': [{'requests': [[]]}]}):
            with self.subTest(scenario=scenario), self.assertRaises(ProtocolError):
                restarting.history_options(self.args, scenario)

    def test_pause_rejects_stale_half_actions_and_warps(self):
        restarting.validate_journey_pause(self.pause, self.result)
        for pause in (None, self.pause | {'id': 'old'}, self.pause | {'tick': 11}):
            with self.subTest(pause=pause), self.assertRaises(ProtocolError):
                restarting.validate_journey_pause(pause, self.result)
        for key, value in [('settled', False), ('moving', True), ('isJumping', True), ('pendingEdgeDoor', True)]:
            result = copy.deepcopy(self.result)
            result['snapshot']['player'][key] = value
            with self.subTest(key=key), self.assertRaises(ProtocolError):
                restarting.validate_journey_pause(self.pause, result)

    def test_ready_title_can_clear_before_continue_but_not_during_preparation(self):
        result = copy.deepcopy(self.result)
        result['snapshot'].update(root='title', stack='title',
                                  title={'phase': 'menu', 'menu': {'active': True}},
                                  player={'present': False})
        restarting.validate_journey_pause(self.pause, result)
        invalid = copy.deepcopy(result)
        invalid['snapshot']['player'] = {'present': True}
        with self.assertRaises(ProtocolError):
            restarting.validate_journey_pause(self.pause, invalid)
        for change in ({'phase': 'preparing', 'menu': {'active': True}},
                       {'phase': 'menu', 'menu': {'active': False}},
                       {'phase': 'confirm', 'menu': {'active': True}}):
            invalid = copy.deepcopy(result)
            invalid['snapshot']['title'] = change
            with self.subTest(title=change), self.assertRaises(ProtocolError):
                restarting.validate_journey_pause(self.pause, invalid)
        result['snapshot']['stack'] = 'title/options'
        with self.assertRaises(ProtocolError):
            restarting.validate_journey_pause(self.pause, result)
        for key, value in [('root', 'pause'), ('overworld', 'doorWarp')]:
            result = copy.deepcopy(self.result)
            result['snapshot'][key] = value
            with self.subTest(key=key), self.assertRaises(ProtocolError):
                restarting.validate_journey_pause(self.pause, result)

    def history(self):
        client = Mock()
        client.read.return_value = self.pause
        client.data = self.root
        history = restarting.JourneyHistory(self.args, {}, self.root, self.root, Mock(), client)
        history.check = Mock(return_value=restarting.HISTORY_TRIGGER)
        return history

    def test_clear_failure_never_acknowledges_or_replays(self):
        history = self.history()
        history.invoke = Mock(side_effect=ProtocolError('refusal'))
        with self.assertRaisesRegex(ProtocolError, 'refusal'):
            history.completed(self.result, 100)
        self.assertTrue(history.failed)
        self.assertEqual(history.invoke.call_count, 1)
        with self.assertRaisesRegex(ProtocolError, 'without replay'):
            history.before_send()
        self.assertFalse((self.root / 'journey-history-ack.json').exists())

    def test_first_clear_precedes_open_log_inspection(self):
        history = self.history()
        history.invoke = Mock()
        history.completed(self.result, 100)
        self.assertEqual([call.args[0] for call in history.invoke.call_args_list],
                         ['inspect', 'show-log', 'clear', 'inspect'])
        self.assertEqual(history.clears, 1)
        self.assertFalse((self.root / 'journey-history-ack.json').exists())

    def test_bounds_and_safe_pause_below_trigger(self):
        history = self.history()
        history.invoke = Mock()
        history.clears = restarting.HISTORY_MAX_CLEARS
        with self.assertRaisesRegex(ProtocolError, 'Clear bound'):
            history.completed(self.result, 100)
        history.invoke.assert_not_called()
        history = self.history()
        history.clears = 1
        history.check.return_value = restarting.HISTORY_TRIGGER - 1
        history.invoke = Mock()
        history.completed(self.result, 100)
        history.invoke.assert_not_called()
        self.assertEqual(history.pause, self.pause)
        self.assertFalse((self.root / 'journey-history-ack.json').exists())
        history.before_send()
        self.assertTrue((self.root / 'journey-history-ack.json').is_file())
        self.assertIsNone(history.pause)

    def test_history_timeout_does_not_publish_cancel_or_reset(self):
        owner = Mock(path=self.root / 'owner.lock', stream=Mock(closed=False))
        client = Client(self.root, 'build', 'session', self.root, owner=owner)
        client.history = Mock()
        with self.assertRaisesRegex(ProtocolError, 'without reset or replay'):
            client.send(['gamestate'], timeout=0)
        self.assertTrue(client.history.failed)
        self.assertFalse((self.root / 'cancel.json').exists())
        with self.assertRaisesRegex(ProtocolError, 'cannot recover/reset'):
            client.recover()

    def test_guard_failure_during_helper_kills_only_helper_without_replay(self):
        history = self.history()
        history.check.side_effect = [123, ProtocolError('1 GiB')]
        child = Mock()
        child.poll.return_value = None
        child.returncode = -9
        child.communicate.return_value = ('', '')
        (self.root / 'build.json').write_text('{}')
        (self.root / 'process.json').write_text('{}')
        with patch.object(restarting.subprocess, 'Popen', return_value=child) as launch, patch.object(restarting, 'host_footprint', return_value=124):
            with self.assertRaisesRegex(ProtocolError, '1 GiB'):
                history.invoke('clear', 100)
        self.assertTrue(history.failed)
        child.kill.assert_called_once()
        launch.assert_called_once()
        self.assertFalse((self.root / 'journey-history-ack.json').exists())

    def test_show_log_does_not_wait_while_profiler_materializes_history(self):
        history = self.history()
        history.check = Mock(return_value=123)
        child = Mock()
        child.poll.return_value = 0
        child.returncode = 0
        child.communicate.return_value = ('{"malloc_log_open_requested":true,"pid":42}', '')
        history.process.pid = 42
        (self.root / 'build.json').write_text('{}')
        (self.root / 'process.json').write_text('{}')
        with patch.object(restarting.subprocess, 'Popen', return_value=child), patch.object(restarting, 'host_footprint', return_value=123), patch.object(restarting.time, 'sleep') as sleep:
            history.invoke('show-log', 100)
        self.assertEqual(sleep.call_count, 0)

    def test_lock_mode_changes_only_for_opt_in(self):
        for enabled in (False, True):
            with patch('tools.harness.protocol.fcntl.flock') as bsd, patch('tools.harness.protocol.fcntl.lockf') as posix:
                with OwnerLock(self.root / ('lock-' + str(enabled)), history=enabled) as owner:
                    self.assertIsNotNone(owner.stream)
                self.assertEqual(posix.call_count, 2 if enabled else 0)
                self.assertEqual(bsd.call_count, 0 if enabled else 2)

    def test_generation_archive_preserves_posix_fence_across_restarts(self):
        data, output = self.root / 'data', self.root / 'output'
        data.mkdir()
        output.mkdir()
        (data / 'save.json').write_text('durable save')
        probe = ('import fcntl, sys\n'
                 'with open(sys.argv[1], "a+") as stream:\n'
                 ' try: fcntl.lockf(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)\n'
                 ' except BlockingIOError: sys.exit(0)\n'
                 ' sys.exit(1)\n')
        with OwnerLock(data / 'owner.lock', history=True) as owner:
            for generation in (1, 2):
                evidence = output / str(generation)
                evidence.mkdir()
                restarting.archive_generation(data, output, evidence, 0)
                self.assertFalse((evidence / 'runtime-data/owner.lock').exists())
                self.assertEqual((evidence / 'runtime-data/save.json').read_text(), 'durable save')
                self.assertFalse(owner.stream.closed)
                result = subprocess.run([sys.executable, '-c', probe, str(owner.path)],
                                        capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr.decode())
        result = subprocess.run([sys.executable, '-c', probe, str(data / 'owner.lock')],
                                capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 1, result.stderr.decode())

    def startup_history(self):
        owner = OwnerLock(self.root / 'owner.lock', history=True)
        owner.__enter__()
        self.addCleanup(owner.__exit__)
        client = Client(self.root, 'actual-build', 'session', self.root, owner=owner)
        startup = client.envelope(id='startup-' + 'a'*32, generation=2, history_startup_version=1)
        pause = dict(startup, tick=0, status='startup', startup_stage='title-preparing',
            root='title', stack='title', title_phase='preparing', player_present=False,
            injected_input=False, recording=False)
        atomic_json(self.root / 'journey-history-pause.json', pause)
        history = restarting.JourneyHistory(self.args, {}, self.root, self.root, Mock(), client, startup)
        history.check = Mock(return_value=123)
        history.invoke = Mock()
        client.history = history
        return client, history, pause

    def test_startup_clear_uses_same_budget_and_exact_ack_without_ready_claim(self):
        client, history, pause = self.startup_history()
        history.startup_poll(time.monotonic()+1)
        self.assertEqual([call.args[0] for call in history.invoke.call_args_list],
                         ['inspect', 'show-log', 'clear', 'inspect'])
        self.assertEqual(history.clears, 1)
        ack = json.loads((self.root / 'journey-history-ack.json').read_text())
        self.assertEqual(ack, {key: pause[key] for key in (*client.identity, 'id', 'tick',
            'generation', 'startup_stage', 'history_startup_version')})
        self.assertFalse((self.root / 'ready.json').exists())
        history.startup_poll(time.monotonic()+1)
        self.assertEqual(history.invoke.call_count, 4)
        # Later ready-title/explore boundaries share the count and soft trigger.
        atomic_json(self.root / 'journey-history-pause.json', client.envelope(**self.pause))
        history.completed(self.result, time.monotonic()+1)
        self.assertEqual(history.invoke.call_count, 4)

    def test_startup_wrong_identity_stage_or_generation_poison_without_ack(self):
        client, history, pause = self.startup_history()
        for change in ({'id': 'startup-'+'b'*32}, {'generation': 1}, {'history_startup_version': 2},
                       {'build_id': 'foreign'}, {'startup_stage': 'menu'}, {'tick': 1},
                       {'stack': 'title>options'}, {'player_present': True}, {'injected_input': True},
                       {'recording': True}, {'title_phase': 'menu'}):
            history.failed = False
            atomic_json(self.root / 'journey-history-pause.json', dict(pause, **change))
            with self.subTest(change=change), self.assertRaises(ProtocolError):
                history.startup_poll(time.monotonic()+1)
            self.assertTrue(history.failed)
            self.assertFalse((self.root / 'journey-history-ack.json').exists())
        history.invoke.assert_not_called()

    def test_startup_helper_failure_or_deadline_never_acknowledges_or_replays(self):
        client, history, pause = self.startup_history()
        history.invoke.side_effect = ProtocolError('helper deadline')
        with self.assertRaises(ProtocolError):
            client.ready(.1)
        self.assertTrue(history.failed)
        self.assertFalse((self.root / 'journey-history-ack.json').exists())
        with self.assertRaises(ProtocolError):
            history.startup_poll(time.monotonic()+1)
        self.assertEqual(history.invoke.call_count, 1)

    def test_startup_caps_refuse_and_ready_timeout_poisons(self):
        client, history, pause = self.startup_history()
        history.clears = restarting.HISTORY_MAX_CLEARS
        with self.assertRaises(ProtocolError):
            client.ready(.1)
        history.invoke.assert_not_called()
        self.assertFalse((self.root / 'journey-history-ack.json').exists())
        history.failed = False
        (self.root / 'journey-history-pause.json').unlink()
        with self.assertRaisesRegex(ProtocolError, 'ready handshake timed out'):
            client.ready(.001)
        self.assertTrue(history.failed)

    def test_ready_loop_services_startup_then_requires_genuine_ready(self):
        client, history, pause = self.startup_history()
        def producer_delay(_):
            self.assertTrue((self.root / 'journey-history-ack.json').exists())
            (self.root / 'journey-history-pause.json').unlink()
            (self.root / 'journey-history-ack.json').unlink()
            atomic_json(self.root / 'ready.json', client.envelope(status='ready', tick=1))
        with patch('tools.harness.protocol.time.sleep', side_effect=producer_delay):
            self.assertEqual(client.ready(.5)['tick'], 1)
        self.assertEqual(history.clears, 1)

    def test_ready_without_startup_barrier_and_runtime_failure_refuse(self):
        client, history, pause = self.startup_history()
        (self.root / 'journey-history-pause.json').unlink()
        atomic_json(self.root / 'ready.json', client.envelope(status='ready', tick=1))
        with self.assertRaisesRegex(ProtocolError, 'without startup'):
            client.ready(.1)
        self.assertTrue(history.failed)
        self.assertFalse((self.root / 'journey-history-ack.json').exists())

    def test_startup_stale_ack_and_replayed_publication_refuse(self):
        client, history, pause = self.startup_history()
        ack_path = self.root / 'journey-history-ack.json'
        atomic_json(ack_path, client.envelope(id='stale', tick=0))
        with self.assertRaisesRegex(ProtocolError, 'already exists'):
            history.startup_poll(time.monotonic()+1)
        history.invoke.assert_not_called()
        self.assertEqual(json.loads(ack_path.read_text())['id'], 'stale')
        ack_path.unlink(); history.failed = False
        history.startup_poll(time.monotonic()+1)
        (self.root / 'journey-history-pause.json').unlink(); ack_path.unlink()
        history.startup_poll(time.monotonic()+1)
        atomic_json(self.root / 'journey-history-pause.json', pause)
        with self.assertRaisesRegex(ProtocolError, 'changed after acknowledgement'):
            history.startup_poll(time.monotonic()+1)
        self.assertEqual(history.invoke.call_count, 4)
        self.assertFalse(ack_path.exists())

    def test_startup_call_cap_and_fatal_transport_stop_without_ack(self):
        client, history, pause = self.startup_history()
        history.invoke = restarting.JourneyHistory.invoke.__get__(history)
        history.calls = restarting.HISTORY_MAX_CALLS
        with self.assertRaisesRegex(ProtocolError, 'helper bound'):
            history.startup_poll(time.monotonic()+1)
        self.assertTrue(history.failed)
        self.assertFalse((self.root / 'journey-history-ack.json').exists())
        history.failed = False
        history.check = restarting.JourneyHistory.check.__get__(history)
        history.process.poll.return_value = None
        atomic_json(self.root / 'runtime-error.json', client.envelope(error='startup guard failure'))
        with patch.object(restarting, 'host_footprint', return_value=123), \
             patch.object(restarting.shutil, 'disk_usage', return_value=SimpleNamespace(free=32*1024**3)):
            with self.assertRaisesRegex(ProtocolError, 'runtime error: startup guard failure'):
                history.startup_poll(time.monotonic()+1)
        self.assertTrue(history.failed)
        self.assertFalse((self.root / 'journey-history-ack.json').exists())

    def test_pre_ready_process_record_is_real_launching_generation(self):
        # Exercise the runner's actual launch-to-ready seam, never a Simulator.
        output, data = self.root / 'run', self.root / 'data'
        output.mkdir(); data.mkdir()
        simulator = self.root / 'simulator'; simulator.write_bytes(b'host seam only')
        metadata = dict(build_id='actual-build', session_id='session', simulator=str(simulator),
            bundle='unused', history_clear=True, history_startup_version=1)
        args = SimpleNamespace(**vars(self.args), ready_timeout=.1)
        process = Mock(pid=42)
        process.poll.return_value = None
        runner = Mock()
        owner = OwnerLock(data / 'owner.lock', history=True); owner.__enter__()
        self.addCleanup(owner.__exit__)
        def ready(client, timeout):
            record = json.loads((output / 'processes/0001/process.json').read_text())
            current = json.loads((output / 'run.json').read_text())['processes'][-1]
            request = client.read('journey-startup-request.json')
            self.assertEqual(record, current)
            self.assertEqual(record['status'], 'launching')
            self.assertIs(record['fresh_ready'], False)
            self.assertEqual((record['pid'], record['start_sec'], record['start_usec'], record['owner_pid']),
                             (42, 10, 20, 99))
            self.assertEqual(record['simulator'], str(simulator))
            self.assertEqual(record['startup_id'], request['id'])
            self.assertEqual(record['generation'], request['generation'])
            raise ProtocolError('stop at pre-ready seam')
        with patch.object(restarting.subprocess, 'Popen', return_value=process), \
             patch.object(restarting, 'native_process_identity', return_value=dict(start_sec=10,start_usec=20,owner_pid=99)), \
             patch.object(restarting, 'SIMULATOR_SHA256', hashlib.sha256(simulator.read_bytes()).hexdigest()), \
             patch.object(restarting.shutil, 'disk_usage', return_value=SimpleNamespace(free=32*1024**3)), \
             patch.object(restarting, 'stop_owned', return_value=-15), \
             patch.object(Client, 'ready', ready):
            self.assertEqual(restarting.run(args, {'processes': [{'requests': [['snapshot']]}]},
                metadata, output, data, owner, runner), 1)
        self.assertFalse((data / 'journey-history-ack.json').exists())
        self.assertEqual(json.loads((output / 'processes/0001/process.json').read_text())['status'], 'failed-exited')

    def test_staging_freeze_survives_capture_overlay_and_inventory_is_actual(self):
        project, sdk, output = (self.root / name for name in ('project', 'sdk', 'output'))
        (project / 'Source/dev').mkdir(parents=True)
        sdk.mkdir()
        output.mkdir()
        original = (run.PROJECT / 'Source/main.lua').read_bytes()
        (project / 'Source/main.lua').write_bytes(original)
        (project / 'Source/pdxinfo').write_text('bundleID=original\n')
        (sdk / 'VERSION.txt').write_text('3.1.2')
        def compiler(*args, **kwargs):
            (output / 'Harness.pdx').mkdir()
            (output / 'Harness.pdx/pdxinfo').write_bytes(b'actual compiled payload')
        with patch.object(run.subprocess, 'check_output', side_effect=['a'*40, '']), patch.object(run.subprocess, 'run', side_effect=compiler):
            metadata = run.prepare(project, sdk, output, 'b'*32, recent_interval=60, journey=True, history=True)
        staged = (output / 'Source/main.lua').read_text()
        self.assertIn('harness.historyWaiting()', staged)
        self.assertIn('import "dev/capture_policy"', staged)
        self.assertEqual((project / 'Source/main.lua').read_bytes(), original)
        self.assertEqual(metadata['history_identity'], 'JOURNEY')
        self.assertEqual(metadata['pdx_files'], {'pdxinfo': hashlib.sha256(b'actual compiled payload').hexdigest()})
        self.assertIn('history_clear = true', (output / 'Source/dev/harness_build.lua').read_text())


if __name__ == '__main__':
    unittest.main()
