#!/usr/bin/env python3
"""Explicit cold-artifact plans. Execution stays disabled pending shared qualification."""
import argparse
from contextlib import ExitStack, contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import stat
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
LOCK_DIRECTORY = Path('/private/tmp')
LOCK_ORDER = ('storage-maintenance', 'suite', 'simulator', 'device')
MAX_METADATA_SECONDS = 30


class OwnerAttention(ValueError):
    pass


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


def parent_lock_descriptors():
    raw = os.environ.get('PI_ARTIFACT_LOCK_FDS', '')
    if not raw:
        return ()
    if any(not value.isdecimal() or int(value) < 3 for value in raw.split(',')):
        raise ValueError('invalid inherited lock descriptor chain')
    descriptors = tuple(dict.fromkeys(map(int, raw.split(','))))
    for descriptor in descriptors:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise ValueError('inherited lock descriptor is not a regular lock file')
    return descriptors


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
    if type(value.get('queue_enabled', False)) is not bool:
        raise ValueError('invalid queue execution gate')
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
    expected = candidate.get('expected_ok', False)
    if type(expected) is not bool or value.get('ok') is not expected:
        raise ValueError('terminal result differs from the explicitly reviewed proof')
    if proof.name == 'suite.json' and (value.get('complete') is not True or value.get('not_run')):
        raise ValueError('suite did not finish reporting its children')
    forbidden = forbidden_entries(source)
    if forbidden:
        raise ValueError('forbidden artifact content: ' + ', '.join(forbidden[:8]))


def forbidden_entries(source):
    """Inspect only the explicit source; do not follow links or remove anything."""
    def cannot_walk(error):
        raise error
    found = []
    device = source.lstat().st_dev
    for parent, directories, files in os.walk(source, followlinks=False, onerror=cannot_walk):
        if Path(parent).lstat().st_dev != device:
            raise ValueError('nested mount in explicit archive source')
        for name in directories + files:
            if name in ('.git', 'Docker.raw'):
                found.append(str(Path(parent) / name))
    return found


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
            partials = partial_rehearsals(source, archive_id)
            if partials:
                raise OwnerAttention('deferred-with-partial: ' + ', '.join(partials[:4]))
            command += ['restore', '--id', archive_id, '--rehearse']
        elif action == 'restore':
            if os.path.lexists(source):
                raise ValueError('restore never overwrites the original path')
            partials = partial_rehearsals(source, archive_id) + partial_original_restores(source)
            if partials:
                raise OwnerAttention('deferred-with-partial: ' + ', '.join(partials[:4]))
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
                LOCK_DIRECTORY / f'pokemon-playdate-{name}-{os.getuid()}.lock')))
        # Keep the same per-artifact fence when source is absent during restore.
        key = hashlib.sha256(str(EVIDENCE / candidate).encode()).hexdigest()[:24]
        descriptors.append(ownership.enter_context(inherited_lock(
            LOCK_DIRECTORY / f'pokemon-playdate-cold-{key}-{os.getuid()}.lock')))
        yield tuple(descriptors)


def call_shared(command, policy, descriptors, inherited, capture=False):
    helper = Path(policy['shared_helper'])
    if helper.is_symlink() or digest(helper) != policy['shared_helper_sha256']:
        raise ValueError('shared helper changed; obtain its qualified contract before use')
    all_descriptors = tuple(dict.fromkeys((*inherited, *descriptors)))
    environment = dict(os.environ, PI_ARTIFACT_LOCK_FDS=','.join(map(str, all_descriptors)))
    return subprocess.run(command, check=False, pass_fds=all_descriptors, env=environment,
                          capture_output=capture, text=capture,
                          # A metadata lookup can time out. Never kill an
                          # active copy/restore/release writer on an observation timer.
                          timeout=MAX_METADATA_SECONDS if capture and command[2] == 'list' else None)


