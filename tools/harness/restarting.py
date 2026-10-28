"""Owned multi-process jobs. No Simulator or filesystem work at import time."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

from tools.harness.protocol import Client, ProtocolError, atomic_json

# Only these protocol publications are removed between stopped processes.
TRANSIENT = frozenset({'ready.json', 'heartbeat.json', 'request.json', 'result.json',
                       'rejected.json', 'cancel.json', 'runtime-error.json', 'captures-final.json',
                       'catalog-invariance-before.json', 'catalog-invariance-after.json'})


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
    if first.get('name') == 'vermilion-natural' and scenario.get('initial_save') != {
            'milestone': '5.3', 'starter': first.get('starter', 'squirtle')}:
        raise ProtocolError('Vermilion requires its accepted Cerulean starting save')
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
                allowed = allowed | {'vermilion_actions','collection_steps','collection_battles','collection_phase_battles','collection_balls','collection_ball_stock','collection_balls_per_battle','collection_money_reserve'}
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
    if not isinstance(packet,dict)or set(packet)!={'schema','kind','build_id','session_id','state'}or packet['schema']!=1 or packet['kind'] not in {'brock-saved','npc-motion-saved','cerulean-saved','vermilion-saved'} or packet['build_id']!=metadata['build_id']or packet['session_id']!=metadata['session_id']:
        raise ProtocolError('wrong-build or malformed prior journey receipt')
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
        if relative.parts[0] == 'recent' or relative.as_posix() in {'owner.lock', 'trace.jsonl', 'captures.jsonl'}:
            continue
        if relative.as_posix() in TRANSIENT or relative.as_posix() in {name + '.tmp' for name in TRANSIENT}:
            continue
        if path.is_file():
            result[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def archive_generation(data, output, evidence, trace_start):
    # Called only after confirmed process exit; producers cannot overwrite copies.
    shutil.copytree(data, evidence / 'runtime-data')
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
    if (not isinstance(spec, dict) or set(spec) != {'milestone', 'starter'}
            or spec['milestone'] not in {'5.2', '5.3'}
            or spec['starter'] not in {'bulbasaur', 'squirtle', 'charmander'}):
        raise ProtocolError('unknown starting save')
    first = scenario['processes'][0]['journey']
    expected = '5.3' if first.get('name') == 'vermilion-natural' else spec['milestone']
    if (first.get('name') not in {'cerulean-natural', 'vermilion-natural'}
            or first.get('starter') != spec['starter'] or spec['milestone'] != expected):
        raise ProtocolError('starting save does not match journey')
    manifest = json.loads((project / 'docs/validation/chain-saves.json').read_text())
    record = next(row for row in manifest['saves'] if row['starter'] == spec['starter']
                  and row['from_milestone'] == spec['milestone'])
    if first['name'] == 'vermilion-natural':
        proof = json.loads((project / 'docs/validation/cerulean-acceptance-20261028.json').read_text())
        if (proof.get('milestone_accepted') is not True or proof.get('milestone') != '5.3'
                or record.get('accepted_commit') != proof.get('accepted_main_code')
                or record.get('accepted_source_sha256') != proof.get('source_sha256')
                or not any(row.get('starter') == spec['starter'] for row in proof.get('starters', []))):
            raise ProtocolError('starting save lacks accepted Cerulean proof')
    if {item['file'] for item in record['files']} != {'adventure.a.json', 'adventure.b.json'}:
        raise ProtocolError('starting save must include both exact slots')
    contents = {}
    for item in record['files']:
        name = item['file']
        if name not in {'adventure.a.json', 'adventure.b.json'}:
            raise ProtocolError('unexpected starting save file')
        content = (Path(record['directory']) / name).read_bytes()
        if hashlib.sha256(content).hexdigest() != item['sha256']:
            raise ProtocolError('accepted starting save checksum changed')
        contents[name] = content
    for name, content in contents.items():
        (data / name).write_bytes(content)
    atomic_json(output / 'starting-save.json', record)
    return record


def export_chain_save(scenario, data, output, metadata):
    spec = scenario.get('initial_save')
    if spec is None:
        return
    first = scenario['processes'][0].get('journey', {})
    if first.get('name') == 'vermilion-natural' and (
            len(scenario['processes']) != 2
            or scenario['processes'][1].get('journey', {}).get('name') != 'vermilion-continue'):
        raise ProtocolError('Vermilion chain export requires its two-process Save/Continue')
    milestone = '5.4' if first.get('name') == 'vermilion-natural' else '5.3'
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


def run(args, scenario, metadata, output, data, owner, runner):
    """Run approved groups under the caller's uninterrupted global/private locks."""
    processes = []
    process = client = evidence = None
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
                process = subprocess.Popen([metadata['simulator'], metadata['bundle']], stdout=log, stderr=subprocess.STDOUT)
                record['pid'] = process.pid
                if process.pid == prior_pid:
                    raise ProtocolError('restart did not produce a new PID')
                record['launched_ns'] = time.time_ns(); publish()
                client = Client(data, metadata['build_id'], metadata['session_id'], evidence, owner=owner)
                client.sequence = sequence
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
                    prior=read_receipt(prior_receipt,metadata) if group['journey']['name'] in {'brock-continue','npc-motion-continue','cerulean-continue','vermilion-continue','vermilion-supplementary-continue'} else None
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
        if processes:
            processes[-1].update(status='failed', error=str(error))
            atomic_json(evidence / 'process.json', processes[-1])
            publish()
        # Never reset/recover a failed command into success. A poisoned pending
        # request cannot safely quiesce; stop its owned producer and archive it.
        if client is not None and not finalized and client._pending_id is None:
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
