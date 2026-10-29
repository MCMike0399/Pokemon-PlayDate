#!/usr/bin/env python3
"""Root-only short exact-PDX proof; default is local artifact verification only."""
import argparse
import json
import errno
import os
import pty
import select
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
                  owned_child_reaped=False, pty_eof=False, publication_confirmed=False)
    process, master = None, None
    with OwnerLock(run.runtime_lock_path(sdk)), OwnerLock(run.device_lock_path()):
        run.simulator_preflight()  # Real pool and USB ownership checks, unchanged.
        settings = Path.home()/'Library/Preferences/com.panic.Playdate Simulator.ini'
        raw_settings = settings.read_bytes()
        values = dict(line.split('=', 1) for line in raw_settings.decode().splitlines() if '=' in line)
        pool = int(values['MallocPoolSize'])
        require(pool == 16645684, 'measured Simulator pool is not 16 MB')
        (output/'malloc-preflight.ini').write_bytes(raw_settings)
        report.update(malloc_pool_mb=16, malloc_pool_preflight=pool,
                      malloc_preflight_sha256=sha(output/'malloc-preflight.ini'))
        data.mkdir(parents=True, exist_ok=False)
        with (output/'simulator.log').open('wb', buffering=0) as log:
            def drain(wait=0):
                if master is None or report['pty_eof']:
                    return
                while select.select([master], [], [], wait)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        chunk = b''  # macOS PTY EOF after owned slave closes
                    if not chunk:
                        report['pty_eof'] = True
                        return
                    log.write(chunk)
                    wait = 0
            try:
                for row in build['earned_slots']:
                    copy_verified(stage/'earned-slots'/row['file'], data/row['file'], row['sha256'])
                atomic_json(data/'soak-simulator-profile.json', {'profile': 'simulator-short-v1'})
                master, slave = pty.openpty()
                try:
                    process = subprocess.Popen([str(sdk/'bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator'), build['bundle']],
                                               stdout=slave, stderr=subprocess.STDOUT, close_fds=True)
                finally:
                    os.close(slave)  # EOF must depend solely on owned child
                atomic_json(output/'run.json', dict(report, simulator_pid=process.pid, capture='owned-child-pty'))
                deadline = time.monotonic()+timeout
                while True:
                    drain(0.25)
                    require(process.poll() is None, 'owned Simulator exited')
                    # DONE is emitted only after complete IO, safety publication,
                    # receipt IO, the retained guard and raw terminal assertions.
                    if ('SOAK-DONE '+build['build_id']+'\n') in (output/'simulator.log').read_text():
                        rows(data, build, short=True)
                        console_rows(output/'simulator.log', data)
                        report['publication_confirmed'] = True
                        break
                    require(time.monotonic() < deadline, 'short proof timed out before complete publication')
            except Exception as error:
                report['error'] = str(error)
            finally:
                # Drain while stopping, not after a potentially blocked wait.
                if process is not None:
                    if process.poll() is None:
                        process.terminate()
                    stop = time.monotonic()+3
                    while process.poll() is None and time.monotonic() < stop:
                        drain(0.05)
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=3)  # confirmed owned PID cleanup is mandatory
                    report['owned_child_reaped'] = True
                    stop = time.monotonic()+3
                    while not report['pty_eof'] and time.monotonic() < stop:
                        drain(0.05)
                if master is not None:
                    os.close(master)
        shutil.copytree(data, output/'runtime-data')
        report['runtime_files'] = inventory(output/'runtime-data')
        report['simulator_log_sha256'] = sha(output/'simulator.log')
        try:
            require(verify(stage) == build, 'build changed during proof')
            require(report['publication_confirmed'] and report['owned_child_reaped'] and report['pty_eof'], 'unconfirmed publication/owned cleanup')
            report['measurements'] = rows(output/'runtime-data', build, short=True)
            console_rows(output/'simulator.log', output/'runtime-data')
            log_text = (output/'simulator.log').read_text().lower()
            require(not any(word in log_text for word in ('booterror', 'not enough memory', 'update failed')), 'Simulator error log')
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