def execute(action, candidate, archive_id):
    policy = read_policy()
    if not policy['execution_enabled']:
        raise ValueError('transfer execution disabled pending coordinator Playdate slot')
    inherited = parent_lock_descriptors()
    with producer_locks(candidate) as descriptors:
        policy = read_policy()
        if not policy['execution_enabled']:
            raise ValueError('archive policy was disabled before ownership')
        current = plan(action, candidate, archive_id, policy)
        # The shared owner performs remote checksum/pressure/service checks and
        # full restore/release validation. A nonzero result never advances here.
        return call_shared(current['argv'], policy, descriptors, inherited).returncode


def read_queue():
    if not QUEUE.exists():
        return {'schema': 1, 'jobs': {}}
    if QUEUE.is_symlink():
        raise ValueError('queue link refused')
    value = json.loads(QUEUE.read_text())
    if value.get('schema') != 1 or not isinstance(value.get('jobs'), dict):
        raise ValueError('invalid pending queue')
    if any(not isinstance(job, dict) for job in value['jobs'].values()):
        raise ValueError('invalid queued job')
    return value


def enqueue(candidate, review_note, archive_id=None):
    if not isinstance(review_note, str) or not 12 <= len(review_note.strip()) <= 1000:
        raise ValueError('explicit owner review note required')
    with producer_locks(candidate):
        policy = read_policy()
        source = source_path(candidate, policy)
        closed_proof(source, policy['candidates'][candidate])
        if archive_id:
            receipt(archive_id, source)
        state = read_queue()
        job = {'source': str(source), 'proof_sha256': policy['candidates'][candidate]['proof_sha256'],
               'review_note': review_note.strip(), 'status': 'pending', 'reviewed_at': time.time(),
               'archive_id': archive_id}
        if candidate in state['jobs']:
            prior = state['jobs'][candidate]
            if prior.get('source') != str(source) or prior.get('proof_sha256') != job['proof_sha256']:
                raise ValueError('existing queued source identity differs')
            if not archive_id:
                return prior
            prior.update(archive_id=archive_id, review_note=review_note.strip(), status='pending',
                         owner_attention=False, reviewed_at=time.time())
            atomic_json(QUEUE, state)
            return prior
        state['jobs'][candidate] = job
        atomic_json(QUEUE, state)
        return job


def maintenance_status():
    """Unlocked scheduler hook; any future drain calls execute outside its own fences."""
    policy = read_policy()
    state = read_queue()
    return {'mode': 'explicit-pi-archive-queue', 'automatic_transfers': False,
            'queue_enabled': policy.get('queue_enabled', False),
            'pending': sum(j.get('status') == 'pending' for j in state['jobs'].values()),
            'trigger_free_gib': policy.get('archive_minimum_free_gib', 70),
            'stop_free_gib': policy.get('archive_target_free_gib', 100),
            'free_gib': free_space_gib(),
            'status': 'inspection only; execute tick requires both canary/slot and queue gates',
            'broad_age_deletion': False}


def free_space_gib():
    info = os.statvfs(EVIDENCE)
    return info.f_bavail * info.f_frsize / 2**30


def partial_rehearsals(source, archive_id):
    # Qualified helper creates the double-dot form; also refuse a retained
    # single-dot form for this exact source and ID. Never descend or delete it.
    prefixes = tuple('.' * n + source.name + '.rehearsal-' + archive_id + '.restore-'
                     for n in (1, 2))
    target = '.' + source.name + '.rehearsal-' + archive_id
    return [str(p) for p in source.parent.iterdir()
            if p.name == target or p.name.startswith(prefixes)]


def partial_original_restores(source):
    # Original restore temps do not include an archive ID. Conservatively stop
    # for any adjacent restore temp belonging to this exact source name.
    prefix = '.' + source.name + '.restore-'
    return [str(p) for p in source.parent.iterdir() if p.name.startswith(prefix)]


def events(output):
    # This is a post-capture parse cap, not a hard subprocess buffer limit.
    if len(output) > 8 * 1024 * 1024:
        raise ValueError('shared metadata exceeds bounded queue reader')
    result = [json.loads(line) for line in output.splitlines() if line.strip()]
    if len(result) > 4096 or any(not isinstance(row, dict) for row in result):
        raise ValueError('invalid or excessive shared metadata')
    return result


