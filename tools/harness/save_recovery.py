#!/usr/bin/env python3
"""Qualify Title -> confirmed New Game -> Save -> actual-process Continue.

Dedicated initial corruption seeder; intentionally outside automatic scenarios.
Uses normal harness preparation, locks, lifecycle and output qualification. No
Source overlays, fixtures, production Data or runtime work happen on import.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
import uuid

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness import restarting, run as harness
from tools.harness.protocol import ProtocolError, atomic_json
from tools.harness.save_recovery_evidence import SEED, verify_run


def seeded_restart(args, scenario, metadata, output, data, owner, runner):
    restarting.check_owner(owner, data)
    session = metadata['session_id']
    if (uuid.UUID(hex=session).hex != session
            or metadata['bundle_id'] != 'com.poc.pokemon.harness.' + session
            or data.resolve() != Path(metadata['data_dir']).resolve()):
        raise ProtocolError('save recovery requires an exact private UUID bundle')
    if {path.name for path in data.iterdir()} != {'owner.lock'}:
        raise ProtocolError('refuse to seed any preexisting private Data files')
    for role, raw in SEED.items():
        with (data / ('adventure.' + role + '.json')).open('xb') as stream:
            stream.write(raw)
    atomic_json(output / 'seeded-artifacts.json', {
        role: {'length': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
        for role, raw in SEED.items()})
    code = _normal_restart(args, scenario, metadata, output, data, owner, runner)
    if code == 0:
        try:
            proof = verify_run(output)
        except (OSError, ValueError, KeyError, TypeError) as error:
            atomic_json(output / 'outcome.json', {
                'ok': False, 'session_id': session,
                'error': 'save-recovery-proof-failed', 'detail': str(error)})
            return 1
        atomic_json(output / 'native-recovery-proof.json', proof)
    return code


# Assigned only inside main's bounded runner call. Keeping the normal function
# separate avoids recursion while the dedicated seeding wrapper is installed.
_normal_restart = restarting.run


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--sdk')
    parser.add_argument('--build-only', action='store_true')
    args = parser.parse_args(argv)
    options = SimpleNamespace(
        sdk=args.sdk, output=args.output,
        scenario=str(Path(__file__).with_name('cases') / 'save-recovery.json'),
        commands=[], build_only=args.build_only, timeout=120,
        ready_timeout=20, max_frames=2400)
    previous = restarting.run
    try:
        restarting.run = seeded_restart
        return harness.run(options)
    except (OSError, ValueError, subprocess.CalledProcessError, ProtocolError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        restarting.run = previous


if __name__ == '__main__':
    raise SystemExit(main())
