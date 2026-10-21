"""Versioned, exclusively owned Simulator mailbox. No Simulator dependencies."""
import fcntl
import json
import math
import os
from pathlib import Path
import time
import uuid

PROTOCOL = 1


class ProtocolError(RuntimeError):
    pass


INT32_TAG = '__harness_int32_v1'
INT32_RESERVED_PREFIX = '__harness_int32'
INT32_MIN, INT32_MAX = -(1 << 31), (1 << 31) - 1
EXACT_SMALL_INTEGER_LIMIT = 1 << 24


def encode_wire_values(value):
    """Protocol-v1 value extension: preserve native int32 through SDK float32 JSON.

    The tag is generated only here. Caller-supplied reserved objects are rejected
    rather than interpreted as an escape hatch. Regular strings are untouched.
    """
    if value is None or type(value) in (bool, str):
        return value
    if type(value) is int:
        if not INT32_MIN <= value <= INT32_MAX:
            raise ProtocolError('integer outside native signed-int32 bounds')
        if value <= -EXACT_SMALL_INTEGER_LIMIT or value >= EXACT_SMALL_INTEGER_LIMIT:
            return {INT32_TAG: str(value)}
        return value
    if type(value) is float:
        if not math.isfinite(value):
            raise ProtocolError('nonfinite numeric command value')
        if value <= -EXACT_SMALL_INTEGER_LIMIT or value >= EXACT_SMALL_INTEGER_LIMIT:
            raise ProtocolError('large floating command value is not a native int32')
        return value
    if type(value) in (list, tuple):
        return [encode_wire_values(item) for item in value]
    if type(value) is dict:
        for key in value:
            if type(key) is not str:
                raise ProtocolError('command object keys must be strings')
            if key.startswith(INT32_RESERVED_PREFIX):
                raise ProtocolError('reserved harness integer tag collision')
        return {key: encode_wire_values(item) for key, item in value.items()}
    raise ProtocolError('unsupported command value type: ' + type(value).__name__)


def encode_commands(commands):
    if type(commands) not in (list, tuple):
        raise ProtocolError('commands must be an array')
    # Fixture seeds are integers, not numeric-looking floats/strings/bools. The
    # runtime additionally validates tagged values and exact-small JSON numbers.
    for command in commands:
        if type(command) is not dict:
            continue
        if command.get('op') == 'fixture':
            options = command.get('options', {})
            if type(options) is dict and 'seed' in options and type(options['seed']) is not int:
                raise ProtocolError('fixture seed requires a native Python integer')
        if command.get('op') == 'seed':
            args = command.get('args', [])
            if type(args) in (list, tuple) and args and type(args[0]) not in (str, int):
                raise ProtocolError('seed argument requires an integer or canonical integer text')
    return encode_wire_values(commands)


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    with temporary.open('w', encoding='utf-8') as stream:
        # SDK JSON's \u escape path can emit non-UTF8 single bytes (e.g. E9).
        # Publish literal UTF8 so accented production text survives exactly.
        json.dump(value, stream, sort_keys=True, ensure_ascii=False)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