def released_source(source, proof):
    stub = Path(str(source) + '.ARCHIVED.json')
    if os.path.lexists(source) or stub.is_symlink():
        raise OwnerAttention('archived receipt conflicts with local source state')
    value = json.loads(stub.read_text())
    if any(value.get(key) != proof.get(key) for key in ('id', 'source', 'project', 'manifest_sha256', 'status')):
        raise OwnerAttention('archive stub does not match successful release receipt')


def queue_phase(candidate, job, policy, descriptors, inherited):
    source = source_path(candidate, policy)
    if job.get('source') != str(source) or job.get('proof_sha256') != policy['candidates'][candidate]['proof_sha256']:
        raise OwnerAttention('queued source is not the reviewed allowlist entry')
    archive_id = job.get('archive_id')
    if not archive_id:
        # Receipt lookup is metadata-only through the shared API. It recovers
        # a copy whose parent exited before its ID reached our queue journal.
        lookup = call_shared([sys.executable, policy['shared_helper'], 'list'], policy,
                             descriptors, inherited, True)
        if lookup.returncode:
            raise RuntimeError('receipt lookup deferred: ' + lookup.stderr[-1000:])
        matches = [r for r in events(lookup.stdout)
                   if r.get('project') == 'playdate' and r.get('source') == str(source)]
        if len(matches) > 1:
            raise OwnerAttention('multiple receipts; owner must bind an explicit ID with enqueue')
        if matches:
            archive_id = job['archive_id'] = matches[0].get('id')
    proof = receipt(archive_id, source) if archive_id else None
    if proof and proof.get('status') == 'archived':
        released_source(source, proof)
        job['status'] = 'done'
        return {'action': None, 'status': 'already released'}
    if not proof:
        action = 'archive'
    elif proof.get('status') == 'copying':
        action = 'resume'
    elif proof.get('status') == 'verified':
        action = 'release' if proof.get('restore_rehearsed') is True else 'rehearse'
    else:
        raise OwnerAttention('ambiguous release/copy receipt state; owner recovery required')
    if action == 'rehearse':
        partials = partial_rehearsals(source, archive_id)
        if partials:
            job['partial_paths'] = partials
            raise OwnerAttention('deferred-with-partial: owner must handle the exact retained rehearsal')
    try:
        closed_proof(source, policy['candidates'][candidate])
    except (OSError, ValueError) as error:
        raise OwnerAttention('reviewed source proof is no longer valid: ' + str(error)) from error
    command = plan(action, candidate, archive_id, policy)['argv']
    job.update(last_action=action, phase_started_at=time.time())
    state = read_queue()
    state['jobs'][candidate] = job
    atomic_json(QUEUE, state)  # Intent survives an interrupted helper/parent.
    result = call_shared(command, policy, descriptors, inherited, True)
    log = QUEUE.parent / 'pi-archive-steps' / (str(time.time_ns()) + '-' + action)
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.with_suffix('.stdout').open('x') as stream:
        stream.write(result.stdout)
    with log.with_suffix('.stderr').open('x') as stream:
        stream.write(result.stderr)
    job['last_log'] = str(log)
    values = events(result.stdout)
    if any('restore_incomplete' in row for row in values):
        job['partial_paths'] = partial_rehearsals(source, archive_id)
        raise OwnerAttention('deferred-with-partial: interrupted rehearsal retained; no automatic retry')
    if result.returncode:
        raise RuntimeError('shared phase deferred: ' + result.stderr[-1000:])
    replies = [r for r in values if r.get('project') == 'playdate' and r.get('source') == str(source)]
    if not replies:
        raise ValueError('phase returned no source-bound receipt')
    archive_id = job['archive_id'] = replies[-1].get('id')
    after = receipt(archive_id, source)
    if after.get('manifest_sha256') != replies[-1].get('manifest_sha256'):
        raise ValueError('persisted receipt differs from phase reply')
    if action == 'release':
        if after.get('status') != 'archived':
            raise OwnerAttention('release has no successful archived receipt')
        released_source(source, after)
        job['status'] = 'done'
    elif after.get('status') != 'verified' or (action == 'rehearse' and after.get('restore_rehearsed') is not True):
        raise ValueError('phase did not publish its required verified/rehearsed state')
    job.pop('last_error', None)
    return {'action': action, 'status': job['status'], 'archive_id': archive_id}


