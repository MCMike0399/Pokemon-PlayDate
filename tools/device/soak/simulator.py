#!/usr/bin/env python3
"""Root-only short exact-PDX proof; default is local artifact verification only."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.device.soak.evidence import verify, rows, require, console_rows
from tools.device_cycle import copy_verified, sha, inventory
from tools.harness import run
from tools.harness.protocol import OwnerLock, atomic_json


def execute(stage, sdk, output, timeout):
    build = verify(stage)
    require(sha(sdk/'bin/pdc') == build['compiler_sha256'] and (sdk/'VERSION.txt').read_text().strip() == build['sdk_version'], 'SDK mismatch')
    output.mkdir(parents=True, exist_ok=False)
    data = sdk/'Disk/Data'/build['bundle_id']
    report = dict(build=build, status='failed', hardware_soak_accepted=False,
                  malloc_pool_mb=16, malloc_pool_preflight=16645684)
    process = None
    with OwnerLock(run.runtime_lock_path(sdk)), OwnerLock(run.device_lock_path()):
        run.simulator_preflight()  # Includes real SDK MallocPoolSize and USB ownership checks.
        data.mkdir(parents=True, exist_ok=False)
        try:
            for row in build['earned_slots']:
                copy_verified(stage/'earned-slots'/row['file'], data/row['file'], row['sha256'])
            atomic_json(data/'soak-simulator-profile.json', {'profile': 'simulator-short-v1'})
            with (output/'simulator.log').open('w') as log:
                process = subprocess.Popen([str(sdk/'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'), build['bundle']], stdout=log, stderr=subprocess.STDOUT)
                atomic_json(output/'run.json', dict(report, simulator_pid=process.pid))
                deadline = time.monotonic()+timeout
                while True:
                    require(process.poll() is None, 'owned Simulator exited')
                    sample = data/'soak-minute.jsonl'
                    if sample.exists():
                        lines = sample.read_text().splitlines()
                        # Incomplete final writes are retried; only complete newline rows count.
                        if sample.read_bytes().endswith(b'\n') and lines:
                            last = json.loads(lines[-1])
                            require(last['kind'] != 'error', 'sampler failed')
                            if last['kind'] == 'complete':
                                break
                    require(time.monotonic() < deadline, 'short proof timed out')
                    time.sleep(0.25)
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
            shutil.copytree(data, output/'runtime-data')
            report['runtime_files'] = inventory(output/'runtime-data')
            report['simulator_log_sha256'] = sha(output/'simulator.log') if (output/'simulator.log').exists() else None
            try:
                require(verify(stage) == build, 'build changed during proof')
                report['measurements'] = rows(output/'runtime-data', build, short=True)
                console_rows(output/'simulator.log', output/'runtime-data')
                log = (output/'simulator.log').read_text().lower()
                require(not any(word in log for word in ('booterror', 'not enough memory', 'update failed')), 'Simulator error log')
                if not report.get('error'):
                    report['status'] = 'simulator-soak-proof-passed'
            except Exception as error:
                report['validation_error'] = str(error)
            atomic_json(output/'simulator-soak-proof.json', report)
    require(report['status'] == 'simulator-soak-proof-passed', 'proof failed; inspect '+str(output))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-stage', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path('~/Developer/PlaydateSDK'))
    parser.add_argument('--execute-root', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    stage = args.build_stage.expanduser().resolve()
    if args.execute_root:
        if not args.output:
            parser.error('--output required')
        print(json.dumps(execute(stage, args.sdk.expanduser().resolve(), args.output.expanduser().resolve(), 240), indent=2))
    else:
        print(json.dumps({'status': 'verified-not-executed', 'build_id': verify(stage)['build_id']}))
