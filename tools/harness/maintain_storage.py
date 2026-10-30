#!/usr/bin/env python3
"""Maintain the evidence reserve. Read-only unless --execute is supplied."""
import argparse
from collections import defaultdict
from contextlib import ExitStack
import fcntl
import fnmatch
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness.cleanup_evidence import inventory, metadata_files, read_json
from tools.harness.share_archives import share_closed_traces

PROJECT = Path(__file__).resolve().parents[2]
GIB = 1024 ** 3
PROTECTED = {'chain', 'player-packages', 'Source', 'references', 'Data', 'runtime-data'}


def git(project, *args):
    return subprocess.check_output(['git', *args], cwd=project, text=True)


def free_bytes(root):
    info = os.statvfs(root)
    return info.f_bavail * info.f_frsize


def live_paths():
    """Inspect current commands, working directories and open files, never old PIDs."""
    commands = subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True)
    opened = subprocess.run(['lsof', '-nP', '-a', '-u', str(os.getuid()), '-Fn'],
                            capture_output=True, text=True, timeout=30)
    if opened.returncode not in (0, 1) or opened.stderr.strip():
        raise ValueError('cannot establish current open process paths: ' + opened.stderr)
    return commands + '\n' + opened.stdout


def tree_stamp(path):
    """Inventory rejects links/mounts/hardlinks; fingerprint also catches same-size edits."""
    if path.is_symlink():
        raise ValueError(f'symlink archive: {path}')
    size, newest = inventory(path)
    digest = hashlib.sha256()
    for folder, dirs, files in os.walk(path):
        dirs.sort()
        for name in ['.'] + dirs + sorted(files):
            item = Path(folder) / name
            info = item.lstat()
            newest = max(newest, info.st_ctime_ns)
            digest.update(repr((str(item.relative_to(path)), info.st_dev, info.st_ino,
                                info.st_mode, info.st_size, info.st_mtime_ns,
                                info.st_ctime_ns)).encode())
    return size, newest, digest.hexdigest()


def reference_texts(project, refs):
    """Pin both required branches, plus HEAD; missing/malformed protection fails closed."""
    for ref in dict.fromkeys((*refs, 'HEAD')):
        revision = git(project, 'rev-parse', '--verify', ref + '^{commit}').strip()
        files = git(project, 'ls-tree', '-r', '--name-only', revision, 'docs/validation').splitlines()
        required = {'docs/validation/progress.md', 'docs/validation/chain-saves.json'}
        if not required.issubset(files):
            raise ValueError(f'missing protection index at {ref}')
        for name in files:
            if name.endswith('.json') or name == 'docs/validation/progress.md':
                raw = git(project, 'show', revision + ':' + name)
                yield f'{ref}:{name}', json.loads(raw) if name.endswith('.json') else raw
    # Uncommitted operator acceptance/progress is additional protection.
    validation = project / 'docs/validation'
    for file in sorted(validation.rglob('*.json')) + [validation / 'progress.md']:
        if file.is_symlink():
            raise ValueError(f'symlink protection source: {file}')
        yield str(file), json.loads(file.read_text()) if file.suffix == '.json' else file.read_text()


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)


def journey_key(scenario):
    groups = scenario.get('processes', [scenario])
    journeys = [group['journey'] for group in groups if group.get('journey')]
    return json.dumps(journeys, sort_keys=True) if journeys else None


def run_records(path):
    """Return terminal journey records and passing device build identities."""
    records = []
    devices = []
    suite = path / 'suite.json'
    if suite.is_file():
        value = read_json(suite)
        if value.get('complete') is not True or not value.get('results') or value.get('not_run'):
            return records, devices, False
        for result in value['results']:
            if not isinstance(result.get('name'), str) or type(result.get('ok')) is not bool:
                return [], [], False
            # Suite result names are the stable scenario selectors. All results
            # protect latest passes, but only actual journeys permit deletion.
            records.append(('suite:' + result['name'], result['ok'], suite.stat().st_mtime_ns))
        scenarios = [read_json(file) for file in path.glob('*/scenario.json')]
        return records, devices, bool(scenarios) and all(journey_key(s) for s in scenarios) and len(scenarios) == len(records)
    outcome = path / 'outcome.json'
    if not outcome.is_file():
        return records, devices, False
    value = read_json(outcome)
    if type(value.get('ok')) is not bool:
        return records, devices, False
    stamp = outcome.stat().st_mtime_ns
    device = path / 'device-smoke.json'
    if device.is_file() and value['ok']:
        data = read_json(device)
        build = data.get('build_id') or data.get('build', {}).get('build_id')
        if isinstance(build, str) and build:
            devices.append((build, stamp))
    scenario = path / 'scenario.json'
    key = journey_key(read_json(scenario)) if scenario.is_file() else None
    if key:
        records.append(('journey:' + key, value['ok'], stamp))
    return records, devices, bool(key)


