#!/usr/bin/env python3
"""Verify a retained DeviceSmoke build; --execute is reserved for the root operator.

Never compiles, patches, deploys, or opens USB. Uses the exact retained PDX.
"""
import argparse
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.device.build_smoke import manifest
from tools.device_cycle import SLOTS, copy_verified, inventory, sha, tree_hash
from tools.harness import run
from tools.harness.protocol import OwnerLock, atomic_json

COMMAND = re.compile(r'(?:state|press (?:a|b|up|down|left|right) ([0-9]+)|wait ([0-9]+)|release (?:all|a|b|up|down|left|right))\Z')


def commands(path):
    values = json.loads(path.read_text())
    if not isinstance(values, list) or len(values) > 10000:
        raise ValueError('commands must be a JSON list of at most 10000 DS1 command bodies')
    for value in values:
        match = COMMAND.fullmatch(value) if isinstance(value, str) else None
        if not match or (match[1] and not 1 <= int(match[1]) <= 120) or (match[2] and not 1 <= int(match[2]) <= 300):
            raise ValueError('invalid DS1 command: ' + repr(value))
    return values


def verify(stage):
    build = json.loads((stage / 'build.json').read_text())
    bundle = Path(build['bundle'])
    if (build.get('mode') != 'device-test-compile-only'
            or bundle.resolve() != (stage / 'DeviceSmoke.pdx').resolve()
            or not re.fullmatch(r'[0-9a-f]{32}', build.get('build_id', ''))
            or build.get('bundle_id') != 'com.poc.pokemon.device-test.' + build['build_id']):
        raise ValueError('not an identified retained DeviceSmoke build')
    source = manifest(stage / 'Source')
    payload = inventory(bundle)
    if (source != build['compiled_source_manifest']
            or tree_hash(source) != build['compiled_source_sha256']
            or run.fingerprint(stage, exclude_generated=False) != build['source_sha256']
            or payload != build['pdx_files'] or tree_hash(payload) != build['pdx_sha256']):
        raise ValueError('retained source or compiled bundle changed')
    if {name for name in source if name.startswith('dev/')} != {'dev/deviceSmoke.lua'}:
        raise ValueError('private build must retain exactly one dev module')
    info = dict(line.split('=', 1) for line in (stage / 'Source/pdxinfo').read_text().splitlines() if '=' in line)
    if info.get('bundleID') != build['bundle_id']:
        raise ValueError('bundle identity mismatch')
    return build


def import_saves(record_path, data, output):
    record = json.loads(record_path.read_text())
    rows = record['files']
    if len(rows) != 2 or {row['file'] for row in rows} != SLOTS:
        raise ValueError('earned manifest must identify both adventure slots exactly')
    for row in rows:
        copy_verified(Path(record['directory']) / row['file'], data / row['file'], row['sha256'])
    atomic_json(output / 'earned-save.json', record)


class Mailbox:
    def __init__(self, data, build_id, process, timeout):
        self.data, self.build_id, self.process, self.timeout = data, build_id, process, timeout
        self.sequence = 0
        self.offset = 0
        self.responses = []

    def command(self, body):
        self.sequence += 1
        if self.sequence > 16777215:
            raise ValueError('DS1 sequence exhausted')
        target = self.data / 'device-smoke-command.txt'
        if target.exists():
            raise ValueError('unconsumed mailbox command; refusing overwrite')
        temporary = target.with_suffix('.tmp')
        temporary.write_text(f'DS1 {self.sequence} {body}')
        temporary.replace(target)
        deadline = time.monotonic() + self.timeout
        while True:
            reply_path = self.data / 'device-smoke-replies.jsonl'
            if reply_path.exists():
                with reply_path.open() as stream:
                    stream.seek(self.offset)
                    while True:
                        start = stream.tell()
                        line = stream.readline()
                        if not line.endswith('\n'):
                            self.offset = start
                            break
                        self.offset = stream.tell()
                        reply = json.loads(line)
                        self.responses.append(reply)
                        if reply.get('build') != self.build_id:
                            raise ValueError('DS1 response build identity mismatch')
                        if reply.get('status') == 'error':
                            raise ValueError('DS1 failed: ' + str(reply.get('value')))
                        if reply.get('seq') == self.sequence and reply.get('status') == 'done':
                            return reply['value']
            trace = self.data / 'boot-trace.tsv'
            if trace.exists() and '\terror.' in trace.read_text():
                raise ValueError('BootTrace guard failed; inspect retained runtime-data')
            if self.process.poll() is not None or time.monotonic() >= deadline:
                raise TimeoutError('Simulator exited or DS1 command timed out: ' + body)
            time.sleep(0.02)


def observations(responses):
    values = [row['value'] for row in responses if row.get('status') == 'done' and isinstance(row.get('value'), dict)]
    return {'title': any(v.get('state') == 'title' for v in values),
            'continue_available': any(v.get('continue_available') is True for v in values),
            'loaded': max((v.get('loaded', 0) for v in values), default=0),
            'saved': max((v.get('saved', 0) for v in values), default=0),
            'states': values}


