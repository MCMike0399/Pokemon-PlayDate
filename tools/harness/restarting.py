"""Owned multi-process jobs. No Simulator or filesystem work at import time."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

from tools.harness.protocol import Client, ProtocolError, atomic_json

# Only these protocol publications are removed between stopped processes.
TRANSIENT = frozenset({'ready.json', 'heartbeat.json', 'request.json', 'result.json',
                       'rejected.json', 'cancel.json', 'runtime-error.json', 'captures-final.json'})


class UnconfirmedExit(ProtocolError):
    """Keep private Data when its owned producer cannot be confirmed dead."""


def validate(scenario, qualification=False):
    if 'processes' not in scenario:
        return
    if qualification or any(key in scenario for key in ('commands', 'requests', 'journey', 'outputs')):
        raise ProtocolError('processes cannot mix with commands/requests/journey/outputs/qualification')
    groups = scenario['processes']
    if not isinstance(groups, list) or not 2 <= len(groups) <= 8:
        raise ProtocolError('processes requires 2..8 process groups')
    for index, group in enumerate(groups):
        if not isinstance(group, dict) or set(group) - {'restart', 'requests', 'outputs'}:
            raise ProtocolError('invalid process group fields')
        if (index == 0 and 'restart' in group) or (index > 0 and group.get('restart') is not True):
            raise ProtocolError('each later process group requires restart:true; first cannot restart')
        requests = group.get('requests')
        if not isinstance(requests, list) or not requests or any(not isinstance(value, list) or not value for value in requests):
            raise ProtocolError('process requests requires nonempty command arrays')
        outputs = group.get('outputs', [])
        if not isinstance(outputs, list):
            raise ProtocolError('process outputs requires an array')
        for value in outputs:
            if not isinstance(value, str) or not value or Path(value).is_absolute() or '..' in Path(value).parts:
                raise ProtocolError('invalid process output path')


def check_owner(owner, data):
    if owner.path.resolve() != (data / 'owner.lock').resolve() or owner.stream is None or owner.stream.closed:
        raise ProtocolError('restart requires the same live private owner lock')


def stop_owned(process, owner, data):
    """Only a Popen handle created by this job is signalled; confirm exit."""
    check_owner(owner, data)
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired as error:
                raise UnconfirmedExit("owned Simulator exit unconfirmed; private Data retained") from error
    if process.poll() is None:
        raise UnconfirmedExit('owned Simulator exit unconfirmed; private Data retained')
    return process.returncode


def clear_handshake(data, owner):
    check_owner(owner, data)
    for name in sorted(TRANSIENT):
        for path in (data / name, data / (name + '.tmp')):
            # Refuse directory/symlink substitution rather than traverse it.
            if path.is_symlink() or (path.exists() and not path.is_file()):
                raise ProtocolError('invalid transient protocol path: ' + path.name)
            path.unlink(missing_ok=True)
    if (data / 'ready.json').exists():
        raise ProtocolError('stale ready handshake remains')


def durable_hashes(data):
    result = {}
    for path in sorted(data.rglob('*')):
        relative = path.relative_to(data)
        if path.is_symlink():
            raise ProtocolError('private Data contains symlink: ' + relative.as_posix())
        if relative.parts[0] == 'recent' or relative.as_posix() in {'owner.lock', 'trace.jsonl', 'captures.jsonl'}:
            continue
        if relative.as_posix() in TRANSIENT or relative.as_posix() in {name + '.tmp' for name in TRANSIENT}:
            continue
        if path.is_file():
            result[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def archive_generation(data, output, evidence, trace_start):
    # Called only after confirmed process exit; producers cannot overwrite copies.
    shutil.copytree(data, evidence / 'runtime-data')
    trace = data / 'trace.jsonl'
    content = trace.read_bytes() if trace.exists() else b''
    if trace_start > len(content):
        raise ProtocolError('runtime trace was truncated across restart')
    (evidence / 'trace.jsonl').write_bytes(content[trace_start:])
    if (output / 'frames').exists():
        shutil.move(str(output / 'frames'), evidence / 'frames')
    (output / 'frames').mkdir()
    for name in ('captures.json', 'catalog.json', 'artifact-finalization.json'):
        path = output / name
        if path.exists():
            shutil.move(str(path), evidence / name)
    return len(content)


def run(args, scenario, metadata, output, data, owner, runner):
    """Run approved groups under the caller's uninterrupted global/private locks."""
    processes = []
    process = client = evidence = None
    sequence = trace_start = 0
    finalized = archived = False
    prior_pid = None
    expected_durable = None

    def publish():
        atomic_json(output / 'run.json', dict(metadata, processes=processes))

    try:
        for generation, group in enumerate(scenario['processes'], 1):
            check_owner(owner, data)
            evidence = output / 'processes' / f'{generation:04d}'
            evidence.mkdir(parents=True, exist_ok=False)
            finalized = archived = False
            client = None
            # Old process was quiesced, stopped, confirmed dead and archived
            # before reaching this boundary. No saves or trace are removed.
            before = durable_hashes(data)
            clear_handshake(data, owner)
            if durable_hashes(data) != before:
                raise ProtocolError('restart cleanup changed durable files')
            expected_durable = before
            record = {'generation': generation, 'status': 'launching', 'evidence': str(evidence.relative_to(output)),
                      'first_sequence': sequence + 1, 'durable_before': before,
                      'previous_pid': prior_pid, 'previous_exit_confirmed': generation == 1 or processes[-1]['status'] == 'exited'}
            processes.append(record); publish()
            with (evidence / 'simulator.log').open('w') as log:
                process = subprocess.Popen([metadata['simulator'], metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
                record['pid'] = process.pid
                if process.pid == prior_pid:
                    raise ProtocolError('restart did not produce a new PID')
                record['launched_ns'] = time.time_ns(); publish()
                client = Client(data, metadata['build_id'], metadata['session_id'], evidence, owner=owner)
                client.sequence = sequence
                # No prior ready exists, and the old publisher is confirmed dead.
                ready = client.ready(args.ready_timeout)
                if process.poll() is not None:
                    raise ProtocolError('Simulator exited during fresh ready handshake')
                if generation > 1 and durable_hashes(data) != expected_durable:
                    raise ProtocolError('boot changed durable files across restart')
                record.update(status='ready', fresh_ready=True, ready_tick=ready.get('tick'), ready_observed_ns=time.time_ns())
                atomic_json(evidence / 'process.json', record); publish()
                for commands in group['requests']:
                    result = client.send(commands, args.timeout, args.max_frames)
                    runner.verify_request_outputs(commands, result, output)
                for path in group.get('outputs', []):
                    runner.verify_png(output / 'frames' / path)
                runner.finalize_captures(client, data, output)
                finalized = True
                sequence = client.sequence
                record['last_sequence'] = sequence
                record['status'] = 'quiescent'; publish()
                record['returncode'] = stop_owned(process, owner, data)
                record['status'] = 'exited'
                prior_pid = process.pid
                process = None
                trace_start = archive_generation(data, output, evidence, trace_start)
                archived = True
                record['durable_after'] = durable_hashes(data)
                atomic_json(evidence / 'process.json', record); publish()
        atomic_json(output / 'outcome.json', {'ok': True, 'session_id': metadata['session_id'],
                                             'process_generations': len(processes)})
        print(output)
        return 0
    except BaseException as error:
        if processes:
            processes[-1].update(status='failed', error=str(error))
            atomic_json(evidence / 'process.json', processes[-1])
            publish()
        # Never reset/recover a failed command into success. A poisoned pending
        # request cannot safely quiesce; stop its owned producer and archive it.
        if client is not None and not finalized and client._pending_id is None:
            try:
                runner.finalize_captures(client, data, output)
                finalized = True
            except BaseException as capture_error:
                atomic_json(output / 'artifact-finalization.json', {'quiescent': False, 'error': str(capture_error)})
        atomic_json(output / 'outcome.json', {'ok': False, 'session_id': metadata['session_id'],
                                             'error': str(error), 'process_generations': len(processes),
                                             'captures_finalized': finalized})
        return 1
    finally:
        if process is not None:
            try:
                returncode = stop_owned(process, owner, data)
                if processes:
                    processes[-1].update(status='failed-exited', returncode=returncode)
            except UnconfirmedExit as error:
                if processes:
                    processes[-1].update(status='exit-unconfirmed', error=str(error))
                atomic_json(output / 'outcome.json', {'ok':False, 'error':str(error),
                    'session_id':metadata['session_id'], 'data_retained':str(data)})
                raise
            finally:
                if processes:
                    atomic_json(evidence / "process.json", processes[-1])
                publish()
        if evidence is not None and not archived:
            archive_generation(data, output, evidence, trace_start)