def compile_stage(path):
    # A missing run.json, old name or failed runtime is never a compile declaration.
    declarations = [json.loads(file.read_text()) for file in path.glob('*.json')]
    declared = any(isinstance(v, dict) and v.get('simulator_executed') is False and
                   ('compile-only' in str(v.get('mode', v.get('status', ''))))
                   for v in declarations)
    runtime = any((path / name).exists() for name in
                  ('run.json', 'outcome.json', 'suite.json', 'processes', 'process.json',
                   'ready.json', 'simulator.log', 'trace.jsonl', 'journey-summary.json', 'frames'))
    return declared and not runtime and any(path.glob('*.pdx/main.pdz'))


def plan(project, root, refs, age_hours):
    paths = {p.name: p for p in sorted(root.iterdir()) if p.is_dir() or p.is_symlink()}
    keep = defaultdict(set)
    stamps, records, devices, eligible, metadata = {}, {}, {}, {}, {}
    current = live_paths()
    for name, path in paths.items():
        if name in PROTECTED or 'accept' in name.lower():
            keep[name].add('saves, packages, inputs or acceptance evidence')
        if str(path) in current or re.search(r'(?<![\w.-])' + re.escape(name) + r'(?![\w.-])', current):
            keep[name].add('current process path')
        try:
            stamps[name] = tree_stamp(path)
            if time.time_ns() - stamps[name][1] < age_hours * 3600 * 1e9:
                keep[name].add('age grace')
            metadata[name] = [(file, json.loads(file.read_text())) for file in metadata_files(path)]
            for file, value in metadata[name]:
                if 'acceptance' in file.name.lower() or (isinstance(value, dict) and
                        (value.get('accepted') is True or value.get('status') == 'accepted')):
                    keep[name].add('acceptance metadata')
                data = value.get('data_dir') if isinstance(value, dict) else None
                if isinstance(data, str) and Path(data).expanduser().exists():
                    keep[name].add('SDK Data still exists')
            records[name], devices[name], journey = run_records(path)
            if journey:
                eligible[name] = 'completed journey retry'
            elif compile_stage(path):
                eligible[name] = 'explicit closed compile-only stage'
        except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
            keep[name].add('uncertain tree or metadata: ' + str(error))

    latest = defaultdict(list)
    for name, runs in records.items():
        for key, ok, stamp in runs:
            if ok:
                latest[key].append((stamp, name))
    for name, builds in devices.items():
        for build, stamp in builds:
            latest['device:' + build].append((stamp, name))
    for runs in latest.values():
        newest = max(stamp for stamp, _ in runs)
        for stamp, name in runs:
            if stamp == newest:
                keep[name].add('latest passing journey or device build')
    for name in paths:
        if eligible.get(name) == 'completed journey retry' and not all(
                any(newer > stamp for newer, _ in latest[key]) for key, _, stamp in records[name]):
            keep[name].add('no newer passing replacement for every journey')
        if name not in eligible:
            keep[name].add('unclassified archive')

    def protect(value, reason, base=project):
        for text in strings(value):
            matches = set(re.findall(r'[\w.-]+', text)) & paths.keys()
            matches.update(name for name in paths
                           if not re.fullmatch(r'[\w.-]+', name) and name in text)
            for token in re.findall(r'evidence/([^\s`"\'\)]+)', text):
                component = re.sub(r'<[^>]+>', '*', token.split('/')[0].rstrip('.,;:'))
                matches.update(n for n in paths if fnmatch.fnmatchcase(n, component))
            if text.rstrip('/') in (str(root), '$POKEMON_ENV/evidence', '${POKEMON_ENV}/evidence'):
                matches.update(paths)
            if '\n' not in text and len(text) < 4096 and '/' in text:
                expanded = text.replace('${POKEMON_ENV}', str(root.parent)).replace('$POKEMON_ENV', str(root.parent))
                # Evidence prose can start with approximate timings (~1.5 s/load).
                # Only the current user's explicit home prefix denotes a home path.
                candidate = Path(expanded)
                if expanded.startswith('~/'):
                    candidate = candidate.expanduser()
                for location in ([candidate] if candidate.is_absolute() else
                                 [base / candidate, project / candidate, root / candidate, root.parent / candidate]):
                    resolved = location.resolve()
                    if resolved == root:
                        matches.update(paths)
                    elif resolved.is_relative_to(root):
                        matches.add(resolved.relative_to(root).parts[0])
            for name in matches & paths.keys():
                keep[name].add(reason)

    for source, value in reference_texts(project, refs):
        protect(value, 'validation reference: ' + source)
    # Retained links protect their targets. Never descend mounts or links.
    for folder, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            entry = Path(folder) / name
            if entry.is_symlink():
                protect(str(entry.resolve()), 'retained symlink target')
        dirs[:] = [n for n in dirs if not (Path(folder) / n).is_symlink()
                   and not (Path(folder) / n).is_mount()]
    for file in root.glob('*.json'):
        if file.is_symlink():
            raise ValueError(f'symlink metadata: {file}')
        protect(json.loads(file.read_text()), 'loose evidence metadata', file.parent)
    scanned = set()
    while pending := set(keep) - scanned:
        for name in pending:
            scanned.add(name)
            if name not in metadata:
                # An unsafe retained tree may hide ancestry. Do not guess.
                raise ValueError(f'cannot inspect retained ancestry: {paths[name]}')
            for file, value in metadata[name]:
                protect(value, 'retained ancestry: ' + name, file.parent)
    return [{'path': str(path), 'bytes': stamps[name][0], 'stamp': stamps[name],
             'action': 'keep' if keep[name] else 'remove',
             'reasons': sorted(keep[name]) or [eligible[name]]}
            for name, path in paths.items()]


