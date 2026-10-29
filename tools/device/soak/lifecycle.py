"""Narrow root Cycle hooks. Requires the adjacent UNAPPLIED shared-owner patch.

No standalone runtime entry point. Persistent reservation is read/written only
under the existing device lock; ordinary Simulator owners never consult it.
Uncertain/failed attempts deliberately keep their reservation for root inspection.
"""
import json
from pathlib import Path
import time
import uuid
from tools.harness.protocol import atomic_json
from tools.harness.run import device_lock_path, simulator_usb_preflight
from tools.device_cycle import inventory, tree_hash, sha, plain_path, IDENTITY
from tools.device.soak.evidence import admission, verify, rows, require


def reservation_path():
    return Path(str(device_lock_path())+'.soak.json')


def enter(cycle, manifest):
    """Called under BOTH ordinary locks, before ANY device command or copy."""
    path = reservation_path()
    args = cycle.args
    collect = getattr(args, 'soak_collect', None)
    launch = getattr(args, 'soak_launch', False)
    require(not (launch and collect), 'choose launch or collect')
    require(not (launch or collect) or getattr(args, 'soak_proof', None), 'soak flags require exact soak proof')
    if path.exists():
        record = json.loads(path.read_text())
        require(collect and str(Path(collect).resolve()) == record['launch_output'],
                'live/uncertain soak reserves device: root must collect this exact attempt first')
        require(record['build'] == manifest['build'] and record['manifest_sha256'] == tree_hash(manifest), 'attempt/build changed')
        require(record['state'] == 'running', 'uncertain launch/collection; stop device queue, root inspection required')
        cycle.soak_reservation = record
    else:
        require(not collect, 'no live soak reservation')
        if launch:
            record = dict(attempt=uuid.uuid4().hex, state='launching', launch_output=str(cycle.output.resolve()),
                          build=manifest['build'], manifest_sha256=tree_hash(manifest), created_ns=time.time_ns())
            # Atomic publication; no expiry or automatic cleanup on failure.
            atomic_json(path, record)
            cycle.soak_reservation = record
            atomic_json(cycle.output/'soak-attempt.json', record)


def launched(cycle):
    """pdutil subprocess has exited: it owns no persistent serial descriptor."""
    require(cycle.select_serial(), 'device needs one A press; USB disappeared; stop device queue')
    simulator_usb_preflight()  # Fail if any reader still owns the port.
    record = cycle.soak_reservation
    record.update(state='running', launched_ns=time.time_ns(), serial_port=cycle.serial, volume=str(cycle.volume))
    atomic_json(reservation_path(), record)
    atomic_json(cycle.output/'soak-attempt.json', record)
    cycle.event('soak-launched', attempt=record['attempt'], note='no readers; returning releases both locks')


def collect(cycle, installed, data, payload):
    record = cycle.soak_reservation
    launch = Path(record['launch_output'])
    require(json.loads((launch/'soak-attempt.json').read_text()) == record, 'launch attempt identity changed')
    cycle.ran = True
    require(cycle.select_serial(), 'device needs one A press; USB disappeared; stop device queue')
    require(cycle.serial == record['serial_port'] and str(cycle.volume) == record['volume'], 'device/volume differs from launch')
    simulator_usb_preflight()
    # Never reset or rerun the app. One owned data-disk entry stops sampling.
    record['state'] = 'collecting'
    atomic_json(reservation_path(), record)
    cycle.disk()
    actual = cycle.archive('after', installed, data)
    require(actual == payload, 'exact installed PDX changed')
    require(json.loads((data/IDENTITY).read_text()) == json.loads((launch/'manifest.json').read_text()), 'installed identity changed')
    before = json.loads((launch/'before/logs.json').read_text())
    after = json.loads((cycle.output/'after/logs.json').read_text())
    for name in set(before) | set(after):
        if name.endswith(('errorlog.txt', 'crashlog.txt')):
            require(before.get(name) == after.get(name), 'error/crash logs changed; stop device queue')
    require(not (data/'soak-simulator-profile.json').exists(), 'Simulator profile on hardware')
    result = rows(cycle.output/'after'/data.relative_to(cycle.volume), record['build'], short=False)
    result.update(attempt=record['attempt'], build_id=record['build']['build_id'], installed_pdx_sha256=tree_hash(actual))
    atomic_json(cycle.output/'soak-result.json', result)
    record.update(state='collected', collection_output=str(cycle.output.resolve()))
    atomic_json(cycle.output/'soak-attempt.json', record)
    reservation_path().unlink()  # Only after every acceptance check; errors retain the reservation.
    cycle.event('soak-collected', **result)


def validate_mode(args, stage):
    require(bool(getattr(args, 'soak_launch', False)) != bool(getattr(args, 'soak_collect', None)), 'soak proof requires exact launch/collect mode')
    require(not getattr(args, 'leave_running', False) and not getattr(args, 'clear_boot_trace', False)
            and not getattr(args, 'calibration_build', None) and not getattr(args, 'safety_only', False), 'incompatible soak flags')
    require(args.earned_save, 'exact earned manifest required')
    build = verify(stage)
    earned = json.loads(Path(args.earned_save).read_text())
    require(earned == json.loads((stage/'earned-save.json').read_text()), 'earned identity differs from compiled packet')
