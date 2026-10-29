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

    def disk(self):
        if not (self.volume / 'Games').is_dir():
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
        logs = {}
        paths = [self.volume / name for name in ('errorlog.txt', 'crashlog.txt')]
        paths += [self.volume / 'System/Logs' / name for name in ('errorlog.txt', 'crashlog.txt')]
        paths += [data / 'boot-trace.tsv', data / 'calibration.json', data / IDENTITY]
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
        if inventory(stage / 'Production.pdx') != payload:
            raise ValueError('PDX differs from retained compiler output')
        if not payload or pdx.suffix != '.pdx' or not re.fullmatch(r'[A-Za-z0-9_.-]+\.pdx', pdx.name):
            raise ValueError('expected a nonempty, safely named production .pdx')
        if (build.get('mode') != 'production' or Path(build['bundle']).resolve() != pdx
                or build.get('source_sha256') != fingerprint(stage, exclude_generated=False)):
            raise ValueError('PDX must match a retained production build stage')
        info = dict(line.split('=', 1) for line in (stage / 'Source/pdxinfo').read_text().splitlines() if '=' in line)
        bundle_id = info.get('bundleID', '').strip()
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', bundle_id) or bundle_id in {'.', '..'}:
            raise ValueError('invalid bundleID')
        if (stage / 'Source/dev').exists() or any(name.startswith('dev/') for name in payload):
            raise ValueError('development payload refused')
        manifest = {'schema': 1, 'pdx': str(pdx), 'pdx_files': payload,
                    'pdx_sha256': tree_hash(payload), 'source_files': source,
                    'source_sha256': build['source_sha256'], 'build': build,
                    'bundle_id': bundle_id, 'stage': str(stage)}
        atomic_json(self.output / 'manifest.json', manifest)
        if getattr(args, 'calibration_preflight', None):
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

    def execute(self):
        args = self.args
        pdx, stage, bundle_id, payload, manifest = self.validate_inputs()
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
        installed = plain_path(self.volume / 'Games' / pdx.name, self.volume)
        data = plain_path(self.volume / 'Data' / bundle_id, self.volume)
        print('Unattended cycle: no routine unlock or replug actions. A hard crash or missing '
              'serial after run stops device attempts: device needs one A press. '
              'Simulator-only work may continue after the serial reader is closed.', flush=True)
        with OwnerLock(runtime_lock_path(self.sdk)), OwnerLock(device_lock_path()):
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
                if not re.fullmatch(r'[A-Za-z0-9_.-]+', prior_id):
                    raise ValueError('unsafe previous-game bundle ID')
                self.archive('previous-game', prior, self.volume / 'Data' / prior_id)
            self.step('backup-existing-save-slots' if earned else 'preserve-application-data')
            before_data = inventory(data) if data.exists() else {}
            atomic_json(self.output / 'data-before.json', before_data)
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
            self.command([str(self.sdk / 'bin/pdutil'), self.serial, 'run', '/Games/' + pdx.name])
            self.ran = True
            self.step('wait-for-game')
            deadline = time.monotonic() + args.run_seconds
            if getattr(args, 'calibration_preflight', None):
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
            if getattr(args, 'leave_running', False):
                self.step('return-to-running-app')
                self.command(['diskutil', 'eject', str(self.volume)])
                self.wait_for(lambda: not (self.volume / 'Games').exists(), 30, 'waiting for collected disk unmount')
                self.wait_for(self.select_serial, args.disk_timeout, 'waiting for serial after collection')
                simulator_usb_preflight()
                self.command([str(self.sdk / 'bin/pdutil'), self.serial, 'run', '/Games/' + pdx.name])
            before_logs = json.loads((self.output / 'before/logs.json').read_text())
            after_logs = json.loads((self.output / 'after/logs.json').read_text())
            for name, record in after_logs.items():
                if name.endswith(('errorlog.txt', 'crashlog.txt')) and record != before_logs.get(name) and 'sha256' in record:
                    if (self.output / 'after' / name).stat().st_size:
                        raise RuntimeError('device needs one A press; new crash log; no further device attempts; Simulator-only work may continue')
            self.event('complete', note='data disk left mounted; logs can be missing; no boot acceptance inferred')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute-root', action='store_true', required=True,
                        help='explicit root operator authorization; workers must not execute')
    parser.add_argument('--pdx', required=True)
    parser.add_argument('--build-stage', required=True)
    parser.add_argument('--output', required=True, help='fresh evidence directory')
    gates = parser.add_mutually_exclusive_group(required=True)
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
        cycle.execute()
        atomic_json(cycle.output / 'outcome.json', {'ok': True, 'boot_accepted': False})
        return 0
    except (Exception, KeyboardInterrupt) as error:
        if cycle:
            if cycle.ran and isinstance(error, (TimeoutError, subprocess.TimeoutExpired, subprocess.CalledProcessError)):
                error = RuntimeError('device needs one A press; no further device attempts; Simulator-only work may continue: ' + str(error))
            cycle.event('error', error=repr(error))
            atomic_json(cycle.output / 'outcome.json', {'ok': False, 'phase': cycle.phase, 'error': repr(error)})
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