class OwnerLock:
    def __init__(self, path):
        self.path = Path(path)
        self.stream = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.stream = self.path.open('a+')
        try:
            fcntl.flock(self.stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            self.stream.close()
            raise ProtocolError('run already has an owner') from error
        self.stream.seek(0)
        self.stream.truncate()
        json.dump({'pid': os.getpid()}, self.stream)
        self.stream.flush()
        return self

    def __exit__(self, *args):
        fcntl.flock(self.stream, fcntl.LOCK_UN)
        self.stream.close()


class Client:
    def __init__(self, data_dir, build_id, session_id, evidence_dir, owner=None):
        self.data = Path(data_dir)
        self._owns_lock = owner is None
        self.owner = owner or OwnerLock(self.data / 'owner.lock')
        if self._owns_lock:
            self.owner.__enter__()
        if (self.owner.path.resolve() != (self.data / 'owner.lock').resolve()
                or self.owner.stream is None or self.owner.stream.closed):
            raise ProtocolError('client requires the live owner lock for this Data directory')
        self.evidence = Path(evidence_dir)
        self.identity = {'protocol': PROTOCOL, 'build_id': build_id, 'session_id': session_id}
        self.sequence = 0
        self._pending_id = None
        self._quiescent_result = None

    def close(self):
        if self._owns_lock and self.owner.stream is not None and not self.owner.stream.closed:
            self.owner.__exit__()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def _check_owner(self):
        if self.owner.stream is None or self.owner.stream.closed:
            raise ProtocolError('client owner lock is no longer held')

    def envelope(self, **values):
        return dict(self.identity, **values)

    def read(self, filename):
        path = self.data / filename
        if not path.exists():
            return None
        try:
            result = json.loads(path.read_text(encoding='utf-8'))
        except (ValueError, OSError) as error:
            raise ProtocolError(f'malformed {filename}: {error}') from error
        if not isinstance(result, dict):
            raise ProtocolError(f'malformed {filename}: object required')
        for key, value in self.identity.items():
            if result.get(key) != value:
                raise ProtocolError(f'{filename}: wrong {key}')
        return result

    def ready(self, timeout=15):
        self._check_owner()
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            result = self.read('ready.json')
            if result:
                if result.get('status') != 'ready':
                    raise ProtocolError('runtime not ready')
                atomic_json(self.evidence / 'ready.json', result)
                return result
            time.sleep(.05)
        raise ProtocolError('ready handshake timed out')

    def send(self, commands, timeout=60, max_frames=1800):
        self._check_owner()
        if self._quiescent_result is not None:
            raise ProtocolError('runtime is quiescent; start a new session')
        if self._pending_id is not None:
            raise ProtocolError('unconfirmed pending request; recover or close this client before sending')
        wire_commands = encode_commands(commands)
        if type(max_frames) is not int or not 1 <= max_frames <= 18000:
            raise ProtocolError('max_frames requires an integer in 1..18000')
        self.sequence += 1
        request_id = f'{self.sequence:05d}-{uuid.uuid4().hex}'
        request = self.envelope(id=request_id, commands=wire_commands, max_frames=max_frames)
        atomic_json(self.evidence / f'{self.sequence:05d}-request.json', request)
        self._pending_id = request_id
        atomic_json(self.data / 'request.json', request)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            rejected = self.read('rejected.json')
            if rejected and rejected.get('id') == request_id:
                self._pending_id = None
                raise ProtocolError(f"runtime rejected request: {rejected.get('error')}")
            result = self.read('result.json')
            if result:
                if result.get('id') != request_id:
                    # Old replies are never accepted; archive for diagnosis and keep waiting.
                    atomic_json(self.evidence / 'stale-result.json', result)
                else:
                    atomic_json(self.evidence / f'{self.sequence:05d}-result.json', result)
                    if result.get('status') in ('error', 'timeout', 'cancelled'):
                        self._pending_id = None
                    if result.get('status') != 'ok':
                        raise ProtocolError(f"runtime {result.get('status')}: {result.get('error', '')}")
                    entries = result.get('results')
                    if not isinstance(entries, list) or len(entries) != len(commands):
                        raise ProtocolError('incomplete per-command results')
                    for position, entry in enumerate(entries, 1):
                        if not isinstance(entry, dict) or entry.get('command') != position or entry.get('status') != 'ok':
                            raise ProtocolError('invalid per-command result')
                    if not isinstance(result.get('snapshot'), dict):
                        raise ProtocolError('missing final snapshot')
                    self._pending_id = None
                    if result.get('quiescent') is True:
                        self._quiescent_result = result
                    return result
            time.sleep(.025)
        atomic_json(self.data / 'cancel.json', self.envelope(id=request_id))
        # Cancellation is a protocol barrier. Never issue another request until acknowledged.
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            result = self.read('result.json')
            if result and result.get('id') == request_id and result.get('status') == 'cancelled':
                atomic_json(self.evidence / f'{self.sequence:05d}-result.json', result)
                self._pending_id = None
                raise ProtocolError('command timed out; cancellation acknowledged')
            time.sleep(.025)
        raise ProtocolError('command timed out; cancellation unconfirmed; terminate owned runtime')

    def recover(self, timeout=5):
        """Confirm pending termination, then reset the actual runtime before reuse."""
        self._check_owner()
        request_id = self._pending_id
        if request_id is not None:
            atomic_json(self.data / 'cancel.json', self.envelope(id=request_id))
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                try:
                    result = self.read('result.json')
                except ProtocolError:
                    result = None  # corrupted reply may be replaced by real runtime
                if (result and result.get('id') == request_id
                        and result.get('status') in ('ok', 'error', 'timeout', 'cancelled')):
                    atomic_json(self.evidence / f'{self.sequence:05d}-recovery-terminal.json', result)
                    self._pending_id = None
                    break
                time.sleep(.025)
            if self._pending_id is not None:
                raise ProtocolError('recovery unconfirmed; terminate owned runtime and close client')
        try:
            return self.send([{'op': 'fixture', 'options': {'seed': 0}}], timeout=timeout)
        except BaseException:
            # Even a terminal failure to reset does not establish a safe
            # baseline. Keep this client blocked until another recovery/close.
            self._pending_id = self._pending_id or 'unconfirmed-recovery-reset'
            raise

    def quiesce(self):
        """Freeze the producer after its final completed frame and publications."""
        self._check_owner()
        if self._quiescent_result is not None:
            return self._quiescent_result
        result = self.send(['quiesce'], timeout=5, max_frames=180)
        if result.get('quiescent') is not True:
            raise ProtocolError('missing quiescent acknowledgement')
        return result
