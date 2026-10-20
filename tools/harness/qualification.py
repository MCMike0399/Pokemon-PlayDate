"""Deliberate protocol faults against one owned real SDK runtime.

Invoked by run.py --qualification; never launches a Simulator itself.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import time

from tools.harness.protocol import Client, ProtocolError, atomic_json


def run(client, evidence_dir, sdk):
    evidence = Path(evidence_dir) / 'qualification'
    evidence.mkdir()
    report = {'ok': True, 'tests': []}

    def test(name, action):
        try:
            detail = action()
            report['tests'].append({'name': name, 'ok': True, 'detail': detail})
        except Exception as error:
            report['ok'] = False
            report['tests'].append({'name': name, 'ok': False, 'error': str(error)})
            atomic_json(Path(evidence_dir) / 'qualification.json', report)
            raise
        atomic_json(Path(evidence_dir) / 'qualification.json', report)

    def expect_failure(action, pattern):
        try:
            action()
        except ProtocolError as error:
            assert re.search(pattern, str(error)), str(error)
            return str(error)
        raise AssertionError('fault was incorrectly accepted')

    def wait_json(filename, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        path = client.data / filename
        while time.monotonic() < deadline:
            if path.exists():
                try:
                    value = json.loads(path.read_text())
                    if predicate(value):
                        atomic_json(evidence / filename, value)
                        return value
                except ValueError:
                    pass
            time.sleep(.01)
        raise AssertionError(f'no expected {filename}')

    def recover():
        result = client.send([{'op': 'fixture', 'options': {'seed': 42}},
                              {'op': 'assert', 'path': 'stack', 'equals': 'overworld>dialog'},
                              {'op': 'assert', 'path': 'player.x', 'equals': 5},
                              {'op': 'assert', 'path': 'player.y', 'equals': 3}])
        return result['snapshot']

    def ready_fault(value, pattern):
        original = client.read('ready.json')
        try:
            if isinstance(value, str):
                # Deliberately malformed producer publication, not normal transport.
                (client.data / 'ready.json').write_text(value)
            else:
                atomic_json(client.data / 'ready.json', value)
            return expect_failure(lambda: client.ready(.1), pattern)
        finally:
            atomic_json(client.data / 'ready.json', original)

    test('malformed ready rejected', lambda: ready_fault('{broken', 'malformed'))
    test('wrong-build ready rejected', lambda: ready_fault(client.envelope(status='ready', build_id='wrong-build'), 'wrong build_id'))
    test('wrong-session ready rejected', lambda: ready_fault(client.envelope(status='ready', session_id='wrong-session'), 'wrong session_id'))

    def wrong_request():
        request = client.envelope(id='wrong-session-request', commands=['hold right'], max_frames=100)
        request['session_id'] = 'wrong-session'
        atomic_json(client.data / 'request.json', request)
        response = wait_json('rejected.json', lambda value: value.get('id') == request['id'])
        assert response['status'] == 'rejected'
        return recover()
    test('wrong-session request rejected before execution', wrong_request)

    def malformed_request():
        (client.data / 'request.json').write_text('{not-json')
        response = wait_json('rejected.json', lambda value: value.get('id') == 'invalid')
        assert response['status'] == 'rejected'
        return recover()
    test('malformed request rejected and next request recovers', malformed_request)

    test('invalid command returns failure', lambda: expect_failure(lambda: client.send(['qualification_unknown_command']), 'invalid command'))
    test('assertion failure returns failure', lambda: expect_failure(lambda: client.send([{'op': 'assert', 'path': 'zone', 'equals': 'impossible-zone'}]), 'assertion'))
    test('invalid-command and assertion recovery', recover)

    def stale_reply():
        atomic_json(client.data / 'result.json', client.envelope(id='stale-ack', status='ok', results=[], snapshot={}))
        result = client.send(['wait 4', 'snapshot'])
        assert result['id'] != 'stale-ack'
        stale = json.loads((client.evidence / 'stale-result.json').read_text())
        assert stale['id'] == 'stale-ack'
        return result['id']
    test('stale success reply never accepted', stale_reply)

    def wrong_result():
        atomic_json(client.data / 'result.json', dict(client.envelope(id='wrong-build-ack', status='ok'), build_id='wrong-build'))
        problem = expect_failure(lambda: client.send(['wait 2', 'snapshot']), 'wrong build_id')
        # The legitimate pending request may still execute; wait for its terminal
        # reply before publishing recovery commands. Never race the mailbox.
        request = json.loads((client.evidence / f'{client.sequence:05d}-request.json').read_text())
        wait_json('result.json', lambda value: value.get('id') == request['id'] and value.get('status') == 'ok')
        expect_failure(lambda: client.send(['snapshot']), 'unconfirmed pending request')
        client.recover()
        recover()
        return problem
    test('wrong-build reply rejected then runtime recovers', wrong_result)

    def replay_request():
        result = client.send(['snapshot'])
        original = json.loads((client.evidence / f'{client.sequence:05d}-request.json').read_text())
        atomic_json(client.data / 'request.json', original)
        response = wait_json('result.json', lambda value: value.get('id') == result['id'] and value.get('status') == 'error')
        assert 'duplicate request' in response.get('error', '')
        return recover()
    test('replayed request id rejected', replay_request)

    def cancellation():
        client.send([{'op': 'fixture', 'options': {'opening': False}}])
        problem = expect_failure(lambda: client.send(['record cancel-record 10000', 'hold right', 'wait 10000'],
                                                     timeout=.12, max_frames=18000), 'cancellation acknowledged')
        cancelled = json.loads((client.evidence / f'{client.sequence:05d}-result.json').read_text())
        assert cancelled['status'] == 'cancelled'
        assert 'interrupted_snapshot' in cancelled
        count_before = len([path for path in (Path(evidence_dir) / 'frames').glob('cancel-record-*.png') if re.fullmatch(r'cancel-record-[0-9]+\.png', path.name)])
        result = client.send(['wait 5', {'op': 'assert', 'path': 'stack', 'equals': 'overworld>dialog'},
                              {'op': 'assert', 'path': 'player.x', 'equals': 5},
                              {'op': 'assert', 'path': 'player.y', 'equals': 3},
                              {'op': 'assert', 'path': 'player.settled', 'equals': True},
                              {'op': 'assert', 'path': 'story.stage', 'equals': 'pre_oak'},
                              {'op': 'assert', 'path': 'pokemon.present', 'equals': False}])
        count_after = len([path for path in (Path(evidence_dir) / 'frames').glob('cancel-record-*.png') if re.fullmatch(r'cancel-record-[0-9]+\.png', path.name)])
        assert count_before == count_after, 'recording continued after cancellation'
        return {'error': problem, 'cancelled_frames': count_after, 'snapshot': result['snapshot']}
    test('host timeout cancels movement/input/recording and resets session', cancellation)

    def runtime_timeout():
        problem = expect_failure(lambda: client.send(['hold right', 'wait 100'], timeout=5, max_frames=3), 'runtime timeout')
        snapshot = client.send(['snapshot'])['snapshot']
        assert snapshot['stack'] == 'overworld>dialog' and snapshot['player']['settled']
        return problem
    test('runtime frame timeout resets and recovers', runtime_timeout)

    def competing_client():
        return expect_failure(lambda: Client(client.data, client.identity['build_id'], client.identity['session_id'], evidence / 'intruder'), 'already has an owner')
    test('second live-session client cannot own mailbox', competing_client)

    def competing_runner():
        output = evidence / 'forbidden-second-run'
        runner = Path(__file__).with_name('run.py')
        process = subprocess.run([sys.executable, str(runner), '--sdk', str(sdk), '--output', str(output), 'snapshot'],
                                 text=True, capture_output=True, timeout=5)
        assert process.returncode != 0 and 'already has an owner' in process.stderr, process.stderr
        assert not output.exists(), 'competing runner staged before ownership'
        return {'exit': process.returncode, 'stderr': process.stderr.strip()}
    test('second actual runner process rejected before build/launch', competing_runner)
    from tools.harness import integer_qualification
    integer_report = integer_qualification.run(client, evidence_dir, sdk)
    report['tests'].extend(integer_report['tests'])
    report['ok'] = report['ok'] and integer_report['ok']
    report['passed'] = len(report['tests'])
    return report