def measurements(data, build_id, factor):
    """Never infer active time from BootTrace phase gaps spanning coroutine yields."""
    from tools.device.metrics import ordinary_frames, gc_windows
    frames = []
    for line in (data / 'device-smoke-frames.tsv').read_text().splitlines():
        columns = line.split('\t')
        if len(columns) not in (6, 7, 8) or (len(columns) >= 7 and columns[6] not in {'0', '1'}):
            raise ValueError('invalid frame columns')
        identity, update, segment, kind, elapsed, heap = columns[:6]
        values = [float(elapsed), float(heap)]
        if identity != build_id or kind not in {'yield', 'return', 'error'} or any(not math.isfinite(v) or v < 0 for v in values):
            raise ValueError('invalid frame measurement or build identity')
        frames.append({'update': int(update), 'segment': int(segment), 'kind': kind,
                       'active_ms': values[0], 'heap_kib': values[1],
                       'loading': len(columns) >= 7 and columns[6] == '1',
                       'start_ms': float(columns[7]) if len(columns) == 8 else None})
        if frames[-1]['start_ms'] is not None and (not math.isfinite(frames[-1]['start_ms']) or frames[-1]['start_ms'] < 0):
            raise ValueError('invalid active segment timestamp')
    lines = (data / 'boot-trace.tsv').read_text().splitlines()
    if not lines or lines[0] != f'schema\t1\tbuild\t{build_id}\tplatform\tsimulator':
        raise ValueError('BootTrace identity/platform mismatch')
    phases = []
    for line in lines[2:]:
        sequence, phase, clock, since_yield, phase_ms, heap, peak = line.split('\t')
        values = [float(v) for v in (clock, since_yield, phase_ms, heap, peak)]
        if any(not math.isfinite(v) or v < 0 for v in values):
            raise ValueError('invalid BootTrace measurement')
        phases.append(dict(phase=phase, clock_ms=values[0], since_yield_ms=values[1],
                           phase_ms=values[2], heap_kib=values[3], peak_kib=values[4]))
    def span(begin, end):
        start, spans = None, []
        for row in phases:
            if row['phase'] == begin:
                start = row['clock_ms']
            elif row['phase'] == end and start is not None:
                spans.append(row['clock_ms'] - start)
                start = None
        return max(spans) if spans else None
    def predicted_span(begin, end):
        start, estimates = None, []
        for row in phases:
            if row['phase'] == begin:
                start = row['clock_ms']
            elif row['phase'] == end and start is not None:
                stop = row['clock_ms']
                active = sum(max(0, min(stop, frame['start_ms'] + frame['active_ms'])
                                 - max(start, frame['start_ms'])) for frame in frames)
                wall = stop - start
                # Two endpoint milliseconds cover alignment with integer phase
                # clocks. Suspension/display wait is retained at its observed
                # duration; the Lua calibration factor applies to active work.
                estimates.append(wall + (min(wall, active + 2) * max(0, factor - 1)))
                start = None
        return max(estimates) if estimates else None
    live = [row['heap_kib'] * 1024 for row in phases if row['phase'] in {'title.live.after_gc', 'Continue.live.after_gc'}]
    measured = {'heap_live_bytes': max(live) if live else None,
                'heap_peak_bytes': max([r['peak_kib'] * 1024 for r in phases] + [f['heap_kib'] * 1024 for f in frames], default=None),
                'map_load_ms': span('door.map.begin', 'door.map.end'),
                'battle_start_ms': span('battle.start.begin', 'battle.start.end'),
                'frame_ms': max((f['active_ms'] for f in ordinary_frames(frames, phases)), default=None),
                'slice_ms': max([f['active_ms'] for f in frames] + [r['since_yield_ms'] for r in phases], default=None)}
    limits = {'heap_live_bytes': 6 * 1024**2, 'heap_peak_bytes': 9 * 1024**2,
              'map_load_ms': 500 / factor, 'battle_start_ms': 500 / factor,
              'frame_ms': 33 / factor, 'slice_ms': 1000 / factor}
    if frames and all(frame['start_ms'] is not None for frame in frames):
        limits['map_load_ms'] = limits['battle_start_ms'] = 500
        for name, begin, end in (
            ('map_device_estimate_ms', 'door.map.begin', 'door.map.end'),
            ('battle_device_estimate_ms', 'battle.start.begin', 'battle.start.end'),
        ):
            estimate = predicted_span(begin, end)
            if estimate is not None:
                measured[name] = estimate
                limits[name] = 500
    failures = [name for name, value in measured.items() if value is None or value > limits[name]]
    if not frames or any(f['kind'] == 'error' for f in frames) or any(r['phase'].startswith('error.') for r in phases):
        failures.append('runtime-error-or-no-frames')
    if not all(any(r['phase'] == p for r in phases) for p in ('title.live.after_gc', 'Continue.live.after_gc')):
        failures.append('missing-title-or-Continue-live-heap')
    return {'measurements': measured, 'limits': limits, 'budget_failures': failures,
            'frames': frames, 'phases': phases, 'timing_factor': factor,
            'diagnostic_gc_windows': gc_windows(phases),
            'metric_classification': 'Simulator raw safety evidence; legacy factor estimates are not device acceptance',
            'timing_basis': 'SDK active elapsed segments exclude suspension, polling and observer IO; phase loads are wall elapsed including suspension. Not OS CPU time. Lua heap excludes native allocations.'}


