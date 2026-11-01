#!/usr/bin/env python3
"""Explicit cold-artifact plans. Execution stays disabled pending shared qualification."""
import argparse
from contextlib import ExitStack, contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness.protocol import OwnerLock, ProtocolError, atomic_json

POLICY = Path(__file__).with_name('pi_archive_allowlist.json')
EVIDENCE = Path('/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence')
RECEIPTS = Path.home() / '.local/state/pi-artifacts'
QUEUE = EVIDENCE.parent / 'storage-maintenance-logs/pi-archive-queue.json'
LOCK_ORDER = ('storage-maintenance', 'suite', 'simulator', 'device')


@contextmanager
def inherited_lock(path):
    owner = OwnerLock(path)
    owner.__enter__()
    try:
        yield owner.stream.fileno()
    finally:
        # Do not explicitly LOCK_UN: children inheriting this open file
        # description must keep the lock if the wrapper is interrupted.
        owner.stream.close()


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def read_policy():
    value = json.loads(POLICY.read_text())
    if value.get('schema') != 1 or type(value.get('execution_enabled')) is not bool:
        raise ValueError('invalid archive policy')
    return value


def source_path(candidate, policy):
    if candidate not in policy['candidates'] or Path(candidate).name != candidate:
        raise ValueError('candidate is not explicitly allowlisted')
    if candidate in {'chain', 'player-packages', 'references', 'Source', 'Data', 'runtime-data'} or candidate in policy.get('keep_local_names', []):
        raise ValueError('active/current/pinned input must stay local')
    if EVIDENCE.resolve() != EVIDENCE or not EVIDENCE.is_dir() or EVIDENCE.is_mount():
        raise ValueError('evidence root must be an ordinary local directory')
    source = EVIDENCE / candidate
    if source.is_symlink() or source.resolve() != source or source.is_mount():
        raise ValueError('candidate path is aliased or mounted')
    return source


def closed_proof(source, candidate):
    proof = source / candidate['proof_file']
    if proof.is_symlink() or not proof.is_file() or digest(proof) != candidate['proof_sha256']:
        raise ValueError('closed-producer proof changed or is absent')
    value = json.loads(proof.read_text())
    if value.get('ok') is not False:
        raise ValueError('allowlist is restricted to the reviewed failed runs')
    if proof.name == 'suite.json' and (value.get('complete') is not True or value.get('not_run')):
        raise ValueError('suite did not finish reporting its children')


def receipt(archive_id, source):
    if not re.fullmatch(r'playdate-[0-9a-f]{32}', archive_id or ''):
        raise ValueError('explicit Playdate archive ID required')
    path = RECEIPTS / (archive_id + '.json')
    if path.is_symlink():
        raise ValueError('receipt link refused')
    value = json.loads(path.read_text())
    if (value.get('id') != archive_id or value.get('project') != 'playdate'
            or value.get('source') != str(source)
            or not re.fullmatch(r'[0-9a-f]{64}', value.get('manifest_sha256', ''))):
        raise ValueError('receipt does not bind this exact allowlisted source')
    return value


def plan(action, candidate, archive_id, policy):
    source = source_path(candidate, policy)
    helper = Path(policy['shared_helper'])
    command = [sys.executable, str(helper)]
    if action == 'archive':
        if archive_id:
            raise ValueError('archive creates its own ID; do not supply --id')
        closed_proof(source, policy['candidates'][candidate])
        command += ['archive', '--project', 'playdate', '--source', str(source), '--closed']
    else:
        proof = receipt(archive_id, source)
        if action == 'resume':
            closed_proof(source, policy['candidates'][candidate])
            if proof.get('status') != 'copying':
                raise ValueError('resume requires an interrupted copying receipt')
            command += ['resume', '--id', archive_id, '--closed']
        elif proof.get('status') not in ('verified', 'archived'):
            raise ValueError('receipt is not a verified or archived copy')
        elif action == 'release':
            closed_proof(source, policy['candidates'][candidate])
            if proof.get('status') != 'verified' or proof.get('restore_rehearsed') is not True:
                raise ValueError('release requires the full successful restore rehearsal')
            command += ['release', '--id', archive_id, '--closed']
        elif action == 'rehearse':
            command += ['restore', '--id', archive_id, '--rehearse']
        elif action == 'restore':
            if os.path.lexists(source):
                raise ValueError('restore never overwrites the original path')
            command += ['restore', '--id', archive_id]
        else:
            command += ['verify', '--id', archive_id]
    return {'action': action, 'source': str(source), 'argv': command,
            'execution_enabled': policy['execution_enabled'],
            'locks': [f'/private/tmp/pokemon-playdate-{name}-{os.getuid()}.lock'
                      for name in LOCK_ORDER]}