def maintenance_tick():
    """One data phase per tick; never called inside pre-held producer fences."""
    policy = read_policy()
    if policy.get('queue_enabled') is not True or policy['execution_enabled'] is not True:
        return dict(maintenance_status(), status='disabled pending real canary/transport slot')
    initial = read_queue()
    eligible = [name for name, job in initial['jobs'].items()
                if job.get('status') == 'pending' and not job.get('owner_attention')]
    if not eligible:
        return {'status': 'no approved eligible pending jobs', 'automatic_transfers': False,
                'needs_owner_review': [name for name, job in initial['jobs'].items()
                                       if job.get('status') == 'pending' and job.get('owner_attention')]}
    candidate = min(eligible, key=lambda name: initial['jobs'][name].get('last_attempt_at', 0))
    inherited = parent_lock_descriptors()
    try:
        with producer_locks(candidate) as descriptors:
            policy = read_policy()
            if policy.get('queue_enabled') is not True or policy['execution_enabled'] is not True:
                return {'status': 'disabled before ownership', 'automatic_transfers': False}
            state = read_queue()
            job = state['jobs'][candidate]
            if job.get('status') != 'pending' or job.get('owner_attention'):
                return {'status': 'job changed before ownership', 'automatic_transfers': False}
            free = free_space_gib()
            active = state.get('active_cycle') is True
            if free < policy.get('archive_minimum_free_gib', 70):
                active = True
            if free >= policy.get('archive_target_free_gib', 100):
                active = False
            state['active_cycle'] = active
            if not active:
                atomic_json(QUEUE, state)
                return {'status': 'reserve outside archive cycle', 'free_gib': free, 'automatic_transfers': False}
            job['last_attempt_at'] = time.time()
            atomic_json(QUEUE, state)
            try:
                outcome = queue_phase(candidate, job, policy, descriptors, inherited)
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                job['last_error'] = str(error)
                if isinstance(error, OwnerAttention):
                    job['owner_attention'] = True
                outcome = {'status': 'deferred-with-partial' if job.get('partial_paths') else 'deferred',
                           'reason': str(error), 'automatic_transfers': False}
            state['jobs'][candidate] = job
            atomic_json(QUEUE, state)
            return dict(outcome, candidate=candidate)
    except (OSError, ProtocolError) as error:
        return {'status': 'deferred: producer busy', 'reason': str(error), 'automatic_transfers': False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('archive', 'verify', 'rehearse', 'release', 'restore', 'resume', 'enqueue', 'maintenance', 'preflight'))
    parser.add_argument('candidate', nargs='?', help='exact name from the committed allowlist')
    parser.add_argument('--id', dest='archive_id')
    parser.add_argument('--review-note', help='explicit owner-reviewed cold-artifact decision for enqueue')
    parser.add_argument('--execute', action='store_true', help='disabled until shared qualification closes')
    args = parser.parse_args(argv)
    try:
        if args.action == 'preflight':
            policy = read_policy()
            source = source_path(args.candidate, policy)
            closed_proof(source, policy['candidates'][args.candidate])
            print(json.dumps({'source': str(source), 'forbidden_entries': [],
                              'network': False, 'locks_acquired': False}, indent=2))
            return 0
        if args.action == 'maintenance':
            print(json.dumps(maintenance_tick() if args.execute else maintenance_status(), indent=2))
            return 0
        if args.action == 'enqueue':
            if args.execute:
                print(json.dumps(enqueue(args.candidate, args.review_note, args.archive_id), indent=2))
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
