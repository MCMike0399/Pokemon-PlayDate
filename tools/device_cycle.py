#!/usr/bin/env python3
"""Root operator's physical Playdate cycle; never builds or launches Simulator.

Usage and the safety boundary are documented in tools/device-cycle.md.
Importing this module performs no device operations.
"""
import argparse
import glob
import hashlib
import json
import math
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import time

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.harness.protocol import OwnerLock, atomic_json
from tools.harness.run import device_lock_path, fingerprint, runtime_lock_path, sdk_path, simulator_usb_preflight

SLOTS = {'adventure.a.json', 'adventure.b.json'}
IDENTITY = 'device-cycle-identity.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(directory):
    """Hash every payload, refusing links and special files, even empty dirs."""
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError(f'not a plain directory: {directory}')
    result = {}
    for path in sorted(directory.rglob('*')):
        if path.name == '.DS_Store' or path.name.startswith('._'):
            continue
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError(f'unsafe payload: {path}')
        if path.is_file():
            result[path.relative_to(directory).as_posix()] = sha(path)
    return result


def tree_hash(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def plain_path(path, boundary):
    """Reject symlink ancestors before any device read/write."""
    path.relative_to(boundary)
    for candidate in (path, *path.parents):
        if candidate.is_symlink():
            raise ValueError(f'symlink refused: {candidate}')
        if candidate == boundary:
            break
    return path


def copy_verified(source, target, expected):
    if source.is_symlink() or not source.is_file() or sha(source) != expected:
        raise ValueError(f'source changed or unsafe: {source}')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    if sha(target) != expected:
        raise ValueError(f'copy hash mismatch: {target}')


def calibration_gate(args, manifest, source):
    """A tiny measurement app is not a passed game-performance gate."""
    from tools.device.calibrate import compare
    if not args.calibration_build:
        raise ValueError('--calibration-preflight requires --calibration-build')
    metadata = json.loads(Path(args.calibration_build).read_text())
    report_path = Path(args.calibration_preflight)
    report = json.loads(report_path.read_text())
    runtime = json.loads((report_path.parent / 'run.json').read_text())
    if (metadata.get('mode') != 'calibration-compile-only'
            or set(source) != {'main.lua', 'pdxinfo', 'game/bootTrace.lua', 'calibration.lua'}
            or metadata.get('source_manifest') != source
            or metadata.get('bundle_manifest') != manifest['pdx_files']
            or not manifest['bundle_id'].startswith('com.poc.pokemon.calibration.')
            or runtime.get('malloc_pool_preflight') != 16645684
            or runtime.get('build_id') != metadata.get('build_id')):
        raise ValueError('calibration preflight does not identify this exact minimal build')
    compare(metadata, simulator=report)  # Identity/platform/completion checks.
    for phase in report['phases']:
        if (phase.get('complete') is not True or phase.get('blocks') != 8192
                or phase.get('work_count') != 65536
                or not 0 <= phase.get('heap_kib', math.inf) <= 512
                or not 0 < phase.get('max_work_slice_ms', math.inf) <= 4):
            raise ValueError('calibration safety preflight failed')
    if args.earned_save:
        raise ValueError('calibration cannot import game saves')
    return {'classification': 'synthetic calibration only', 'game_gate_passed': False,
            'build_id': metadata['build_id'], 'simulator_report': str(report_path),
            'simulator_report_sha256': sha(report_path), 'malloc_pool_mb': 16}


def smoke_gate(args, stage, pdx):
    """Recompute the Simulator evidence before acquiring any hardware ownership."""
    from tools.device import simulator_smoke as smoke
    if getattr(args, 'calibration_build', None):
        raise ValueError('smoke cannot use calibration metadata')
    build = smoke.verify(stage)
    safety_only = getattr(args, 'safety_only', False)
    if build.get('diagnostic_only') and not safety_only:
        raise ValueError('diagnostic builds cannot supply hardware admission proof')
    if pdx.resolve() != (stage / 'DeviceSmoke.pdx').resolve():
        raise ValueError('smoke candidate must be the exact retained DeviceSmoke.pdx')
    production = build['production_source_manifest']
    compiled = build['compiled_source_manifest']
    if (tree_hash(production) != build['production_source_sha256']
            or any(name.startswith('dev/') for name in production)
            or set(compiled) - set(production) != {'dev/deviceSmoke.lua'}
            or set(production) - set(compiled)
            or {name for name in production if production[name] != compiled[name]} != {'main.lua', 'pdxinfo'}
            or build.get('protocol') != 'DS1' or build.get('simulator_transport_version') != 1):
        raise ValueError('smoke overlay exceeds the exact one-module build')
    path = Path(args.simulator_smoke).expanduser().resolve()
    report = json.loads(path.read_text())
    runtime = json.loads((path.parent / 'run.json').read_text())
    allowed_status = {'simulator-smoke-passed', 'failed'} if safety_only else {'simulator-smoke-passed'}
    if (report.get('status') not in allowed_status or report.get('build') != build
            or report.get('device_gate_passed') is not False
            or any(report.get(key) for key in ('error', 'measurement_error'))
            or any(row.get('build') != build or row.get('malloc_pool_mb') != 16
                   or row.get('malloc_pool_preflight') != 16645684 for row in (runtime, report))):
        raise ValueError('matching simulator-smoke-passed report required')
    # Reuse the shared whitelist and canonical tree hash, including whitespace.
    bodies = report.get('commands')
    if (not isinstance(bodies, list) or not bodies or len(bodies) > 10000
            or any(not isinstance(body, str) or not smoke.COMMAND.fullmatch(body) for body in bodies)):
        raise ValueError('invalid frozen DS1 commands')
    for body in bodies:
        match = smoke.COMMAND.fullmatch(body)
        if (match[1] and not 1 <= int(match[1]) <= 120) or (match[2] and not 1 <= int(match[2]) <= 300):
            raise ValueError('invalid frozen DS1 command bounds')
    if (report.get('commands_sha256') != tree_hash(bodies)
            or runtime.get('commands') != bodies or runtime.get('commands_sha256') != tree_hash(bodies)):
        raise ValueError('frozen DS1 commands hash mismatch')
    factor = report.get('timing_factor')
    if type(factor) not in (int, float) or not math.isfinite(factor) or factor <= 0:
        raise ValueError('invalid Simulator timing factor')
    recomputed = smoke.measurements(path.parent / 'runtime-data', build['build_id'], factor)
    safety_limits = {'heap_peak_bytes': 9 * 1024**2, 'slice_ms': 150}
    safety_failures = [name for name, limit in safety_limits.items()
                       if recomputed['measurements'][name] is None
                       or recomputed['measurements'][name] > limit]
    safety_failures += [name for name in recomputed['budget_failures']
                        if name in {'runtime-error-or-no-frames', 'missing-title-or-Continue-live-heap'}]
    failures = safety_failures if safety_only else recomputed['budget_failures']
    if (failures
            or any(type(v) not in (int, float) or not math.isfinite(v) or v < 0
                   for v in recomputed['measurements'].values())
            or any(report.get(k) != v for k, v in recomputed.items())):
        raise ValueError('Simulator smoke measurements changed or budgets failed')
    responses = json.loads((path.parent / 'responses.json').read_text())
    raw_responses = [json.loads(line) for line in
                     (path.parent / 'runtime-data/device-smoke-replies.jsonl').read_text().splitlines()]
    if raw_responses != responses:
        raise ValueError('Simulator response archive differs from raw replies')
    if any(row.get('build') != build['build_id'] or row.get('status') == 'error' for row in responses):
        raise ValueError('invalid Simulator responses')
    seen = smoke.observations(responses)
    if (seen != report.get('observations') or not seen['title'] or not seen['continue_available']
            or seen['loaded'] <= 0 or seen['saved'] <= 0):
        raise ValueError('missing Simulator smoke observations')
    # The route starts only after a completed ready probe; every later command
    # and the final state must have a unique, contiguous completion.
    done = [row for row in responses if row.get('status') == 'done']
    if (len(done) < len(bodies) + 2
            or [row.get('seq') for row in done] != list(range(1, len(done) + 1))
            or done[-len(bodies)-2].get('value', {}).get('ready') is not True):
        raise ValueError('incomplete Simulator command transcript')
    first = done[-len(bodies)-2]['seq'] + 1
    for seq, body in enumerate(bodies + ['state'], first):
        accepted = [r for r in responses if r.get('seq') == seq and r.get('status') == 'accepted']
        if body != 'state' and (len(accepted) != 1 or accepted[0].get('value') != body.split()[0]):
            raise ValueError('Simulator command acceptance transcript mismatch')
    if not args.earned_save:
        raise ValueError('smoke requires the exact Simulator earned-save manifest')
    earned = json.loads(Path(args.earned_save).expanduser().read_text())
    prior = json.loads((path.parent / 'earned-save.json').read_text())
    if earned.get('files') != prior.get('files'):
        raise ValueError('smoke earned slots differ from Simulator input')
    return build, report, {'classification': ('hardware measurement safety only; not playability acceptance'
                                             if safety_only else 'exact private DeviceSmoke; Simulator admission only'),
                          'safety_only': safety_only, 'safety_limits': safety_limits if safety_only else None,
                          'simulator_report': str(path), 'simulator_report_sha256': sha(path),
                          'commands': bodies, 'commands_sha256': tree_hash(bodies)}


def parse_device_trace(path, build_id):
    lines = path.read_text().splitlines()
    if not lines or lines[0] != f'schema\t1\tbuild\t{build_id}\tplatform\tdevice':
        raise ValueError('device BootTrace identity/platform mismatch')
    phases, last_clock = [], 0
    for sequence, line in enumerate(lines[2:], 1):
        fields = line.split('\t')
        if len(fields) != 7 or fields[0] != str(sequence) or fields[1].startswith('error.'):
            raise ValueError('invalid/failed device BootTrace phase')
        values = [float(v) for v in fields[2:]]
        if any(not math.isfinite(v) or v < 0 for v in values) or values[0] < last_clock:
            raise ValueError('invalid device BootTrace numbers')
        last_clock = values[0]
        phases.append(dict(phase=fields[1], clock_ms=values[0], since_yield_ms=values[1],
                           phase_ms=values[2], heap_kib=values[3], peak_kib=values[4]))
    return phases


class SmokeSerial:
    """Single-flight raw transport. An uncertain write/completion is never retried."""
    def __init__(self, cycle, descriptor, build_id, deadline):
        self.cycle, self.descriptor, self.build_id, self.deadline = cycle, descriptor, build_id, deadline
        self.pending = b''
        self.sequence = 0
        self.responses = []
        self.trace = []
        self.trace_identity = False

    def read(self):
        if not self.cycle.select_serial():
            raise RuntimeError('device needs one A press; USB disappeared; no further device attempts')
        if time.monotonic() >= self.deadline:
            raise TimeoutError('DS1 completion uncertain; no command replay')
        readable, _, _ = select.select([self.descriptor], [], [], min(0.2, max(0, self.deadline - time.monotonic())))
        if not readable:
            return []
        try:
            chunk = os.read(self.descriptor, 8192)
        except BlockingIOError:
            return []
        if not chunk:
            raise RuntimeError('device needs one A press; USB reader closed; no further device attempts')
        with (self.cycle.output / 'serial.raw').open('ab') as raw:
            raw.write(chunk)
        self.pending += chunk
        rows = []
        while b'\n' in self.pending:
            line, self.pending = self.pending.split(b'\n', 1)
            if b'BOOTTRACE\t' in line:
                text = line.split(b'BOOTTRACE\t', 1)[1].decode('utf-8').rstrip('\r')
                self.trace.append(text)
                if text.startswith('schema\t'):
                    if text != f'schema\t1\tbuild\t{self.build_id}\tplatform\tdevice':
                        raise ValueError('device BootTrace identity mismatch')
                    self.trace_identity = True
                elif '\terror.' in text:
                    raise ValueError('device BootTrace guard failed')
                self.cycle.event('boottrace', line=text)
            # The device echoes host serial commands before printing replies.
            if line.strip().startswith(b'msg DS1 '):
                continue
            if b'DS1 ' not in line:
                continue
            row, _ = json.JSONDecoder().raw_decode(line.split(b'DS1 ', 1)[1].decode('utf-8'))
            if not isinstance(row, dict) or row.get('build') != self.build_id:
                raise ValueError('device DS1 build identity mismatch')
            self.responses.append(row)
            self.cycle.event('ds1-response', message=row)
            if row.get('status') == 'error' or (isinstance(row.get('value'), dict) and row['value'].get('error')):
                raise ValueError('device DS1 error: ' + str(row.get('value')))
            rows.append(row)
        if len(self.pending) > 65536:
            raise ValueError('serial line exceeds bounded buffer')
        return rows

    def command(self, body):
        if time.monotonic() >= self.deadline:
            raise TimeoutError('DS1 deadline expired; no further command sent')
        if not self.cycle.select_serial():
            raise RuntimeError('device needs one A press; USB disappeared; no further device attempts')
        self.sequence += 1
        if self.sequence > 16777215:
            raise ValueError('DS1 sequence exhausted')
        wire = f'msg DS1 {self.sequence} {body}\n'.encode('ascii')
        self.cycle.event('ds1-send', sequence=self.sequence, body=body)
        # A partial/blocked write could already have affected the device. Stop.
        if os.write(self.descriptor, wire) != len(wire):
            raise RuntimeError('DS1 write uncertain; no command replay')
        while True:
            completed = None
            for row in self.read():
                if row.get('seq') == 0 and row.get('status') == 'ready':
                    continue  # module installed does not mean ordinary game ready
                if row.get('seq') != self.sequence or row.get('status') not in {'accepted', 'done'}:
                    raise ValueError('unexpected DS1 sequence/status; no command replay')
                if row['status'] == 'done':
                    if completed is not None or not isinstance(row.get('value'), dict):
                        raise ValueError('invalid DS1 completion')
                    completed = row['value']
            if completed is not None:
                return completed


class Cycle:
    def __init__(self, args):
        self.args = args
        self.output = Path(args.output).expanduser().absolute()
        self.output.mkdir(parents=True, exist_ok=False)
        self.phase = 'initializing'
        self.sdk = None
        self.volume = Path(args.volume).absolute()
        self.serial = None
        self.ran = False
        self.smoke_build = None
        self.smoke_report = None
        self.smoke_transport = None

    def event(self, status, **fields):
        row = dict(time_ns=time.time_ns(), phase=self.phase, status=status, **fields)
        with (self.output / 'phases.jsonl').open('a') as stream:
            stream.write(json.dumps(row, sort_keys=True) + '\n')
            stream.flush()
            os.fsync(stream.fileno())

    def step(self, name):
        self.phase = name
        self.event('started')
        print(name, flush=True)

    def command(self, argv):
        self.event('command', argv=[str(value) for value in argv])
        result = subprocess.run(argv, capture_output=True, text=True, timeout=30)
        self.event('command-result', returncode=result.returncode,
                   stdout=result.stdout, stderr=result.stderr)
        result.check_returncode()

    def wait_for(self, predicate, seconds, description):
        deadline = time.monotonic() + seconds
        while not predicate():
            if time.monotonic() >= deadline:
                raise TimeoutError(description)
            time.sleep(1)
        self.event('ready', description=description)

    def select_serial(self):
        ports = sorted(glob.glob('/dev/cu.usbmodemPD*'))
        if self.args.serial:
            ports = [value for value in ports if value == self.args.serial]
        if len(ports) > 1:
            raise ValueError('multiple Playdates; specify --serial')
        if ports:
            self.serial = ports[0]
            return True
        return False

    def wait_calibration(self, deadline):
        """Verify print/msg on the minimal app; close before any pdutil call."""
        build = json.loads(Path(self.args.calibration_build).read_text())
        transport = {'print_stream_verified': False, 'message_callback_verified': False,
                     'complete_seen': False, 'build_id': build['build_id']}
        simulator_usb_preflight()
        descriptor = os.open(self.serial, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        pending = b''
        ping_after_ready = False
        completed_at = None
        try:
            os.write(descriptor, b'msg CAL1 ping\n')
            with (self.output / 'serial.raw').open('wb') as raw:
                while time.monotonic() < deadline:
                    if completed_at is not None and time.monotonic() - completed_at > 3:
                        return
                    if not self.select_serial():
                        raise RuntimeError('device needs one A press; USB disappeared; no further device attempts')
                    readable, _, _ = select.select([descriptor], [], [], 1)
                    if not readable:
                        continue
                    try:
                        chunk = os.read(descriptor, 8192)
                    except BlockingIOError:
                        continue
                    if not chunk:
                        continue
                    raw.write(chunk)
                    raw.flush()
                    pending = (pending + chunk)[-65536:]
                    while b'\n' in pending:
                        line, pending = pending.split(b'\n', 1)
                        position = line.find(b'CAL1 ')
                        if position < 0:
                            continue
                        try:
                            row, _ = json.JSONDecoder().raw_decode(line[position + 5:].decode('utf-8'))
                        except (ValueError, UnicodeError):
                            continue
                        if not isinstance(row, dict) or row.get('build_id') != build['build_id']:
                            continue
                        transport['print_stream_verified'] = True
                        self.event('serial-message', message=row)
                        if row.get('kind') == 'status':
                            transport['message_callback_verified'] = True
                        elif not ping_after_ready:
                            os.write(descriptor, b'msg CAL1 ping\n')
                            ping_after_ready = True
                        value = row.get('value')
                        if row.get('kind') == 'complete' or (isinstance(value, dict) and value.get('state') == 'complete'):
                            transport['complete_seen'] = True
                            completed_at = time.monotonic()
                        if transport['complete_seen'] and transport['message_callback_verified']:
                            return
                        if row.get('kind') == 'error':
                            transport['app_error'] = value
                            return
        finally:
            os.close(descriptor)
            atomic_json(self.output / 'serial-transport.json', transport)

    def wait_smoke(self, deadline):
        simulator_usb_preflight()
        descriptor = os.open(self.serial, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        transport = SmokeSerial(self, descriptor, self.smoke_build['build_id'], deadline)
        self.smoke_transport = transport
        try:
            # A command sent while the application imports has no callback yet.
            # Wait for this build's module announcement (or its later trace
            # header) before sending the first read-only readiness command.
            installed = False
            while not installed:
                rows = transport.read()
                installed = transport.trace_identity or any(
                    row.get('seq') == 0 and row.get('status') == 'ready' for row in rows)
            while transport.command('state').get('ready') is not True:
                time.sleep(min(0.05, max(0, deadline - time.monotonic())))
            for body in self.smoke_report['commands']:
                transport.command(body)
            transport.command('state')
        finally:
            os.close(descriptor)
            atomic_json(self.output / 'device-responses.json', transport.responses)
            (self.output / 'serial-boot-trace.tsv').write_text('\n'.join(transport.trace) + '\n')
            self.event('reader-closed')

    def report_smoke(self, bundle_id):
        """Only archived device observations can establish device measurements."""
        from tools.device.simulator_smoke import observations
        from tools.device.metrics import ordinary_frames, phase_report, phase_table_text
        archived = self.output / 'after/Data' / bundle_id
        report = {'device_gate_passed': False, 'boot_accepted': False,
                  'classification': 'device attempt; root hardware acceptance remains separate',
                  'build_id': self.smoke_build['build_id'],
                  'pdx_sha256': self.smoke_build['pdx_sha256'],
                  'commands_sha256': self.smoke_report['commands_sha256'],
                  'observations': observations(self.smoke_transport.responses if self.smoke_transport else []),
                  'failures': []}
        try:
            prior_trace = self.output / 'before/Data' / bundle_id / 'boot-trace.tsv'
            if prior_trace.exists() and sha(prior_trace) == sha(archived / 'boot-trace.tsv'):
                raise ValueError('unchanged prior BootTrace is not a new attempt')
            phases = parse_device_trace(archived / 'boot-trace.tsv', report['build_id'])
            report['phases'] = phases
            report['last_phase'] = phases[-1] if phases else None
            frames = []
            for line in (archived / 'device-smoke-frames.tsv').read_text().splitlines():
                fields = line.split('\t')
                if (len(fields) != 8 or fields[0] != report['build_id']
                        or fields[3] not in {'yield', 'return'} or fields[6] not in {'0', '1'}):
                    raise ValueError('invalid device active frame metrics')
                elapsed, heap, clock = [float(fields[i]) for i in (4, 5, 7)]
                if any(not math.isfinite(v) or v < 0 for v in (elapsed, heap, clock)):
                    raise ValueError('invalid device active frame numbers')
                if int(fields[1]) < 1 or int(fields[2]) < 1:
                    raise ValueError('invalid device update/segment identity')
                frames.append({'update': int(fields[1]), 'segment': int(fields[2]),
                               'kind': fields[3], 'start_ms': clock, 'active_ms': elapsed,
                               'heap_kib': heap, 'loading': fields[6] == '1'})
            def span(begin, end):
                start, values = None, []
                for row in phases:
                    if row['phase'] == begin:
                        start = row['clock_ms']
                    elif row['phase'] == end and start is not None:
                        values.append(row['clock_ms'] - start)
                        start = None
                return max(values) if values else None
            live = [row['heap_kib'] * 1024 for row in phases
                    if row['phase'] in {'title.live.after_gc', 'Continue.live.after_gc'}]
            measured = {'heap_live_bytes': max(live) if live else None,
                        'heap_peak_bytes': max([r['peak_kib'] * 1024 for r in phases]
                                               + [f['heap_kib'] * 1024 for f in frames], default=None),
                        'map_load_ms': span('door.map.begin', 'door.map.end'),
                        'battle_start_ms': span('battle.start.begin', 'battle.start.end'),
                        'frame_ms': max((f['active_ms'] for f in ordinary_frames(frames, phases)), default=None),
                        'slice_ms': max([f['active_ms'] for f in frames]
                                        + [r['since_yield_ms'] for r in phases], default=None)}
            limits = dict(heap_live_bytes=6 * 1024**2, heap_peak_bytes=9 * 1024**2,
                          map_load_ms=1500, battle_start_ms=1000, frame_ms=50, slice_ms=1000)
            report.update(measurements=measured, limits=limits, phases=phases, frames=frames)
            # Ordinary maximum is diagnostic; walking acceptance uses scoped p95.
            report['failures'] += [k for k, v in measured.items()
                                   if k not in {'frame_ms', 'slice_ms'} and (v is None or v > limits[k])]
            report.update(phase_report(phases, frames, self.smoke_transport.responses
                                       if self.smoke_transport else []))
            report['failures'] += report['phase_failures']
            report['diagnostics'] = dict(
                raw_frame_max_ms=max((f['active_ms'] for f in frames), default=None),
                ordinary_frame_max_ms=measured['frame_ms'],
                raw_slice_ms=measured['slice_ms'],
                note='frame_ms and raw slice_ms retained for diagnostics; device acceptance uses scoped cave p95 and boot slices')
            if not frames:
                report['failures'].append('missing-device-frames')
            for phase in ('title.live.after_gc', 'Continue.live.after_gc'):
                if not any(r['phase'] == phase for r in phases):
                    report['failures'].append('missing-' + phase)
        except (ValueError, OSError) as error:
            report['failures'].append('missing-or-invalid-device-metrics: ' + str(error))
        seen = report['observations']
        if not (seen['title'] and seen['continue_available'] and seen['loaded'] > 0 and seen['saved'] > 0):
            report['failures'].append('missing-title-earned-Continue-or-save')
        atomic_json(self.output / 'device-smoke.json', report)
        table = phase_table_text(report)
        (self.output / 'device-phases.md').write_text(table)
        print(table, flush=True)
        # Collection can succeed without acceptance. Missing metrics stay explicit.
        self.event('device-smoke-reported', failures=report['failures'], boot_accepted=False)

    def disk(self):
        if not (self.volume / 'Games').is_dir():
            if self.ran:
                if not self.select_serial():
                    raise RuntimeError('device needs one A press; USB disappeared; no further device attempts')
            else:
                self.wait_for(self.select_serial, self.args.disk_timeout, 'waiting for unlocked USB serial')
            simulator_usb_preflight()
            self.command([str(self.sdk / 'bin/pdutil'), self.serial, 'datadisk'])
        self.wait_for(lambda: (self.volume / 'Games').is_dir(), self.args.disk_timeout,
                      'waiting for PLAYDATE data disk')
        for path in (self.volume, self.volume / 'Games', self.volume / 'Data'):
            plain_path(path, self.volume)

    def archive(self, label, installed, data):
        destination = self.output / label
        destination.mkdir()
        files = inventory(installed) if installed.exists() else None
        atomic_json(destination / 'installed-pdx.json', {
            'present': files is not None, 'files': files,
            'sha256': tree_hash(files) if files is not None else None})
        if files:
            for name in ('main.pdz', 'pdxinfo'):
                if name in files:
                    copy_verified(installed / name, destination / 'installed-binary' / name, files[name])
        if files and 'pdxinfo' in files:
            info = dict(line.split('=', 1) for line in (installed / 'pdxinfo').read_text().splitlines() if '=' in line)
            actual_id = info.get('bundleID', '').strip()
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', actual_id) or actual_id in {'.', '..'}:
                raise ValueError('unsafe installed bundle ID')
            actual_data = plain_path(self.volume / 'Data' / actual_id, self.volume)
        else:
            actual_data = data
        # Preserve both actual installed Data and candidate Data when IDs differ.
        for folder in {actual_data, data}:
            plain_path(folder, self.volume)
            data_files = inventory(folder) if folder.exists() else {}
            for name, digest in data_files.items():
                copy_verified(folder / name, destination / folder.relative_to(self.volume) / name, digest)
        atomic_json(destination / 'data-inventory.json', {
            str(folder.relative_to(self.volume)): inventory(folder) if folder.exists() else None
            for folder in sorted({actual_data, data})})
        logs = {}
        paths = [self.volume / name for name in ('errorlog.txt', 'crashlog.txt')]
        paths += [self.volume / 'System/Logs' / name for name in ('errorlog.txt', 'crashlog.txt')]
        paths += [folder / name for folder in sorted({actual_data, data})
                  for name in ('boot-trace.tsv', 'calibration.json', IDENTITY)]
        for path in paths:
            plain_path(path, self.volume)
            relative = path.relative_to(self.volume).as_posix()
            if path.exists():
                digest = sha(path)
                copy_verified(path, destination / relative, digest)
                logs[relative] = {'sha256': digest}
            else:
                logs[relative] = {'missing': True}
        atomic_json(destination / 'logs.json', logs)
        self.event('archived', directory=label, installed_sha256=tree_hash(files) if files is not None else None)
        return files

    def validate_inputs(self):
        args = self.args
        self.step('validate-local-inputs')
        self.sdk = sdk_path(args.sdk)
        pdx = Path(args.pdx).expanduser().resolve()
        stage = Path(args.build_stage).expanduser().resolve()
        build = json.loads((stage / 'build.json').read_text())
        source = inventory(stage / 'Source')
        payload = inventory(pdx)
        soak_mode = bool(getattr(args, 'soak_proof', None))
        smoke_mode = bool(getattr(args, 'simulator_smoke', None))
        if soak_mode:
            from tools.device.soak.evidence import admission
            from tools.device.soak.lifecycle import validate_mode
            validate_mode(args, stage)
            build, soak_report = admission(stage, args.soak_proof)
            if pdx != stage / 'Soak.pdx' or sha(self.sdk / 'bin/pdc') != build['compiler_sha256'] or (self.sdk / 'VERSION.txt').read_text().strip() != build['sdk_version']:
                raise ValueError('soak SDK/PDX mismatch')
            soak_admission = {'classification': 'exact short soak safety proof; not hardware acceptance',
                              'report_sha256': sha(Path(args.soak_proof)), 'report': soak_report}

        elif smoke_mode:
            self.smoke_build, self.smoke_report, smoke_admission = smoke_gate(args, stage, pdx)
            if (sha(self.sdk / 'bin/pdc') != build['compiler_sha256']
                    or (self.sdk / 'VERSION.txt').read_text().strip() != build['sdk_version']):
                raise ValueError('SDK differs from exact smoke build')
        else:
            if inventory(stage / 'Production.pdx') != payload:
                raise ValueError('PDX differs from retained compiler output')
            if (build.get('mode') != 'production' or Path(build['bundle']).resolve() != pdx
                    or build.get('source_sha256') != fingerprint(stage, exclude_generated=False)):
                raise ValueError('PDX must match a retained production build stage')
        if not payload or pdx.suffix != '.pdx' or not re.fullmatch(r'[A-Za-z0-9_.-]+\.pdx', pdx.name):
            raise ValueError('expected a nonempty, safely named .pdx')
        info = dict(line.split('=', 1) for line in (stage / 'Source/pdxinfo').read_text().splitlines() if '=' in line)
        bundle_id = info.get('bundleID', '').strip()
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', bundle_id) or bundle_id in {'.', '..'}:
            raise ValueError('invalid bundleID')
        if not (smoke_mode or soak_mode) and ((stage / 'Source/dev').exists() or any(name.startswith('dev/') for name in payload)):
            raise ValueError('development payload refused')
        manifest = {'schema': 1, 'pdx': str(pdx), 'pdx_files': payload,
                    'pdx_sha256': tree_hash(payload), 'source_files': source,
                    'source_sha256': build['compiled_source_sha256'] if soak_mode else build['source_sha256'], 'build': build,
                    'bundle_id': bundle_id, 'stage': str(stage)}
        atomic_json(self.output / 'manifest.json', manifest)
        if soak_mode:
            gate = soak_admission
        elif smoke_mode:
            gate = smoke_admission
        elif getattr(args, 'calibration_preflight', None):
            gate = calibration_gate(args, manifest, source)
        else:
            gate = json.loads(Path(args.simulator_gate).expanduser().read_text())
            self.validate_game_gate(gate, manifest)
        atomic_json(self.output / 'simulator-gate.json', gate)
        return pdx, stage, bundle_id, payload, manifest

    def validate_game_gate(self, gate, manifest):
        if (gate.get('malloc_pool_mb') != 16 or gate.get('pdx_sha256') != manifest['pdx_sha256']
                or gate.get('source_sha256') != manifest['source_sha256']):
            raise ValueError('Simulator gate must identify this exact build and its 16 MB malloc pool')
        required = {'heap_live_bytes', 'heap_peak_bytes', 'map_load_ms', 'battle_start_ms', 'frame_ms', 'slice_ms'}
        measured = gate.get('measurements', {})
        limits = gate.get('limits', {})
        if not required <= measured.keys() or not required <= limits.keys():
            raise ValueError('Simulator gate missing measured budgets')
        for name in required:
            value, limit = measured[name], limits[name]
            if (type(value) not in (int, float) or type(limit) not in (int, float)
                    or not math.isfinite(value) or not math.isfinite(limit) or not 0 <= value <= limit or limit <= 0):
                raise ValueError('Simulator budget failed: ' + name)

    def validate_earned(self):
        args = self.args
        earned = None
        if args.earned_save:
            earned = json.loads(Path(args.earned_save).expanduser().read_text())
            rows = earned['files']
            if len(rows) != 2 or {row['file'] for row in rows} != SLOTS:
                raise ValueError('earned save manifest must name both adventure slots exactly')
            for row in rows:
                path = Path(earned['directory']) / row['file']
                if path.is_symlink() or sha(path) != row['sha256']:
                    raise ValueError('earned save checksum mismatch')
            atomic_json(self.output / 'earned-save.json', earned)
        return earned

    def execute(self):
        args = self.args
        pdx, stage, bundle_id, payload, manifest = self.validate_inputs()
        earned = self.validate_earned()
        installed = plain_path(self.volume / 'Games' / pdx.name, self.volume)
        data = plain_path(self.volume / 'Data' / bundle_id, self.volume)
        print('Unattended cycle: no routine unlock or replug actions. A hard crash or missing '
              'serial after run stops device attempts: device needs one A press. '
              'Simulator-only work may continue after the serial reader is closed.', flush=True)
        with OwnerLock(runtime_lock_path(self.sdk)), OwnerLock(device_lock_path()):
            from tools.device.soak import lifecycle as soak
            soak.enter(self, manifest)  # All device candidates honor a live soak reservation.
            if getattr(args, 'soak_collect', None):
                soak.collect(self, installed, data, payload)
                return
            if getattr(args, 'soak_proof', None):
                from tools.device.soak.evidence import admission
                if admission(stage, args.soak_proof)[0] != manifest['build']:
                    raise ValueError('soak changed while acquiring locks')
            if self.smoke_build:
                checked, _, _ = smoke_gate(args, stage, pdx)
                if checked != self.smoke_build:
                    raise ValueError('smoke build changed while acquiring ownership')
            self.step('deploy-enter-data-disk')
            self.disk()
            self.step('archive-current-install-before-write')
            previous = self.archive('before', installed, data)
            prior_name = getattr(args, 'inspect_previous_game', None)
            if prior_name:
                if not re.fullmatch(r'[A-Za-z0-9_.-]+\.pdx', prior_name):
                    raise ValueError('unsafe previous-game name')
                prior = plain_path(self.volume / 'Games' / prior_name, self.volume)
                prior_info = dict(line.split('=', 1) for line in (prior / 'pdxinfo').read_text().splitlines() if '=' in line)
                prior_id = prior_info.get('bundleID', '').strip()
                if not re.fullmatch(r'[A-Za-z0-9_.-]+', prior_id) or prior_id in {'.', '..'}:
                    raise ValueError('unsafe previous-game bundle ID')
                self.archive('previous-game', prior, self.volume / 'Data' / prior_id)
            self.step('backup-existing-save-slots' if earned else 'preserve-application-data')
            before_data = inventory(data) if data.exists() else {}
            atomic_json(self.output / 'data-before.json', before_data)
            if getattr(args, 'soak_launch', False) and before_data:
                raise ValueError('soak requires fresh private Data')
            if self.smoke_build and any(name in before_data for name in (
                    'boot-profile-build.json', 'device-smoke-command.txt', 'device-smoke-frames.tsv')):
                raise ValueError('smoke Data contains stale metrics, external identity or an unconsumed command')
            if earned:
                for name in sorted(SLOTS):
                    if name in before_data:
                        copy_verified(data / name, self.output / 'save-backup' / name, before_data[name])
                atomic_json(self.output / 'save-backup.json', {name: before_data.get(name) for name in sorted(SLOTS)})
            self.step('copy-changed-pdx-files')
            installed.mkdir(parents=True, exist_ok=True)
            changed = []
            for name, digest in payload.items():
                target = plain_path(installed / name, self.volume)
                if not target.is_file() or sha(target) != digest:
                    copy_verified(pdx / name, target, digest)
                    changed.append(name)
            # Remove only obsolete payload files, never application Data.
            for name in sorted(set(previous or {}) - set(payload)):
                plain_path(installed / name, self.volume).unlink()
            self.event('copied', changed=changed, obsolete=sorted(set(previous or {}) - set(payload)))
            self.step('verify-every-payload-hash')
            if inventory(installed) != payload:
                raise ValueError('installed PDX inventory/hash mismatch')
            self.step('write-explicit-identity-and-save-import')
            data.mkdir(parents=True, exist_ok=True)
            if args.clear_boot_trace:
                plain_path(data / 'boot-trace.tsv', self.volume).unlink(missing_ok=True)
            if earned:
                for row in earned['files']:
                    copy_verified(Path(earned['directory']) / row['file'],
                                  plain_path(data / row['file'], self.volume), row['sha256'])
            atomic_json(plain_path(data / IDENTITY, self.volume), manifest)
            after_data = inventory(data)
            allowed = {IDENTITY} | (SLOTS if earned else set()) | ({'boot-trace.tsv'} if args.clear_boot_trace else set())
            if {k: v for k, v in before_data.items() if k not in allowed} != {k: v for k, v in after_data.items() if k not in allowed}:
                raise ValueError('unrequested application Data change')
            self.step('eject')
            self.command(['diskutil', 'eject', str(self.volume)])
            self.wait_for(lambda: not self.volume.exists(), 30, 'waiting for disk unmount')
            self.step('run')
            self.wait_for(self.select_serial, args.disk_timeout, 'waiting for serial after eject/unlock')
            simulator_usb_preflight()
            self.ran = True  # a timed-out run command may already have launched
            self.command([str(self.sdk / 'bin/pdutil'), self.serial, 'run', '/Games/' + pdx.name])
            if getattr(args, 'soak_launch', False):
                soak.launched(self)
                return  # subprocess closed serial; context releases BOTH locks
            self.step('wait-for-game')
            deadline = time.monotonic() + args.run_seconds
            attempt_error = None
            if self.smoke_build:
                try:
                    self.wait_smoke(deadline)
                except Exception as error:
                    attempt_error = error
                    self.event('smoke-stopped', error=repr(error), replay=False)
                # Never issue another hardware command after disappearance.
                if not self.select_serial():
                    raise RuntimeError('device needs one A press; USB disappeared; no further device attempts')
            elif getattr(args, 'calibration_preflight', None):
                self.wait_calibration(deadline)
            else:
                while time.monotonic() < deadline:
                    if not self.select_serial():
                        raise RuntimeError('device needs one A press; no further device attempts; Simulator-only work may continue')
                    time.sleep(max(0, min(1, deadline - time.monotonic())))
            self.step('collect-enter-data-disk')
            self.disk()
            self.step('collect-result-logs')
            actual = self.archive('after', installed, data)
            if actual != payload:
                raise ValueError('installed build changed during cycle')
            if self.smoke_build:
                self.report_smoke(bundle_id)
            before_logs = json.loads((self.output / 'before/logs.json').read_text())
            after_logs = json.loads((self.output / 'after/logs.json').read_text())
            for name, record in after_logs.items():
                if name.endswith(('errorlog.txt', 'crashlog.txt')) and record != before_logs.get(name) and 'sha256' in record:
                    if (self.output / 'after' / name).stat().st_size:
                        raise RuntimeError('device needs one A press; new crash log; no further device attempts; Simulator-only work may continue')
            if attempt_error:
                raise attempt_error
            if getattr(args, 'leave_running', False):
                self.step('return-to-running-app')
                self.command(['diskutil', 'eject', str(self.volume)])
                self.wait_for(lambda: not (self.volume / 'Games').exists(), 30, 'waiting for collected disk unmount')
                self.wait_for(self.select_serial, args.disk_timeout, 'waiting for serial after collection')
                simulator_usb_preflight()
                self.command([str(self.sdk / 'bin/pdutil'), self.serial, 'run', '/Games/' + pdx.name])
                if not self.select_serial():
                    raise RuntimeError('device needs one A press; USB disappeared; no further device attempts')
            self.event('complete', leave_running=bool(getattr(args, 'leave_running', False)),
                       note='logs archived; no boot acceptance inferred')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute-root', action='store_true', required=True,
                        help='explicit root operator authorization; workers must not execute')
    parser.add_argument('--safety-only', action='store_true',
                        help='admit a complete error-free 16 MB smoke with <=9 MiB peak and <=150 ms slices; not playability acceptance')
    parser.add_argument('--validate-only', action='store_true', help='local admission only; no ownership locks or device access')
    parser.add_argument('--pdx', required=True)
    parser.add_argument('--build-stage', required=True)
    parser.add_argument('--output', required=True, help='fresh evidence directory')
    gates = parser.add_mutually_exclusive_group(required=True)
    gates.add_argument('--soak-proof', help='exact short Simulator soak proof; not soak acceptance')
    split = parser.add_mutually_exclusive_group()
    split.add_argument('--soak-launch', action='store_true')
    split.add_argument('--soak-collect', help='exact launch evidence directory')
    gates.add_argument('--simulator-smoke', help='exact passed DeviceSmoke report; recomputed before any device access')
    gates.add_argument('--simulator-gate', help='root measured 16 MB game gate for this exact build')
    gates.add_argument('--calibration-preflight', help='completed minimal calibration Simulator record; not a game gate')
    parser.add_argument('--calibration-build', help='exact minimal calibration build manifest')
    parser.add_argument('--inspect-previous-game', help='also archive this installed .pdx and its logs before writing')
    parser.add_argument('--leave-running', action='store_true', help='eject collected disk and immediately relaunch the verified app')
    parser.add_argument('--sdk')
    parser.add_argument('--volume', default='/Volumes/PLAYDATE')
    parser.add_argument('--serial')
    parser.add_argument('--disk-timeout', type=float, default=300)
    parser.add_argument('--run-seconds', type=float, default=30)
    parser.add_argument('--earned-save', help='explicit manifest with directory and two file/sha256 rows')
    parser.add_argument('--clear-boot-trace', action='store_true', help='archive then clear only boot-trace.tsv')
    args = parser.parse_args()
    cycle = None
    try:
        if any(not math.isfinite(value) or value <= 0 for value in (args.disk_timeout, args.run_seconds)):
            raise ValueError('timeouts must be finite positive seconds')
        cycle = Cycle(args)
        if args.validate_only:
            cycle.validate_inputs()
            cycle.validate_earned()
            atomic_json(cycle.output / 'outcome.json', {'ok': True, 'validated_only': True, 'boot_accepted': False})
            return 0
        cycle.execute()
        atomic_json(cycle.output / 'outcome.json', {'ok': True, 'boot_accepted': False})
        return 0
    except (Exception, KeyboardInterrupt) as error:
        if cycle:
            if cycle.ran and isinstance(error, (TimeoutError, subprocess.TimeoutExpired, subprocess.CalledProcessError)):
                error = RuntimeError('device needs one A press; no further device attempts; Simulator-only work may continue: ' + str(error))
            cycle.event('error', error=repr(error))
            atomic_json(cycle.output / 'outcome.json', {
                'ok': False, 'boot_accepted': False, 'phase': cycle.phase,
                'device_needs_one_A_press': 'device needs one A press' in str(error),
                'error': repr(error)})
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