def maintain(project, env, refs, minimum, target, age_hours, execute=False,
             lock_dir=Path('/private/tmp')):
    project = project.resolve(strict=True)
    # Reject a supplied alias rather than following it into another storage tree.
    env = env.expanduser().absolute()
    root = env / 'evidence'
    if env != env.resolve(strict=True) or root.is_symlink() or not root.is_dir() or root.is_mount() or env.is_mount():
        raise ValueError('environment and evidence must be real, unmounted directories')
    root = root.resolve(strict=True)
    if root == project or project.is_relative_to(root) or root.is_relative_to(project):
        raise ValueError('evidence must be outside the checkout')
    before = free_bytes(root)
    report = {'mode': 'execute' if execute else 'dry-run', 'evidence': str(root),
              'minimum_free_bytes': minimum, 'target_free_bytes': target,
              'free_bytes_before': before, 'entries': [], 'removed': [], 'sharing': None}
    with ExitStack() as stack:
        if execute and before < minimum:
            for owner in ('storage-maintenance', 'suite', 'simulator', 'device'):
                lock = lock_dir / f'pokemon-playdate-{owner}-{os.getuid()}.lock'
                fd = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
                stream = stack.enter_context(os.fdopen(fd, 'a+'))
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if before < minimum:
            report['entries'] = plan(project, root, refs, age_hours)
            for entry in report['entries']:
                if not execute or free_bytes(root) >= target:
                    break
                if entry['action'] != 'remove':
                    continue
                fresh = {e['path']: e for e in plan(project, root, refs, age_hours)}
                current = fresh.get(entry['path'])
                if not current or current['action'] != 'remove' or current['stamp'] != entry['stamp']:
                    raise ValueError('archive changed or became retained: ' + entry['path'])
                path = Path(entry['path'])
                if path.parent != root or tree_stamp(path) != tuple(entry['stamp']):
                    raise ValueError('removal boundary changed: ' + str(path))
                if free_bytes(root) >= target:
                    break
                shutil.rmtree(path)
                report['removed'].append(str(path))
                # Print a durable audit line even if a later revalidation refuses.
                print(json.dumps({'removed': str(path), 'free_bytes': free_bytes(root)}), file=sys.stderr)
            if execute and free_bytes(root) < target:
                # Delete eligible archives first. Share only old retained trees;
                # refreshed ctimes then enforce a quiet grace period, rather
                # than recloning on each invocation and postponing deletion.
                old_retained = {Path(e['path']) for e in report['entries']
                                if e['action'] == 'keep' and 'age grace' not in e['reasons']}
                report['sharing'] = share_closed_traces(
                    root, True, lambda: free_bytes(root) >= target, allowed_roots=old_retained)
    report['free_bytes_after'] = free_bytes(root)
    report['observed_free_bytes_delta'] = report['free_bytes_after'] - before
    report['minimum_met'] = report['free_bytes_after'] >= minimum
    report['status'] = ('reserve already met' if before >= minimum else
                        'dry-run' if not execute else
                        'target met' if report['free_bytes_after'] >= target else 'eligible archives exhausted')
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=PROJECT)
    parser.add_argument('--env', type=Path, default=os.environ.get('POKEMON_ENV'))
    parser.add_argument('--checkpoint-ref', default='wip/checkpoint-a-erika')
    parser.add_argument('--minimum-free-gib', type=float, default=150)
    parser.add_argument('--target-free-gib', type=float, default=170)
    parser.add_argument('--min-age-hours', type=float, default=24)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args(argv)
    if args.env is None:
        parser.error('set POKEMON_ENV or supply --env')
    if not all(math.isfinite(n) for n in (args.minimum_free_gib, args.target_free_gib, args.min_age_hours)) or not (
            0 < args.minimum_free_gib <= args.target_free_gib and args.min_age_hours >= 1):
        parser.error('require finite 0 < minimum <= target and age >= 1 hour')
    try:
        report = maintain(args.project, args.env, ('main', args.checkpoint_ref),
                          int(args.minimum_free_gib * GIB), int(args.target_free_gib * GIB),
                          args.min_age_hours, args.execute)
        print(json.dumps(report, indent=2))
        return 0 if report['minimum_met'] or not args.execute else 2
    except (OSError, ValueError, TypeError, RuntimeError, subprocess.SubprocessError) as error:
        print('Storage maintenance refused: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