def execute(stage, sdk, output, earned, bodies, timeout, factor):
    build = verify(stage)
    if build.get('simulator_transport_version') != 1:
        raise ValueError('root must apply device-smoke-simulator.patch and compile a new private build')
    if (sdk / 'VERSION.txt').read_text().strip() != build['sdk_version']:
        raise ValueError('Simulator SDK differs from compile SDK')
    output.mkdir(parents=True, exist_ok=False)
    data = sdk / 'Disk/Data' / build['bundle_id']
    process, mailbox = None, None
    report = {'build': build, 'device_gate_passed': False, 'status': 'failed',
              'classification': 'Simulator only; not yet playable on Playdate hardware',
              'malloc_pool_mb': 16, 'malloc_pool_preflight': 16645684,
              'commands': bodies, 'commands_sha256': tree_hash(bodies)}
    with OwnerLock(run.runtime_lock_path(sdk)), OwnerLock(run.device_lock_path()):
        run.simulator_preflight()
        data.mkdir(parents=True, exist_ok=False)
        try:
            import_saves(earned, data, output)
            # BootTrace's optional external identity file is deliberately absent.
            with (output / 'simulator.log').open('w') as log:
                simulator = sdk / 'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'
                process = subprocess.Popen([str(simulator), build['bundle']], stdout=log, stderr=subprocess.STDOUT)
                report['simulator_pid'] = process.pid
                atomic_json(output / 'run.json', report)
                mailbox = Mailbox(data, build['build_id'], process, timeout)
                deadline = time.monotonic() + timeout
                while True:
                    state = mailbox.command('state')
                    if state.get('ready'):
                        break
                    if time.monotonic() >= deadline:
                        raise TimeoutError('ordinary gameplay never became ready')
                    time.sleep(0.05)
                for body in bodies:
                    mailbox.command(body)
                mailbox.command('state')
        except Exception as error:
            report['error'] = str(error)
        finally:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
            shutil.copytree(data, output / 'runtime-data')
            # Keep SDK Data for inspection/restart; never remove earned slots.
            report['data_dir'] = str(data)
            responses = mailbox.responses if mailbox else []
            report['observations'] = observations(responses)
            atomic_json(output / 'responses.json', responses)
            try:
                report.update(measurements(data, build['build_id'], factor))
                if verify(stage) != build:
                    raise ValueError('build metadata changed during runtime')
                seen = report['observations']
                complete = seen['title'] and seen['continue_available'] and seen['loaded'] > 0 and seen['saved'] > 0
                if not complete:
                    report['error'] = report.get('error', 'missing title, earned Continue or verified save observation')
                if not report.get('error') and not report['budget_failures']:
                    report['status'] = 'simulator-smoke-passed'
            except Exception as error:
                report['measurement_error'] = str(error)
            atomic_json(output / 'simulator-smoke.json', report)
    if report['status'] != 'simulator-smoke-passed':
        raise ValueError('Simulator smoke failed: ' + str(report.get('error') or report.get('measurement_error')
                         or report.get('budget_failures')) + '; inspect ' + str(output / 'simulator-smoke.json'))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-stage', type=Path, required=True)
    parser.add_argument('--execute', action='store_true', help='root only: launch the exact compiled PDX')
    parser.add_argument('--sdk', type=Path, default=Path('~/Developer/PlaydateSDK'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--earned-save', type=Path, help='manifest with directory and two file/sha256 rows')
    parser.add_argument('--commands', type=Path, help='JSON list of DS1 command bodies, no sequence envelope')
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--timing-factor', type=float, help='root supplied device/Simulator factor; provenance must be recorded separately')
    args = parser.parse_args()
    stage = args.build_stage.expanduser().resolve()
    build = verify(stage)
    if not args.execute:
        print(json.dumps({'status': 'verified-not-executed', 'build_id': build['build_id'],
                          'source_sha256': build['source_sha256'], 'pdx_sha256': build['pdx_sha256']}, indent=2))
        return
    if not all((args.output, args.earned_save, args.commands)) or not args.timing_factor or not math.isfinite(args.timing_factor) or args.timing_factor <= 0 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('--execute requires --output, --earned-save, --commands, positive finite --timing-factor and --timeout')
    execute(stage, args.sdk.expanduser().resolve(), args.output.expanduser().resolve(),
            args.earned_save.expanduser().resolve(), commands(args.commands), args.timeout, args.timing_factor)


if __name__ == '__main__':
    main()
