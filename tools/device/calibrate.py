#!/usr/bin/env python3
"""Compile a minimal private calibration PDX, or compare collected JSON. Never runs it."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import uuid

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.build import compile_production
from tools.harness.run import sdk_path

PROJECT = Path(__file__).resolve().parents[2]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def manifest(directory):
    return {p.relative_to(directory).as_posix(): digest(p.read_bytes())
            for p in sorted(directory.rglob('*')) if p.is_file()}


def build(project, sdk, output):
    if any((parent / '.git').exists() for parent in (output, *output.parents)):
        raise ValueError('calibration output must be outside Git')
    output.mkdir(parents=True, exist_ok=False)
    source = output / 'input/Source'
    (source / 'game').mkdir(parents=True)
    for origin, target in [('Source/game/bootTrace.lua', 'game/bootTrace.lua'),
                           ('Source/dev/calibration.lua', 'calibration.lua')]:
        (source / target).write_bytes((project / origin).read_bytes())
    sdk_version = (sdk / 'VERSION.txt').read_text().strip()
    source_hash = digest(json.dumps(manifest(source), sort_keys=True).encode())
    identity = uuid.uuid4().hex  # one compilation; reuse this exact PDX on both platforms
    info = {'id': identity, 'source_sha256': source_hash, 'sdk_version': sdk_version}
    (source / 'main.lua').write_text(
        'DEVICE_TEST_BUILD = true\nDEVICE_TEST_ID = ' + json.dumps(identity) + '\n'
        'CALIBRATION_BUILD = ' + '{' + ', '.join(
            key + '=' + json.dumps(value) for key, value in info.items()) + '}\n'
        'import "CoreLibs/graphics"\n'
        # Catch import/startup failures too; update and serial remain installed.
        'local ok, problem = pcall(function()\n'
        '    import "game/bootTrace"\n'
        '    import "calibration"\n'
        'end)\n'
        'if not ok then\n'
        '    local failure = tostring(problem):sub(1, 320)\n'
        '    playdate.setAutoLockDisabled(true)\n'
        '    pcall(function()\n'
        '        local file = assert(playdate.file.open("calibration.json", playdate.file.kFileWrite))\n'
        '        file:write(json.encode({schema=1, build_id=DEVICE_TEST_ID, status="error", error=failure}))\n'
        '        file:flush()\n'
        '        file:close()\n'
        '    end)\n'
        '    function playdate.update()\n'
        '        playdate.graphics.clear(playdate.graphics.kColorWhite)\n'
        '        playdate.graphics.drawTextInRect("CALIBRATION ERROR\\n" .. failure, 8, 8, 384, 224)\n'
        '    end\n'
        '    function playdate.serialMessageReceived(message)\n'
        '        if message == "CAL1 ping" or message == "CAL1 status" then\n'
        '            print("CAL1 " .. json.encode({kind="status", build_id=DEVICE_TEST_ID, value={state="error", error=failure}}))\n'
        '        end\n'
        '    end\n'
        'end\n')
    (source / 'pdxinfo').write_text(
        'name=P0 Calibration USB Keeper\nauthor=PoC\n'
        'description=Synthetic calibration only; no gameplay acceptance\n'
        f'bundleID=com.poc.pokemon.calibration.{identity}\nversion=1.0\nbuildNumber=1\n')
    stage = output / 'build'
    stage.mkdir()
    bundle = output / 'Calibration.pdx'
    compile_production(output / 'input', sdk, bundle, stage)
    result = {
        'schema': 1, 'mode': 'calibration-compile-only', 'build_id': identity,
        'source_sha256': source_hash, 'sdk_version': sdk_version,
        'source_manifest': manifest(source), 'bundle_manifest': manifest(bundle),
        'compiler_sha256': digest((sdk / 'bin/pdc').read_bytes()),
        'bundle': str(bundle), 'execution': 'not performed',
        'work': {'block_work': 8, 'blocks_per_phase': 8192,
                 'phases': ['lua_compute', 'small_tables']},
    }
    (output / 'build.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def number(record, key, positive=False):
    value = record.get(key)
    if (isinstance(value, bool) or not isinstance(value, (int, float))
            or not math.isfinite(value) or value < 0 or (positive and value == 0)):
        raise ValueError(f'invalid measurement: {key}')
    return value


def compare(metadata, simulator=None, device=None, safety=2.0):
    result = {'schema': 1, 'build_id': metadata['build_id'],
              'status': 'unmeasured', 'game_gate': 'unverified', 'phases': [],
              'limitations': ['Synthetic Lua only; no map, battle, startup, native allocation or device capacity inference.',
                              'Active work uses SDK elapsed spans, not an OS process CPU clock.',
                              'Budgets are provisional with a safety multiplier, not a measured worst case.']}
    for expected, record in [('simulator', simulator), ('device', device)]:
        if record is None:
            continue
        for key in ('build_id', 'source_sha256', 'sdk_version'):
            if record.get(key) != metadata[key]:
                raise ValueError(f'{expected}: exact build mismatch: {key}')
        if record.get('timer_accuracy_us') != 1:
            raise ValueError(f'{expected}: timer configuration mismatch')
        if record.get('schema') != 1 or record.get('platform') != expected:
            raise ValueError(f'{expected}: schema/platform mismatch')
        if record.get('status') != 'complete' or record.get('error'):
            raise ValueError(f'{expected}: incomplete/error record')
        for key in ('block_work', 'blocks_per_phase'):
            if record.get(key) != metadata['work'][key]:
                raise ValueError(f'{expected}: work configuration mismatch')
        if [p.get('name') for p in record.get('phases', [])] != metadata['work']['phases']:
            raise ValueError(f'{expected}: phase list mismatch')
    if simulator is None or device is None:
        result['missing'] = [name for name, record in [('simulator', simulator), ('device', device)] if record is None]
        return result
    factors = []
    for sim, dev in zip(simulator['phases'], device['phases']):
        for record in (sim, dev):
            if (record.get('complete') is not True or record.get('blocks') != 8192
                    or record.get('work_count') != 65536):
                raise ValueError('incomplete or mismatched phase work')
            for key in ('inter_frame_ms', 'max_work_slice_ms', 'max_block_ms', 'zero_blocks'):
                number(record, key)
        if (type(sim.get('checksum')) is not int or type(dev.get('checksum')) is not int
                or sim['checksum'] != dev['checksum'] or not 0 <= sim['checksum'] < 65521):
            raise ValueError('phase checksum mismatch')
        sim_ms = number(sim, 'active_work_ms')
        dev_ms = number(dev, 'active_work_ms')
        row = {'name': sim['name'], 'simulator_active_work_ms': sim_ms,
               'device_active_work_ms': dev_ms,
               'simulator_inter_frame_ms': sim['inter_frame_ms'],
               'device_inter_frame_ms': dev['inter_frame_ms']}
        # Active span brackets each work update; block timers are diagnostics only.
        # A one-microsecond error at each span endpoint can dominate tiny spans.
        sim_tick_ms = max(0.001, number(simulator, 'timer_elapsed_s') * 1000 / 2**23)
        dev_tick_ms = max(0.001, number(device, 'timer_elapsed_s') * 1000 / 2**23)
        sim_uncertainty = 2 * sim_tick_ms * number(sim, 'frames', positive=True)
        dev_uncertainty = 2 * dev_tick_ms * number(dev, 'frames', positive=True)
        if sim_ms <= sim_uncertainty * 10 or dev_ms <= dev_uncertainty * 10:
            row['status'] = 'timer-limited; no factor'
        else:
            factor = dev_ms / sim_ms
            upper = (dev_ms + dev_uncertainty) / (sim_ms - sim_uncertainty)
            row.update(status='measured', device_over_simulator=factor,
                       conservative_factor=upper * safety)
            factors.append(upper * safety)
        result['phases'].append(row)
    if len(factors) == 2:
        conservative = max(1, *factors)
        result.update(status='synthetic pair measured', safety_multiplier=safety,
                      conservative_factor=conservative,
                      simulator_active_work_budget_ms={
                          'device_33ms': 33 / conservative,
                          'device_500ms': 500 / conservative,
                          'device_1000ms_ceiling': 1000 / conservative})
    else:
        result['status'] = 'timer-limited; no aggregate budget'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    compiler = commands.add_parser('build', help='SDK compile only; never launch or deploy')
    compiler.add_argument('--project', type=Path, default=PROJECT)
    compiler.add_argument('--sdk')
    compiler.add_argument('--output', type=Path, required=True)
    comparison = commands.add_parser('compare', help='read collected calibration.json files only')
    comparison.add_argument('--build', type=Path, required=True)
    comparison.add_argument('--simulator', type=Path)
    comparison.add_argument('--device', type=Path)
    comparison.add_argument('--safety', type=float, default=2.0)
    args = parser.parse_args()
    if args.command == 'build':
        report = build(args.project.expanduser().resolve(), sdk_path(args.sdk),
                       args.output.expanduser().resolve())
    else:
        if not math.isfinite(args.safety) or args.safety < 2:
            parser.error('--safety must be finite and at least 2')
        load = lambda path: json.loads(path.read_text()) if path else None
        report = compare(load(args.build), load(args.simulator), load(args.device), args.safety)
    print(json.dumps(report, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
