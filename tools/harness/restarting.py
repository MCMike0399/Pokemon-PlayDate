"""Owned multi-process jobs. No Simulator or filesystem work at import time."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

from tools.harness.protocol import Client, ProtocolError, atomic_json

# Only these protocol publications are removed between stopped processes.
TRANSIENT = frozenset({'ready.json', 'heartbeat.json', 'request.json', 'result.json',
                       'rejected.json', 'cancel.json', 'runtime-error.json', 'captures-final.json',
                       'catalog-invariance-before.json', 'catalog-invariance-after.json',
                       'journey-history-pause.json', 'journey-history-ack.json', 'journey-startup-request.json'})


class UnconfirmedExit(ProtocolError):
    """Keep private Data when its owned producer cannot be confirmed dead."""


def validate(scenario, qualification=False):
    if 'processes' not in scenario:
        return
    if qualification or any(key in scenario for key in ('commands', 'requests', 'journey', 'outputs')):
        raise ProtocolError('processes cannot mix with commands/requests/journey/outputs/qualification')
    if set(scenario) - {'processes', 'initial_save'}:
        raise ProtocolError('unknown process scenario fields')
    groups = scenario['processes']
    if not isinstance(groups, list) or not 2 <= len(groups) <= 8:
        raise ProtocolError('processes requires 2..8 process groups')
    first = groups[0].get('journey', {}) if isinstance(groups[0], dict) else {}
    if first.get('name') == 'midgame-natural':
        from tools.harness.midgame_journey import validate_scenario
        validate_scenario(scenario)
        return
    if first.get('name') == 'vermilion-natural':
        starting = scenario.get('initial_save', {})
        if (not isinstance(starting, dict) or set(starting) != {'milestone', 'starter'}
                or starting['milestone'] not in {'5.3', '5.4'}
                or starting['starter'] != first.get('starter', 'squirtle')):
            raise ProtocolError('Vermilion requires its Cerulean save or an earned checkpoint')
        # Exact slot hashes and the accepted Cerulean origin are checked before boot.
    for index, group in enumerate(groups):
        if not isinstance(group, dict) or set(group) - {'restart', 'requests', 'journey', 'outputs'}:
            raise ProtocolError('invalid process group fields')
        if (index == 0 and 'restart' in group) or (index > 0 and group.get('restart') is not True):
            raise ProtocolError('each later process group requires restart:true; first cannot restart')
        if ('requests' in group) == ('journey' in group):
            raise ProtocolError('process group requires exactly one of requests or known journey')
        if 'requests' in group:
            requests = group['requests']
            if not isinstance(requests, list) or not requests or any(not isinstance(value, list) or not value for value in requests):
                raise ProtocolError('process requests requires nonempty command arrays')
        else:
            journey=group['journey']
            allowed={'name','starter','seed','max_actions','max_steps','max_encounters','location','training_level','max_training_battles','max_capture_attempts','max_blackouts','evolution_policy','fossil','max_transitions','max_puzzle_attempts','case','supplementary'}
            if isinstance(journey,dict) and isinstance(journey.get('name'),str) and journey['name'].startswith('vermilion-'):
                allowed = allowed | {'content_scope', 'vermilion_actions','collection_steps','collection_battles','collection_phase_battles','collection_balls','collection_ball_stock','collection_balls_per_battle','collection_money_reserve'}
            if not isinstance(journey,dict) or set(journey)-allowed or journey.get('name') not in {'brock-natural','brock-continue','npc-motion-save','npc-motion-continue','cerulean-natural','cerulean-continue','vermilion-natural','vermilion-continue','vermilion-supplementary','vermilion-supplementary-continue'}:
                raise ProtocolError('unknown or malformed process journey')
            name=journey['name']
            if not name.startswith('vermilion-') and set(journey) & {'max_puzzle_attempts','case','supplementary'}:
                raise ProtocolError('Vermilion options cannot mix with earlier journeys')
            if name.startswith('npc-motion'):
                if set(journey)&{'training_level','max_training_battles','max_capture_attempts','max_blackouts','evolution_policy'}:raise ProtocolError('Brock options cannot mix with NPC motion')
                from tools.harness.motion_journey import validate_config
                validate_config(journey)
                if name=='npc-motion-save' and index!=0:
                    raise ProtocolError('motion Save must be first process')
                if name=='npc-motion-continue' and (index==0 or groups[index-1].get('journey',{}).get('name') not in {'npc-motion-save','npc-motion-continue'}):
                    raise ProtocolError('motion Continue requires prior saved motion receipt')
            elif name.startswith('vermilion-'):
                from tools.harness.vermilion_journey import validate_process_journey
                validate_process_journey(journey,index,groups[index-1].get('journey',{}) if index else {})
            elif name.startswith('cerulean-'):
                from tools.harness.cerulean_journey import validate_process_journey
                validate_process_journey(journey,index,groups[index-1].get('journey',{}) if index else {})
            else:
                if set(journey)&{'fossil','max_transitions'}:raise ProtocolError('Cerulean options cannot mix with Brock')
                if 'location' in journey:raise ProtocolError('location is only supported for NPC motion')
                if journey.get('evolution_policy','accept')not in {'accept','cancel'}:raise ProtocolError('invalid Brock evolution policy')
                if name=='brock-natural' and index!=0:
                    raise ProtocolError('new-game journey must be first process')
                if name=='brock-continue' and (index==0 or groups[index-1].get('journey',{}).get('name') not in {'brock-natural','brock-continue'}):
                    raise ProtocolError('Continue journey requires prior saved journey receipt')
                for name,low,high in [('seed',-2147483648,2147483647),('max_actions',1,20000),('max_steps',1,5000),('max_encounters',1,64),('training_level',8,20),('max_training_battles',1,256),('max_capture_attempts',1,24),('max_blackouts',0,2)]:
                    if name in journey and (type(journey[name]) is not int or not low<=journey[name]<=high):
                        raise ProtocolError('invalid process journey bound: '+name)
                if journey.get('starter','squirtle')not in {'squirtle','bulbasaur','charmander'}:raise ProtocolError('Brock journey requires an original Kanto starter')
        outputs = group.get('outputs', [])
        if not isinstance(outputs, list):
            raise ProtocolError('process outputs requires an array')
        for value in outputs:
            if not isinstance(value, str) or not value or Path(value).is_absolute() or '..' in Path(value).parts:
                raise ProtocolError('invalid process output path')



def read_receipt(reference, metadata):
    if not isinstance(reference,dict) or set(reference)!={'path','sha256'}:
        raise ProtocolError('missing prior immutable journey receipt')
    path=Path(reference['path'])
    if path.is_symlink() or not path.is_file():raise ProtocolError('missing prior immutable journey receipt')
    raw=path.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=reference['sha256']:raise ProtocolError('prior journey receipt changed')
    try:packet=json.loads(raw)
    except (UnicodeDecodeError,ValueError) as error:raise ProtocolError('malformed prior journey receipt')from error
    if not isinstance(packet,dict)or set(packet)!={'schema','kind','build_id','session_id','state'}or packet['schema']!=1 or packet['kind'] not in {'brock-saved','npc-motion-saved','cerulean-saved','vermilion-saved','midgame-saved'} or packet['build_id']!=metadata['build_id']or packet['session_id']!=metadata['session_id']:
        raise ProtocolError('wrong-build or malformed prior journey receipt')
    if packet["kind"] == "midgame-saved":
        from tools.harness.midgame_journey import validate_receipt_state
        validate_receipt_state(packet["state"])
    if packet["kind"]=="vermilion-saved":
        from tools.harness.vermilion_journey import validate_receipt_state
        validate_receipt_state(packet["state"])
    if packet["kind"]=="cerulean-saved":
        from tools.harness.cerulean_journey import validate_receipt_state
        validate_receipt_state(packet["state"])
    if packet["kind"]=="npc-motion-saved":
        from tools.harness.motion_journey import validate_receipt_state
        validate_receipt_state(packet["state"])
    return packet


def check_owner(owner, data):
    if owner.path.resolve() != (data / 'owner.lock').resolve() or owner.stream is None or owner.stream.closed:
        raise ProtocolError('restart requires the same live private owner lock')


def stop_owned(process, owner, data):
    """Only a Popen handle created by this job is signalled; confirm exit."""
    check_owner(owner, data)
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired as error:
                raise UnconfirmedExit("owned Simulator exit unconfirmed; private Data retained") from error
    if process.poll() is None:
        raise UnconfirmedExit('owned Simulator exit unconfirmed; private Data retained')
    return process.returncode


def clear_handshake(data, owner):
    check_owner(owner, data)
    for name in sorted(TRANSIENT):
        for path in (data / name, data / (name + '.tmp')):
            # Refuse directory/symlink substitution rather than traverse it.
            if path.is_symlink() or (path.exists() and not path.is_file()):
                raise ProtocolError('invalid transient protocol path: ' + path.name)
            path.unlink(missing_ok=True)
    if (data / 'ready.json').exists():
        raise ProtocolError('stale ready handshake remains')


def durable_hashes(data):
    result = {}
    for path in sorted(data.rglob('*')):
        relative = path.relative_to(data)
        if path.is_symlink():
            raise ProtocolError('private Data contains symlink: ' + relative.as_posix())
        if relative.parts[0] == 'recent' or relative.as_posix() in {'owner.lock', 'trace.jsonl', 'captures.jsonl', 'boot-trace.tsv'}:
            continue
        if relative.as_posix() in TRANSIENT or relative.as_posix() in {name + '.tmp' for name in TRANSIENT}:
            continue
        if path.is_file():
            result[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def archive_generation(data, output, evidence, trace_start):
    # Called only after confirmed process exit; producers cannot overwrite copies.
    # Opening and closing another descriptor for a POSIX-locked inode releases
    # this process's record lock. Never read the live fence during archival.
    shutil.copytree(data, evidence / 'runtime-data',
                    ignore=lambda directory, names: {'owner.lock'} if Path(directory) == data else set())
    trace = data / 'trace.jsonl'
    content = trace.read_bytes() if trace.exists() else b''
    if trace_start > len(content):
        raise ProtocolError('runtime trace was truncated across restart')
    (evidence / 'trace.jsonl').write_bytes(content[trace_start:])
    if (output / 'frames').exists():
        shutil.move(str(output / 'frames'), evidence / 'frames')
    (output / 'frames').mkdir()
    for name in ('captures.json', 'catalog.json', 'artifact-finalization.json'):
        path = output / name
        if path.exists():
            shutil.move(str(path), evidence / name)
    return len(content)


def import_chain_save(scenario, project, data, output):
    spec = scenario.get('initial_save')
    if spec is None:
        return None
    if (not isinstance(spec, dict) or set(spec) not in ({'milestone', 'starter'}, {'milestone', 'starter', 'resume'})
            or spec['milestone'] not in {'5.2', '5.3', '5.4', '5.5a', '5.5b'}
            or spec['starter'] not in {'bulbasaur', 'squirtle', 'charmander'}):
        raise ProtocolError('unknown starting save')
    first = scenario['processes'][0]['journey']
    expected = spec['milestone']
    if expected in {'5.5a', '5.5b'} and first.get('name') != 'midgame-natural':
        raise ProtocolError('accepted midgame starting save requires its next midgame packet')
    if first.get('name') == 'midgame-natural':
        from tools.harness.midgame_journey import validate_scenario
        validate_scenario(scenario)
    if first.get('name') == 'vermilion-natural' and expected not in {'5.3', '5.4'}:
        raise ProtocolError('Vermilion must start from Cerulean or its earned checkpoint')
    if (first.get('name') not in {'cerulean-natural', 'vermilion-natural', 'midgame-natural'}
            or first.get('starter') != spec['starter'] or spec['milestone'] != expected):
        raise ProtocolError('starting save does not match journey')
    manifest = json.loads((project / 'docs/validation/chain-saves.json').read_text())
    records = [row for row in manifest['saves'] if row['starter'] == spec['starter']
               and row['from_milestone'] == spec['milestone']]
    if len(records) != 1:
        raise ProtocolError('starting save requires exactly one chain record')
    record = records[0]
    if first['name'] == 'midgame-natural':
        from tools.harness.midgame_journey import validate_chain_record
        validate_chain_record(record, spec, project)
        if spec['milestone'] in {'5.5a', '5.5b'}:
            record = dict(record, accepted_boundary=accepted_midgame_boundary(record, project))
    if first['name'] == 'vermilion-natural':
        origin = record
        if spec['milestone'] == '5.4':
            if record.get('resume_checkpoint') is not True or record.get('origin_milestone') != '5.3':
                raise ProtocolError('in-progress save lacks its Cerulean origin')
            origin = next(row for row in manifest['saves']
                          if row['starter'] == spec['starter'] and row['from_milestone'] == '5.3')
        proof = json.loads((project / 'docs/validation/cerulean-acceptance-20261028.json').read_text())
        if (proof.get('milestone_accepted') is not True or proof.get('milestone') != '5.3'
                or origin.get('accepted_commit') != proof.get('accepted_main_code')
                or origin.get('accepted_source_sha256') != proof.get('source_sha256')
                or not any(row.get('starter') == spec['starter'] for row in proof.get('starters', []))):
            raise ProtocolError('starting save lacks accepted Cerulean proof')
    if 'resume' in spec:
        if first.get('name') != 'midgame-natural':
            raise ProtocolError('partial checkpoint resume is only supported for midgame')
        return import_midgame_partial(spec, first, record, project, data, output)
    if len(record['files']) != 2 or {item['file'] for item in record['files']} != {'adventure.a.json', 'adventure.b.json'}:
        raise ProtocolError('starting save must include both exact slots')
    contents = {}
    for item in record['files']:
        name = item['file']
        if name not in {'adventure.a.json', 'adventure.b.json'}:
            raise ProtocolError('unexpected starting save file')
        slot = Path(record['directory']) / name
        if slot.is_symlink() or not slot.is_file():
            raise ProtocolError('invalid accepted starting slot')
        content = slot.read_bytes()
        if hashlib.sha256(content).hexdigest() != item['sha256']:
            raise ProtocolError('accepted starting save checksum changed')
        contents[name] = content
    for name, content in contents.items():
        (data / name).write_bytes(content)
    atomic_json(output / 'starting-save.json', record)
    return record


def accepted_midgame_boundary(record, project, *, chain_manifest=None):
    """Bind accepted A/B bytes to earned ancestry and a stopped real Continue.

    Read only: no Simulator API, private Data owner, lock, or save edits.
    """
    from tools.harness.midgame_journey import validate_chain_record
    milestone = record['from_milestone']
    validate_chain_record(record, {'milestone': milestone, 'starter': record['starter']}, project)
    root = Path(record['source'])
    run = json.loads((root / 'run.json').read_bytes())
    outcome = json.loads((root / 'outcome.json').read_bytes())
    provenance = json.loads((Path(record['directory']) / 'provenance.json').read_bytes())
    wanted = {item['file']: item['sha256'] for item in record['files']}
    if len(record['files']) != 2 or set(wanted) != {'adventure.a.json', 'adventure.b.json'}:
        raise ProtocolError('accepted A requires both exact slot hashes')
    if (outcome.get('ok') is not True or outcome.get('session_id') != run.get('session_id')
            or provenance.get('evidence') != str(root) or provenance.get('files') != record['files']
            or provenance.get('milestone') != milestone or provenance.get('starter') != record['starter']
            or provenance.get('source_sha256') != record['journey_source_sha256']
            or provenance.get('build_id') != run.get('build_id')):
        raise ProtocolError('accepted A producer/provenance binding differs')
    manifest_path = Path(project) / 'docs/validation/chain-saves.json'
    manifest_bytes = manifest_path.read_bytes() if chain_manifest is None else chain_manifest
    manifest = json.loads(manifest_bytes)
    ancestors = [row for row in manifest['saves'] if row['starter'] == record['starter']
                 and row['from_milestone'] == ('5.5a' if milestone == '5.5b' else '5.4')]
    prior = provenance.get('starting_save', {})
    ignored = {'resume', 'accepted_boundary'} if milestone == '5.5b' else {'resume'}
    if len(ancestors) != 1 or {k: v for k, v in prior.items() if k not in ignored} != ancestors[0]:
        raise ProtocolError('accepted boundary lacks exact earned previous milestone ancestry')
    validate_chain_record(ancestors[0], {'milestone': ancestors[0]['from_milestone'], 'starter': record['starter']}, project)
    if milestone == '5.5b':
        # The producer used a pre-B chain manifest. Verify that immutable Git
        # object; never replace its frozen hash with today's enlarged manifest.
        producer_commit = run['build_id'].split(':')[0]
        historical = subprocess.check_output(['git', '-C', str(project), 'show',
                                              producer_commit + ':docs/validation/chain-saves.json'])
        if prior.get('accepted_boundary') != accepted_midgame_boundary(
                ancestors[0], project, chain_manifest=historical):
            raise ProtocolError('accepted B frozen A authority differs')
        proof = json.loads((Path(project) / record['acceptance']).read_bytes())
        authority = next(row for row in proof['starters'] if row['starter'] == record['starter'])
        for filename, field in [('run.json', 'run_sha256'), ('outcome.json', 'outcome_sha256')]:
            if hashlib.sha256((root / filename).read_bytes()).hexdigest() != authority[field]:
                raise ProtocolError('accepted B producer evidence checksum changed')
        if run.get('build_id') != authority['build_id']:
            raise ProtocolError('accepted B producer build differs')
    groups = run.get('processes', [])
    if len(groups) != 2:
        raise ProtocolError('accepted A requires two actual process generations')
    first, last = groups
    if (any(row.get('status') != 'exited' or 'returncode' not in row for row in groups)
            or type(first.get('pid')) is not int or type(last.get('pid')) is not int
            or first['pid'] == last['pid'] or last.get('previous_pid') != first['pid']
            or last.get('previous_exit_confirmed') is not True or last.get('fresh_ready') is not True):
        raise ProtocolError('accepted A producer has no confirmed actual restart/exit')
    receipts = []
    for group in groups:
        reference = group['journey_receipt']
        expected = group['evidence'] + '/journey-receipt.json'
        if reference['path'] != expected or Path(group['evidence']).parts not in {
                ('processes', '0001'), ('processes', '0002')}:
            raise ProtocolError('accepted A receipt escaped its stopped generation')
        packet = read_receipt(dict(path=str(root / expected), sha256=reference['sha256']), run)
        state = packet['state']
        if (packet['kind'] != 'midgame-saved' or state['packet'] != milestone
                or state['starter'] != record['starter']):
            raise ProtocolError('accepted A receipt route identity differs')
        receipts.append(packet)
        for name, digest in wanted.items():
            slot = root / group['evidence'] / 'runtime-data' / name
            if (group.get('durable_after', {}).get(name) != digest or slot.is_symlink()
                    or hashlib.sha256(slot.read_bytes()).hexdigest() != digest):
                raise ProtocolError('accepted A stopped archive slot changed')
    if milestone == '5.5b':
        slots = []
        for name, digest in wanted.items():
            path = Path(record['directory']) / name
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise ProtocolError('accepted B canonical slot changed')
            slot = json.loads(path.read_bytes())
            if (set(slot) != {'format', 'schema', 'sequence', 'checksum', 'payload'}
                    or slot['format'] != 'pokemon-playdate-save' or slot['schema'] != 1
                    or not isinstance(slot['payload'], str)):
                raise ProtocolError('accepted B slot envelope differs')
            sequence = int(slot['sequence'])
            wire = ('1\n' + str(sequence) + '\n' + slot['payload']).encode()
            checksum = 2166136261
            for byte in wire:
                checksum = ((checksum ^ byte) * 16777619) & 0xffffffff
            if f'{checksum:08x}' != slot['checksum']:
                raise ProtocolError('accepted B slot checksum differs')
            slots.append((sequence, json.loads(slot['payload'])))
        if max(slots, key=lambda row: row[0])[1] != receipts[-1]['state']['codec']:
            raise ProtocolError('accepted B saved codec differs from actual Continue')
    if receipts[0] != receipts[1]:
        raise ProtocolError('accepted A actual Continue codec differs from Save')
    # Verify the recorded partial chain, including its stopped producer and slots.
    for reference in prior.get('resume', {}).get('ancestry', []):
        marker_path = Path(reference['path'])
        if marker_path.is_symlink() or hashlib.sha256(marker_path.read_bytes()).hexdigest() != reference['sha256']:
            raise ProtocolError('accepted A partial ancestry marker changed')
        marker = json.loads(marker_path.read_bytes())
        generation = marker_path.parent
        ancestor_run = json.loads((generation.parent.parent / 'run.json').read_bytes())
        process = next((row for row in ancestor_run['processes']
                        if row.get('evidence') == generation.relative_to(generation.parent.parent).as_posix()), None)
        if (process is None or process.get('status') not in {'exited', 'failed-exited'}
                or 'returncode' not in process
                or any(marker.get(k) != ancestor_run.get(k) for k in ('build_id', 'session_id'))):
            raise ProtocolError('accepted A ancestry producer exit unconfirmed')
        for item in marker['files']:
            archived = generation / 'runtime-data' / item['file']
            if (item['file'] not in wanted or archived.is_symlink()
                    or hashlib.sha256(archived.read_bytes()).hexdigest() != item['sha256']):
                raise ProtocolError('accepted A ancestry archive changed')
    return dict(state=receipts[-1]['state'], receipt=last['journey_receipt'],
                acceptance_sha256=hashlib.sha256((Path(project) / record['acceptance']).read_bytes()).hexdigest(),
                chain_manifest_sha256=hashlib.sha256(manifest_bytes).hexdigest(),
                producer_run_sha256=hashlib.sha256((root / 'run.json').read_bytes()).hexdigest())


def import_midgame_partial(spec, journey, origin, project, data, output):
    """Read a real Save marker only after its owned process exited and was archived.

    The marker binds both slot hashes and the complete actual Save observation.
    A failed journey remains failed; only its last verified Save is resumable.
    """
    from tools.harness.midgame_journey import validate_partial_state
    reference = spec['resume']
    path = Path(reference['path'])
    if path.is_symlink() or not path.is_file() or path.name != 'partial-save.json':
        raise ProtocolError('missing immutable midgame partial Save marker')
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != reference['sha256']:
        raise ProtocolError('partial Save marker checksum changed')
    marker = json.loads(raw)
    if (not isinstance(marker, dict) or set(marker) != {'schema', 'kind', 'state', 'files',
            'starting_save', 'build_id', 'session_id'}
            or marker['schema'] != 1 or marker['kind'] != 'midgame-partial'):
        raise ProtocolError('malformed partial Save marker')
    validate_partial_state(marker['state'])
    if any(marker['state'][key] != journey[key] for key in ('starter', 'packet', 'content_scope')):
        raise ProtocolError('partial Save marker changed starter/route scope')
    # Do not accept an arbitrary relocated slot directory or a live producer.
    generation, run_root = path.parent, path.parent.parent.parent
    run = json.loads((run_root / 'run.json').read_bytes())
    process = next((row for row in run['processes']
                    if row.get('evidence') == generation.relative_to(run_root).as_posix()), None)
    if (any(marker[key] != run[key] for key in ('build_id', 'session_id'))
            or process is None or process.get('status') not in {'exited', 'failed-exited'}
            or 'returncode' not in process):
        raise ProtocolError('partial Save producer has not confirmed its owned exit')
    prior = marker['starting_save']
    original = {key: value for key, value in prior.items() if key != 'resume'}
    if original != origin:
        raise ProtocolError('partial Save lacks the exact accepted starter ancestry')
    # Accepted slots are still checked and never written, even on a tooling retry.
    for item in origin['files']:
        accepted = Path(origin['directory']) / item['file']
        if accepted.is_symlink() or hashlib.sha256(accepted.read_bytes()).hexdigest() != item['sha256']:
            raise ProtocolError('accepted starting ancestor changed')
    files = marker['files']
    if (not isinstance(files, list) or len(files) != 2
            or {item['file'] for item in files} != {'adventure.a.json', 'adventure.b.json'}):
        raise ProtocolError('partial Save requires both exact slot hashes')
    contents = {}
    for item in files:
        archived = generation / 'runtime-data' / item['file']
        if archived.is_symlink() or not archived.is_file():
            raise ProtocolError('partial Save slots are not in the stopped-process archive')
        content = archived.read_bytes()
        if hashlib.sha256(content).hexdigest() != item['sha256']:
            raise ProtocolError('archived slots differ from the last verified real Save')
        contents[item['file']] = content
    record = dict(origin)
    ancestry = list(prior.get('resume', {}).get('ancestry', []))
    ancestry.append(dict(reference))
    record['resume'] = dict(reference, state=marker['state'], files=files,
                            directory=str(generation / 'runtime-data'), ancestry=ancestry)
    for name, content in contents.items():
        (data / name).write_bytes(content)
    atomic_json(output / 'starting-save.json', record)
    return record


def export_chain_save(scenario, data, output, metadata):
    spec = scenario.get('initial_save')
    if spec is None:
        return
    first = scenario['processes'][0].get('journey', {})
    if first.get('name') == 'midgame-natural' and first.get('packet') not in {'5.5a', '5.5b', '5.5c'}:
        return  # A partial route checkpoint never exports final 5.5a slots.
    if first.get('name') == 'vermilion-natural' and (
            len(scenario['processes']) != 2
            or scenario['processes'][1].get('journey', {}).get('name') != 'vermilion-continue'):
        raise ProtocolError('Vermilion chain export requires its two-process Save/Continue')
    if first.get('name') == 'midgame-natural':
        if (len(scenario['processes']) != 2
                or scenario['processes'][1].get('journey', {}).get('name') != 'midgame-continue'):
            raise ProtocolError('midgame export requires actual process Save/Continue')
        run_record = json.loads((output / 'run.json').read_bytes())
        if len(run_record['processes']) != 2 or any(row.get('status') != 'exited' for row in run_record['processes']):
            raise ProtocolError('midgame export requires two confirmed exited processes')
        before, after = run_record['processes']
        if (before.get('pid') == after.get('pid') or not after.get('previous_exit_confirmed')
                or after.get('previous_pid') != before.get('pid') or not after.get('fresh_ready')
                or any('returncode' not in row for row in (before, after))):
            raise ProtocolError('midgame export lacks confirmed actual process restart')
        last = after['journey_receipt']
        initial = before['journey_receipt']
        saved = read_receipt(dict(path=str(output / initial['path']), sha256=initial['sha256']), metadata)
        receipt = read_receipt(dict(path=str(output / last['path']), sha256=last['sha256']), metadata)
        if (receipt.get('kind') != 'midgame-saved'
                or any(receipt['state'].get(key) != first.get(key) for key in ('starter', 'packet', 'content_scope'))):
            raise ProtocolError('midgame export changed journey identity')
        if receipt != saved:
            raise ProtocolError('midgame export Continue differs from actual Save receipt')
        for name in ('adventure.a.json', 'adventure.b.json'):
            slot = data / name
            if slot.is_symlink() or hashlib.sha256(slot.read_bytes()).hexdigest() != after.get('durable_after', {}).get(name):
                raise ProtocolError('midgame export differs from confirmed stopped slots')
        if receipt['state']['packet'] != first['packet']:
            raise ProtocolError('midgame export cannot use another route receipt')
    milestone = first['packet'] if first.get('name') == 'midgame-natural' else '5.4' if first.get('name') == 'vermilion-natural' else '5.3'
    destination = Path.home() / 'Developer/Pokemon-PlayDate-env/evidence/chain' / milestone / spec['starter']
    destination.mkdir(parents=True, exist_ok=True)
    files = []
    for name in ('adventure.a.json', 'adventure.b.json'):
        content = (data / name).read_bytes()
        (destination / name).write_bytes(content)
        files.append({'file': name, 'sha256': hashlib.sha256(content).hexdigest()})
    atomic_json(destination / 'provenance.json', {
        'milestone': milestone, 'starter': spec['starter'], 'evidence': str(output),
        'build_id': metadata['build_id'], 'files': files,
        'source_sha256': metadata.get('source_sha256'),
        'starting_save': json.loads((output / 'starting-save.json').read_text()),
        'status': 'journey passed Save/Continue; milestone review pending'})


# Fixed limits for the explicitly opted-in existing journey owner. These do not
# relax any outer owner guard. No census producer or controller is imported.
HISTORY_TRIGGER = 736 * 1024**2
HISTORY_MAX_CLEARS = 64
HISTORY_MAX_CALLS = 131
SIMULATOR_SHA256 = 'ebaeca5c65f3d613f06c8a3d701e90c01f292f13fc66f24a680e4357c5b447cf'


def file_sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def history_options(args, scenario=None):
    helper, pin = getattr(args, 'history_helper', None), getattr(args, 'history_helper_sha256', None)
    if bool(helper) != bool(pin):
        raise ProtocolError('history helper and SHA256 must be supplied together')
    if not helper:
        return False
    if (not isinstance(pin, str) or len(pin) != 64 or any(c not in '0123456789abcdef' for c in pin)
            or Path(helper).is_symlink() or not Path(helper).is_file() or file_sha(helper) != pin):
        raise ProtocolError('history helper pin mismatch')
    if scenario is not None and (getattr(args, 'qualification', False)
            or not scenario.get('processes')
            or any(not group.get('journey') for group in scenario['processes'])):
        raise ProtocolError('history clearing requires existing process journeys')
    return True


def native_process_identity(pid):
    """Darwin proc_bsdinfo start fields, not a rounded ps display timestamp."""
    import ctypes
    import struct
    library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    library.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int]
    library.proc_pidinfo.restype = ctypes.c_int
    buffer = ctypes.create_string_buffer(136)
    size = library.proc_pidinfo(pid, 3, 0, buffer, len(buffer))  # PROC_PIDTBSDINFO
    if size != len(buffer):
        raise ProtocolError('cannot pin owned process start time')
    parent = struct.unpack_from('=I', buffer.raw, 16)[0]
    import os
    if parent != os.getpid():
        raise ProtocolError('Simulator is not a direct child of this owner')
    sec, usec = struct.unpack_from('=QQ', buffer.raw, 120)
    return dict(start_sec=sec, start_usec=usec, owner_pid=parent)


def linux_vmhwm_bytes(pid):
    """Peak resident set from /proc, not Darwin phys_footprint."""
    try:
        text = Path(f'/proc/{pid}/status').read_text()
    except OSError as error:
        raise ProtocolError('cannot inspect Linux resident set') from error
    for line in text.splitlines():
        if line.startswith('VmHWM:'):
            return int(line.split()[1]) * 1024
    raise ProtocolError('cannot inspect Linux resident set')


class LinuxResidentGuard:
    """Enforce the 1 GiB hard stop and 30 GiB reserve without the Mac helper.

    VmHWM is this host's peak resident set. It is not proc_pid_rusage and
    must not be compared with the Macintosh Silph baselines.
    """
    def __init__(self, process, output):
        self.process = process
        self.output = output
        self.error = None
        self.peak_bytes = 0
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._run, name='linux-resident-guard', daemon=True)
        self.thread.start()

    def _run(self):
        while not self.stop.is_set():
            if self.process.poll() is not None:
                return
            try:
                current = linux_vmhwm_bytes(self.process.pid)
            except ProtocolError as error:
                self.error = str(error)
                self.process.kill()
                return
            if current > self.peak_bytes:
                self.peak_bytes = current
            if current > 1024**3:
                self.error = 'owned Simulator exceeds 1 GiB Linux VmHWM'
            elif shutil.disk_usage(self.output).free < 30 * 1024**3:
                self.error = 'journey disk reserve below 30 GiB'
            else:
                self.stop.wait(0.25)
                continue
            self.process.kill()
            return

    def close(self):
        self.stop.set()
        self.thread.join(2)
        atomic_json(Path(self.output) / 'linux-resident.json', {
            'metric': 'VmHWM',
            'peak_bytes': self.peak_bytes,
            'limit_bytes': 1024**3,
            'error': self.error,
        })


def host_footprint(pid):
    import ctypes
    class Usage(ctypes.Structure):
        _fields_ = [('uuid', ctypes.c_uint8 * 16)] + [
            (name, ctypes.c_uint64) for name in ('user', 'system', 'idle', 'interrupt',
                'pageins', 'wired', 'resident', 'footprint', 'start', 'exit')]
    usage = Usage()
    library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    library.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
    library.proc_pid_rusage.restype = ctypes.c_int
    if library.proc_pid_rusage(pid, 0, ctypes.byref(usage)) != 0:
        raise ProtocolError('cannot inspect owned Simulator footprint')
    return usage.footprint


def validate_journey_pause(value, result):
    if (not value or value.get('id') != result.get('id') or value.get('tick') != result.get('tick')
            or result.get('status') != 'ok' or result.get('history_paused') is not True):
        raise ProtocolError('foreign or incomplete journey history pause')
    snapshot = result.get('snapshot', {})
    player = snapshot.get('player', {})
    title = snapshot.get('title', {})
    ready_title = (snapshot.get('root') == 'title' and snapshot.get('stack') == 'title'
                   and title.get('phase') == 'menu' and title.get('menu', {}).get('active') is True
                   and player.get('present') is False)
    exploring = (snapshot.get('root') == 'overworld' and snapshot.get('overworld') == 'explore'
                 and player.get('settled') is True and player.get('moving') is False
                 and not player.get('isJumping') and not player.get('pendingEdgeDoor'))
    if not (exploring or ready_title):
        raise ProtocolError('journey history boundary is not settled exploration or ready title')


def validate_startup_pause(value, expected):
    if (not isinstance(value, dict) or not expected
            or any(value.get(key) != item for key, item in expected.items())
            or value.get('tick') != 0 or value.get('status') != 'startup'
            or value.get('startup_stage') != 'title-preparing'
            or value.get('history_startup_version') != 1
            or value.get('root') != 'title' or value.get('stack') != 'title'
            or value.get('title_phase') != 'preparing'
            or value.get('player_present') is not False
            or value.get('injected_input') is not False or value.get('recording') is not False):
        raise ProtocolError('foreign or unsafe startup history pause')


class JourneyHistory:
    """A bounded hook on the existing owner/client; never drives game commands."""
    def __init__(self, args, metadata, output, evidence, process, client, startup=None):
        self.startup = startup
        self.startup_serviced = False
        self.startup_consumed = False
        self.helper = Path(args.history_helper).expanduser().absolute()
        self.pin = args.history_helper_sha256
        self.metadata, self.output, self.evidence = metadata, output, evidence
        self.process, self.client = process, client
        self.calls = self.clears = 0
        self.failed = False
        self.pause = None
        self.started = self.progress = time.monotonic()
        self.tick = None

    def check(self, command_deadline=None):
        try:
            now = time.monotonic()
            if self.process.poll() is not None:
                raise ProtocolError('owned journey process exited')
            footprint = host_footprint(self.process.pid)
            if footprint > 1024**3:
                raise ProtocolError('owned Simulator exceeds 1 GiB host footprint')
            if shutil.disk_usage(self.output).free < 30 * 1024**3:
                raise ProtocolError('journey disk reserve below 30 GiB')
            heartbeat = self.client.read('heartbeat.json')
            if heartbeat and heartbeat.get('tick') != self.tick:
                self.tick, self.progress = heartbeat.get('tick'), now
            if now - self.progress > 60 or now - self.started > 14400:
                raise ProtocolError('journey progress or whole-owner deadline expired')
            if command_deadline is not None and now >= command_deadline:
                raise ProtocolError('journey command deadline expired during history pause')
            self.client._check_runtime_failure()
            return footprint
        except BaseException:
            self.failed = True
            raise

    def startup_poll(self, deadline):
        try:
            self.check(deadline)
            if self.failed:
                raise ProtocolError('history owner failed; stop without replay')
            pause = self.client.read('journey-history-pause.json')
            if self.startup_serviced:
                # The publication may remain until the coroutine consumes ACK.
                if pause is None:
                    self.startup_consumed = True
                if pause and (self.startup_consumed or pause != self.startup_publication):
                    raise ProtocolError('startup history publication changed after acknowledgement')
                return
            if pause is None:
                return
            validate_startup_pause(pause, self.startup)
            if (self.client.data / 'journey-history-ack.json').exists():
                raise ProtocolError('startup acknowledgement already exists')
            self.pause = pause
            self.clear(deadline)
            self.check(deadline)
            if self.client.read('journey-history-pause.json') != pause:
                raise ProtocolError('startup history pause changed before acknowledgement')
            ack = {key: pause[key] for key in (*self.client.identity, 'id', 'tick',
                'generation', 'startup_stage', 'history_startup_version')}
            atomic_json(self.evidence / 'startup-pause.json', pause)
            atomic_json(self.client.data / 'journey-history-ack.json', ack)
            self.startup_publication = pause
            self.startup_serviced = True
            self.pause = None
        except BaseException:
            self.failed = True
            raise

    def clear(self, deadline):
        if self.failed or self.clears >= HISTORY_MAX_CLEARS:
            raise ProtocolError('journey history Clear bound reached or owner failed')
        operations = ['inspect', 'show-log', 'clear', 'inspect'] if not self.clears else ['clear', 'inspect']
        for operation in operations:
            self.invoke(operation, deadline)
            if operation == 'clear':
                self.clears += 1

    def before_send(self):
        self.check()
        if self.failed:
            raise ProtocolError('history owner failed; stop without replay')
        if self.pause:
            atomic_json(self.client.data / 'journey-history-ack.json', self.pause)
            self.pause = None

    def invoke(self, operation, deadline):
        if self.calls >= HISTORY_MAX_CALLS or file_sha(self.helper) != self.pin:
            raise ProtocolError('history helper bound or pin changed')
        self.calls += 1
        before = self.check(deadline)
        began = time.monotonic()
        pins = [str(self.output), file_sha(self.output / 'build.json'),
                file_sha(self.evidence / 'process.json'), 'JOURNEY',
                (self.evidence / 'process.json').relative_to(self.output).as_posix()]
        child = subprocess.Popen([str(self.helper), operation, *pins],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout = stderr = ''
        inspection_captures = []
        try:
            while True:
                self.check(deadline)
                if time.monotonic() - began >= 9:
                    raise ProtocolError('history helper timed out; no replay or acknowledgement')
                try:
                    stdout, stderr = child.communicate(timeout=.05)
                    break
                except subprocess.TimeoutExpired:
                    pass
            after = self.check(deadline)
            if child.returncode != 0:
                raise ProtocolError('history helper refused: ' + stderr[-1200:])
            reply = json.loads(stdout)
            if operation == 'clear' and reply not in (
                    {'ax_press_accepted': True, 'pid': self.process.pid},
                    {'clear_requested': True, 'mechanism': 'verified-window-broom', 'pid': self.process.pid}):
                raise ProtocolError('history Clear acknowledgement differs')
            if operation == 'inspect':
                if not isinstance(reply, list):
                    raise ProtocolError('history inspection is not a listing')
                captures = [row for row in reply if row.get('scope') == 'inspection capture']
                if len(captures) > 1 or (not captures and self.clears):
                    raise ProtocolError('history inspection capture missing or ambiguous')
                for capture in captures:
                    path = Path(capture['path'])
                    import re
                    if (path.parent != self.output or path.is_symlink() or
                            not re.fullmatch(r'malloc-log-inspection-[0-9A-Fa-f-]{36}\.png', path.name)
                            or capture.get('returncode') != '0'):
                        raise ProtocolError('history inspection capture identity differs')
                    from tools.harness.run import verify_png
                    verify_png(path)
                    inspection_captures.append(dict(capture, sha256=file_sha(path)))
            if operation == 'show-log':
                accepted = ({'malloc_log_open_requested': True, 'pid': self.process.pid},
                            {'malloc_log_already_open': True, 'pid': self.process.pid})
                if reply not in accepted:
                    raise ProtocolError('history Show Malloc Log acknowledgement differs')
                # Do not wait for the populated profiler view to materialize.
                # Clear independently verifies window readiness and fails closed.
            return reply
        except BaseException:
            self.failed = True
            raise
        finally:
            if child.poll() is None:
                child.kill()
            stdout, stderr = child.communicate()
            try:
                after = host_footprint(self.process.pid)
            except BaseException:
                after = None  # Preserve the original helper/producer failure.
            with (self.evidence / 'malloc-clear.jsonl').open('a') as stream:
                stream.write(json.dumps(dict(operation=operation, calls=self.calls, clears=self.clears,
                    helper_sha256=self.pin, pins=pins, pause=self.pause, failed=self.failed,
                    elapsed_ms=(time.monotonic()-began)*1000, returncode=child.returncode,
                    stdout=stdout, stderr=stderr, inspection_captures=inspection_captures, host_before_bytes=before,
                    host_after_bytes=after), sort_keys=True) + '\n')

    def completed(self, result, deadline):
        try:
            footprint = self.check(deadline)
            if result.get('history_paused') is not True:
                return
            pause = self.client.read('journey-history-pause.json')
            validate_journey_pause(pause, result)
            self.pause = pause
            if self.clears and footprint < HISTORY_TRIGGER:
                return
            self.clear(deadline)
        except BaseException:
            self.failed = True
            raise


def run(args, scenario, metadata, output, data, owner, runner):
    """Run approved groups under the caller's uninterrupted global/private locks."""
    processes = []
    process = client = evidence = guard = None
    sequence = trace_start = 0
    finalized = archived = False
    prior_pid = None
    expected_durable = None
    prior_receipt = None

    def publish():
        atomic_json(output / 'run.json', dict(metadata, processes=processes))

    try:
        for generation, group in enumerate(scenario['processes'], 1):
            check_owner(owner, data)
            evidence = output / 'processes' / f'{generation:04d}'
            evidence.mkdir(parents=True, exist_ok=False)
            finalized = archived = False
            client = None
            # Old process was quiesced, stopped, confirmed dead and archived
            # before reaching this boundary. No saves or trace are removed.
            before = durable_hashes(data)
            clear_handshake(data, owner)
            if durable_hashes(data) != before:
                raise ProtocolError('restart cleanup changed durable files')
            expected_durable = before
            record = {'generation': generation, 'status': 'launching', 'evidence': str(evidence.relative_to(output)),
                      'first_sequence': sequence + 1, 'durable_before': before,
                      'previous_pid': prior_pid, 'previous_exit_confirmed': generation == 1 or processes[-1]['status'] == 'exited'}
            processes.append(record); publish()
            from tools.harness import catalog_qualification
            catalog_qualification.prepare(output)
            with (evidence / 'simulator.log').open('w') as log:
                runner.simulator_preflight()
                if (metadata.get('history_clear') or sys.platform != 'darwin') and shutil.disk_usage(output).free < 31 * 1024**3:
                    raise ProtocolError('journey admission requires 31 GiB disk headroom')
                startup = None
                if metadata.get('history_clear'):
                    if metadata.get('history_startup_version') != 1:
                        raise ProtocolError('journey startup feature missing from actual build')
                    import uuid
                    startup = dict(protocol=1, build_id=metadata['build_id'], session_id=metadata['session_id'],
                        id='startup-' + uuid.uuid4().hex, generation=generation, history_startup_version=1)
                    atomic_json(data / 'journey-startup-request.json', startup)
                process = subprocess.Popen([metadata['simulator'], metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
                if sys.platform != 'darwin' and not metadata.get('history_clear'):
                    if guard is not None:
                        guard.close()
                        if guard.error:
                            raise ProtocolError(guard.error)
                    guard = LinuxResidentGuard(process, output)
                record['pid'] = process.pid
                if process.pid == prior_pid:
                    raise ProtocolError('restart did not produce a new PID')
                record['launched_ns'] = time.time_ns(); publish()
                if metadata.get('history_clear'):
                    record.update(native_process_identity(process.pid), build_id=metadata['build_id'],
                        session_id=metadata['session_id'], history_identity='JOURNEY',
                        simulator_sha256=file_sha(metadata['simulator']))
                    if record['simulator_sha256'] != SIMULATOR_SHA256:
                        raise ProtocolError('journey Simulator executable pin differs')
                client = Client(data, metadata['build_id'], metadata['session_id'], evidence, owner=owner)
                client.sequence = sequence
                if metadata.get('history_clear'):
                    record.update(startup_id=startup['id'], history_startup_version=1, fresh_ready=False,
                                  simulator=metadata['simulator'])
                    atomic_json(evidence / 'process.json', record); publish()
                    client.history = JourneyHistory(args, metadata, output, evidence, process, client, startup)
                # No prior ready exists, and the old publisher is confirmed dead.
                ready = client.ready(args.ready_timeout)
                if process.poll() is not None:
                    raise ProtocolError('Simulator exited during fresh ready handshake')
                if generation > 1 and durable_hashes(data) != expected_durable:
                    raise ProtocolError('boot changed durable files across restart')
                record.update(status='ready', fresh_ready=True, ready_tick=ready.get('tick'), ready_observed_ns=time.time_ns())
                atomic_json(evidence / 'process.json', record); publish()
                if 'journey' in group:
                    from tools.harness import journeys
                    prior=read_receipt(prior_receipt,metadata) if group['journey']['name'] in {'brock-continue','npc-motion-continue','cerulean-continue','vermilion-continue','vermilion-supplementary-continue','midgame-continue'} else None
                    summary=journeys.run(client,{'journey':group['journey']},evidence,
                        build_evidence=output,prior_receipt=prior,capture_dir=output/'frames')
                    if not isinstance(summary,dict)or summary.get('ok') is not True:raise ProtocolError('process journey failed')
                    receipt=summary.get('receipt')
                    if not isinstance(receipt,dict)or set(receipt)!={'path','sha256'}or receipt['path']!='journey-receipt.json':raise ProtocolError('successful journey missing immutable receipt')
                    prior_receipt={'path':str(evidence/'journey-receipt.json'),'sha256':receipt['sha256']}
                    read_receipt(prior_receipt,metadata)
                    record['journey_receipt']={'path':str((evidence/'journey-receipt.json').relative_to(output)),'sha256':receipt['sha256']}
                    record['journey_summary']='journey-summary.json'
                else:
                    for commands in group['requests']:
                        result = client.send(commands, args.timeout, args.max_frames)
                        runner.verify_request_outputs(commands, result, output)
                    prior_receipt=None
                for path in group.get('outputs', []):
                    runner.verify_png(output / 'frames' / path)
                runner.finalize_captures(client, data, output)
                finalized = True
                runner.qualify_catalog(client, data, output)
                runner.qualify_field_items(client, data, output)
                sequence = client.sequence
                record['last_sequence'] = sequence
                record['status'] = 'quiescent'; publish()
                record['returncode'] = stop_owned(process, owner, data)
                record['status'] = 'exited'
                prior_pid = process.pid
                process = None
                trace_start = archive_generation(data, output, evidence, trace_start)
                archived = True
                record['durable_after'] = durable_hashes(data)
                atomic_json(evidence / 'process.json', record); publish()
        export_chain_save(scenario, data, output, metadata)
        atomic_json(output / 'outcome.json', {'ok': True, 'session_id': metadata['session_id'],
                                             'process_generations': len(processes)})
        print(output)
        return 0
    except BaseException as error:
        if guard is not None and guard.error:
            error = ProtocolError(guard.error)
        if processes:
            processes[-1].update(status='failed', error=str(error))
            atomic_json(evidence / 'process.json', processes[-1])
            publish()
        # Never reset/recover a failed command into success. A poisoned pending
        # request cannot safely quiesce; stop its owned producer and archive it.
        if (client is not None and not finalized and client._pending_id is None
                and not metadata.get('history_clear')):
            try:
                runner.finalize_captures(client, data, output)
                finalized = True
            except BaseException as capture_error:
                atomic_json(output / 'artifact-finalization.json', {'quiescent': False, 'error': str(capture_error)})
        atomic_json(output / 'outcome.json', {'ok': False, 'session_id': metadata['session_id'],
                                             'error': str(error), 'process_generations': len(processes),
                                             'captures_finalized': finalized})
        return 1
    finally:
        if guard is not None:
            guard.close()
        if process is not None:
            try:
                returncode = stop_owned(process, owner, data)
                if processes:
                    processes[-1].update(status='failed-exited', returncode=returncode)
            except UnconfirmedExit as error:
                if processes:
                    processes[-1].update(status='exit-unconfirmed', error=str(error))
                atomic_json(output / 'outcome.json', {'ok':False, 'error':str(error),
                    'session_id':metadata['session_id'], 'data_retained':str(data)})
                raise
            finally:
                if processes:
                    atomic_json(evidence / "process.json", processes[-1])
                publish()
        if evidence is not None and not archived:
            archive_generation(data, output, evidence, trace_start)
