#!/usr/bin/env python3
"""Run fresh Simulator qualification cases serially and aggregate exact evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
import re
from pathlib import Path
import signal
import subprocess
import sys
import time

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness.protocol import OwnerLock, ProtocolError, atomic_json
from tools.harness.run import PROJECT, fingerprint


def available_jobs():
    jobs = [
        {'name': 'smoke', 'scenario': PROJECT / 'tools/harness/smoke.json'},
        {'name': 'contracts-catalog', 'commands': ['contracts', 'catalog', 'shot contracts-catalog']},
        {'name': 'qualification', 'qualification': True},
    ]
    root = PROJECT / 'tools/harness/scenarios'
    for path in sorted(root.rglob('*.json'), key=lambda path: path.relative_to(root).as_posix()):
        # Flat artifact-safe names preserve existing top-level CLI names and
        # qualify nested cases by every source directory, e.g. brock--blackout.
        name = '--'.join(path.relative_to(root).with_suffix('').parts)
        jobs.append({'name': name, 'scenario': path})
    _check_unique_jobs(jobs)
    return jobs


def _check_unique_jobs(jobs):
    seen = set()
    for job in jobs:
        name = job['name']
        if name in seen:
            raise ProtocolError('duplicate suite case name: ' + name)
        seen.add(name)


def select_jobs(only=None, mutations=False):
    available = available_jobs()
    if mutations:
        available.append({'name': 'mutations', 'mutations': True})
    _check_unique_jobs(available)
    names = [name for value in (only or []) for name in value.split(',') if name]
    if len(names) != len(set(names)):
        raise ProtocolError('--only contains duplicate cases')
    by_name = {job['name']: job for job in available}
    unknown = set(names) - set(by_name)
    if unknown:
        raise ProtocolError('unknown case(s): ' + ', '.join(sorted(unknown)) + '; use --list; mutations requires --mutations')
    return [by_name[name] for name in names] if names else available


def suite_lock_path():
    # Distinct from run.py's runtime lock: children must acquire that themselves.
    return Path('/private/tmp') / f'pokemon-playdate-suite-{os.getuid()}.lock'


def launch_job(command, output, timeout):
    """Bound a child runner, allowing its finally block to clean owned runtime."""
    started = time.monotonic()
    timed_out = False
    with (output / 'runner-stdout.log').open('w') as stdout, (output / 'runner-stderr.log').open('w') as stderr:
        process = subprocess.Popen(command, cwd=PROJECT, stdout=stdout, stderr=stderr, start_new_session=True)
        try:
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                # SIGINT reaches Python's exception/finally cleanup, including
                # termination of the exact owned Simulator child.
                process.send_signal(signal.SIGINT)
                try:
                    code = process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    # This group contains only the child job and its descendants.
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        code = process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        code = process.wait(timeout=3)
        except BaseException:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)
            raise
    return {'returncode': code, 'timed_out': timed_out, 'elapsed_seconds': round(time.monotonic() - started, 3)}


def load_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise ProtocolError(f'missing/malformed evidence {path}: {error}') from error


def inspect_job(job, destination, execution):
    item = {'name': job['name'], 'evidence': str(destination), **execution, 'ok': False}
    try:
        if execution['timed_out'] or execution['returncode'] != 0:
            raise ProtocolError('child timed out' if execution['timed_out'] else f"child exited {execution['returncode']}")
        if job.get('mutations'):
            outcome = load_json(destination / 'qualification.json')
            if not outcome.get('ok') or not outcome.get('executed'):
                raise ProtocolError('mutation qualification incomplete or failed')
            if not outcome.get('variants') or not all(value.get('qualified') for value in outcome['variants']):
                raise ProtocolError('mutation variants incomplete')
            builds = sorted(destination.glob('*/build.json'))
            item['qualification'] = outcome
        else:
            outcome = load_json(destination / 'outcome.json')
            if outcome.get('ok') is not True:
                raise ProtocolError('runtime outcome missing success')
            builds = [destination / 'build.json']
            if job.get('qualification'):
                qualification = load_json(destination / 'qualification.json')
                if qualification.get('ok') is not True or not qualification.get('tests'):
                    raise ProtocolError('protocol qualification incomplete')
                item['qualification_cases'] = len(qualification['tests'])
            if job['name'] == 'contracts-catalog':
                catalog = load_json(destination / 'catalog.json')
                if not catalog.get('images'):
                    raise ProtocolError('catalog inventory missing')
                item['catalog_images'] = len(catalog['images'])
                item['catalog_missing'] = len(catalog.get('missing', []))
                if item['catalog_missing']:
                    raise ProtocolError('catalog reports missing assets')
                reports = []
                for result_path in destination.glob('*-result.json'):
                    if not re.fullmatch(r'[0-9]{5}-result\.json', result_path.name):
                        continue
                    result = load_json(result_path)
                    reports += [entry['contracts'] for entry in result.get('results', []) if entry.get('contracts')]
                if len(reports) != 1 or reports[0].get('ok') is not True:
                    raise ProtocolError('successful production contract report missing')
                item['contracts'] = {key: reports[0].get(key) for key in ('ok', 'passed', 'failed')}
        if not builds:
            raise ProtocolError('no identified build evidence')
        item['builds'] = []
        for path in builds:
            build = load_json(path)
            if not build.get('build_id') or not build.get('session_id') or not build.get('compiled_source_sha256'):
                raise ProtocolError(f'incomplete build identity: {path}')
            runtime_path = path.parent / 'run.json'
            if runtime_path.exists():
                runtime = load_json(runtime_path)
                if runtime.get('build_id') != build['build_id'] or runtime.get('session_id') != build['session_id']:
                    raise ProtocolError(f'runtime/build identity mismatch: {runtime_path}')
                build['simulator_pid'] = runtime.get('simulator_pid')
            actual = fingerprint(path.parent, exclude_generated=False)
            if actual != build['compiled_source_sha256']:
                raise ProtocolError(f'compiled staging fingerprint mismatch: {path}')
            item['builds'].append({key: build.get(key) for key in (
                'build_id', 'session_id', 'revision', 'source_sha256', 'compiled_source_sha256',
                'sdk_version', 'bundle', 'simulator_pid', 'mutation')})
        item['ok'] = True
    except (ProtocolError, TypeError, KeyError) as error:
        item['error'] = str(error)
    return item


def job_timeout(job, override=None):
    """A bounded campaign budget; explicit CLI override always wins."""
    if override is not None:
        if type(override) not in (int, float) or not math.isfinite(override) or override <= 0:
            raise ProtocolError('job timeout must be finite and positive')
        return override
    if job.get('scenario'):
        scenario = load_json(job['scenario'])
        journeys = [scenario.get('journey', {})]
        journeys += [group.get('journey', {}) for group in scenario.get('processes', [])]
        if any(journey.get('name') == 'brock-natural' for journey in journeys):
            return 3600
    return 240


def execute_suite(args, launch=launch_job):
    jobs = select_jobs(args.only, args.mutations)
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = output / 'inputs'
    inputs.mkdir()
    plan = []
    for job in jobs:
        job = dict(job)
        if job.get('scenario'):
            source = Path(job['scenario'])
            scenario = inputs / (job['name'] + '.json')
            content = source.read_bytes()
            scenario.write_bytes(content)
            job['scenario'] = scenario
            job['scenario_sha256'] = hashlib.sha256(content).hexdigest()
        job['job_timeout_seconds'] = job_timeout(job, args.job_timeout)
        plan.append(job)
    summary = {'schema': 1, 'ok': False, 'complete': False, 'plan_only': args.plan_only,
               'started_utc': datetime.now(timezone.utc).isoformat(), 'output': str(output),
               'failure_policy': 'continue' if args.continue_on_failure else 'abort',
               'job_timeout_seconds': args.job_timeout, 'requested': [job['name'] for job in plan],
               'source_consistent': True, 'results': []}
    atomic_json(output / 'suite-plan.json', {'jobs': [{key: str(value) if isinstance(value, Path) else value
                                                    for key, value in job.items()} for job in plan]})
    if args.plan_only:
        summary['complete'] = False
        summary['status'] = 'planned; no runtime validation performed'
        atomic_json(output / 'suite.json', summary)
        print(output)
        return 0
    baseline_identity = None
    with OwnerLock(suite_lock_path()):
        for number, job in enumerate(plan, 1):
            destination = output / f'{number:02d}-{job["name"]}'
            # run.py requires its --output not to exist; wrapper logs live beside it.
            wrapper = output / f'{number:02d}-{job["name"]}-host'
            wrapper.mkdir()
            if job.get('mutations'):
                command = [sys.executable, str(PROJECT / 'tools/rules-tests/mutations.py'), '--execute', '--output', str(destination)]
            else:
                command = [sys.executable, str(PROJECT / 'tools/harness/run.py'), '--output', str(destination)]
                if job.get('scenario'):
                    command += ['--scenario', str(job['scenario'])]
                if job.get('qualification'):
                    command += ['--qualification']
                command += job.get('commands', [])
            if args.sdk:
                command += ['--sdk', args.sdk]
            atomic_json(wrapper / 'command.json', {'argv': command, 'job': job['name']})
            print(f'[{number}/{len(plan)}] {job["name"]}', flush=True)
            try:
                execution = launch(command, wrapper, job['job_timeout_seconds'])
                item = inspect_job(job, destination, execution)
            except BaseException as error:
                item = {'name': job['name'], 'ok': False, 'error': str(error) or type(error).__name__,
                        'evidence': str(destination), 'interrupted': isinstance(error, (KeyboardInterrupt, SystemExit))}
            item['job_timeout_seconds'] = job['job_timeout_seconds']
            item['host_logs'] = str(wrapper)
            if not item['ok']:
                for stream in ('stdout', 'stderr'):
                    log = wrapper / f'runner-{stream}.log'
                    if log.exists():
                        item[stream + '_tail'] = log.read_text(errors='replace')[-4000:]
            if item['ok'] and not job.get('mutations'):
                identity = (item['builds'][0]['revision'], item['builds'][0]['source_sha256'], item['builds'][0]['sdk_version'])
                if baseline_identity is None:
                    baseline_identity = identity
                elif identity != baseline_identity:
                    summary['source_consistent'] = False
                    item.update(ok=False, error='source revision/content or SDK changed across suite')
            summary['results'].append(item)
            atomic_json(output / 'suite.json', summary)
            print(f'{job["name"]}: {"PASS" if item["ok"] else "FAIL: " + item.get("error", "unknown error")}', flush=True)
            if item.get('interrupted') or (not item['ok'] and not args.continue_on_failure):
                break
    summary['complete'] = len(summary['results']) == len(plan)
    summary['ok'] = summary['complete'] and all(item['ok'] for item in summary['results'])
    summary['not_run'] = [job['name'] for job in plan[len(summary['results']):]]
    summary['finished_utc'] = datetime.now(timezone.utc).isoformat()
    atomic_json(output / 'suite.json', summary)
    print(output)
    return 0 if summary['ok'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', help='new suite evidence directory')
    parser.add_argument('--sdk')
    parser.add_argument('--only', nargs='+', help='case names; space or comma separated, in requested order')
    parser.add_argument('--mutations', action='store_true', help='include actual isolated contract mutation qualification')
    parser.add_argument('--continue-on-failure', action='store_true', help='run remaining requested cases; final exit still fails')
    parser.add_argument('--job-timeout', type=float, default=None, help='whole-job wall deadline override; default 3600s for brock-natural, 240s otherwise')
    parser.add_argument('--plan-only', action='store_true', help='write immutable scenario inputs/plan without launching')
    parser.add_argument('--list', action='store_true', help='list case names without launching')
    args = parser.parse_args()
    try:
        if args.list:
            print('\n'.join(job['name'] for job in select_jobs(args.only, args.mutations)))
            return 0
        if not args.output:
            parser.error('--output is required except with --list')
        if args.job_timeout is not None and (not math.isfinite(args.job_timeout) or args.job_timeout <= 0):
            parser.error('--job-timeout must be positive')
        return execute_suite(args)
    except (OSError, ValueError, ProtocolError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