@contextmanager
def producer_locks(candidate):
    with ExitStack() as ownership:
        descriptors = []
        for name in LOCK_ORDER:
            descriptors.append(ownership.enter_context(inherited_lock(
                Path('/private/tmp') / f'pokemon-playdate-{name}-{os.getuid()}.lock')))
        # Keep the same per-artifact fence when source is absent during restore.
        key = hashlib.sha256(str(EVIDENCE / candidate).encode()).hexdigest()[:24]
        descriptors.append(ownership.enter_context(inherited_lock(
            Path('/private/tmp') / f'pokemon-playdate-cold-{key}-{os.getuid()}.lock')))
        yield tuple(descriptors)


def execute(action, candidate, archive_id):
    policy = read_policy()
    if not policy['execution_enabled']:
        raise ValueError('transfer execution disabled pending coordinator Playdate slot')
    with producer_locks(candidate) as descriptors:
        policy = read_policy()
        if not policy['execution_enabled']:
            raise ValueError('archive policy was disabled before ownership')
        current = plan(action, candidate, archive_id, policy)
        helper = Path(policy['shared_helper'])
        if helper.is_symlink() or digest(helper) != policy['shared_helper_sha256']:
            raise ValueError('shared helper changed; obtain its qualified contract before use')
        # The shared owner performs remote checksum/pressure/service checks and
        # full restore/release validation. A nonzero result never advances here.
        environment = dict(os.environ, PI_ARTIFACT_LOCK_FDS=','.join(map(str, descriptors)))
        return subprocess.run(current['argv'], check=False, pass_fds=tuple(descriptors),
                              env=environment).returncode


def read_queue():
    if not QUEUE.exists():
        return {'schema': 1, 'jobs': {}}
    if QUEUE.is_symlink():
        raise ValueError('queue link refused')
    value = json.loads(QUEUE.read_text())
    if value.get('schema') != 1 or not isinstance(value.get('jobs'), dict):
        raise ValueError('invalid pending queue')
    return value


def enqueue(candidate, review_note):
    if not isinstance(review_note, str) or not 12 <= len(review_note.strip()) <= 1000:
        raise ValueError('explicit owner review note required')
    with producer_locks(candidate):
        policy = read_policy()
        source = source_path(candidate, policy)
        closed_proof(source, policy['candidates'][candidate])
        state = read_queue()
        job = {'source': str(source), 'proof_sha256': policy['candidates'][candidate]['proof_sha256'],
               'review_note': review_note.strip(), 'status': 'pending', 'reviewed_at': time.time()}
        if candidate in state['jobs']:
            prior = state['jobs'][candidate]
            if prior.get('source') != str(source) or prior.get('proof_sha256') != job['proof_sha256']:
                raise ValueError('existing queued source identity differs')
            return prior
        state['jobs'][candidate] = job
        atomic_json(QUEUE, state)
        return job


def maintenance_status():
    """Existing scheduler hook; deliberately no transfer processor before canary."""
    policy = read_policy()
    state = read_queue()
    info = os.statvfs(EVIDENCE)
    return {'mode': 'explicit-pi-archive-queue', 'automatic_transfers': False,
            'queue_enabled': False, 'pending': len(state['jobs']),
            'trigger_free_gib': policy.get('archive_minimum_free_gib', 70),
            'stop_free_gib': policy.get('archive_target_free_gib', 100),
            'free_gib': info.f_bavail * info.f_frsize / 2**30,
            'status': 'disabled: first real canary and queue processor/slot integration remain',
            'broad_age_deletion': False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('archive', 'verify', 'rehearse', 'release', 'restore', 'resume', 'enqueue', 'maintenance'))
    parser.add_argument('candidate', nargs='?', help='exact name from the committed allowlist')
    parser.add_argument('--id', dest='archive_id')
    parser.add_argument('--review-note', help='explicit owner-reviewed cold-artifact decision for enqueue')
    parser.add_argument('--execute', action='store_true', help='disabled until shared qualification closes')
    args = parser.parse_args(argv)
    try:
        if args.action == 'maintenance':
            print(json.dumps(maintenance_status(), indent=2))
            return 0
        if args.action == 'enqueue':
            if args.execute:
                print(json.dumps(enqueue(args.candidate, args.review_note), indent=2))
            else:
                policy = read_policy()
                source = source_path(args.candidate, policy)
                closed_proof(source, policy['candidates'][args.candidate])
                print(json.dumps({'would_enqueue': str(source), 'automatic_transfers': False}, indent=2))
            return 0
        if args.execute:
            return execute(args.action, args.candidate, args.archive_id)
        print(json.dumps(plan(args.action, args.candidate, args.archive_id, read_policy()), indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, ProtocolError) as error:
        print('Playdate archive deferred: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
