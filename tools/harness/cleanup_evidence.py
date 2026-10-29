#!/usr/bin/env python3
"""Report conservative checkpoint evidence cleanup; deletion requires --execute."""
import argparse
from collections import Counter, defaultdict
from contextlib import ExitStack
import fcntl
import fnmatch
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]


def read_json(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f'expected JSON object: {path}')
    return value


def walk_error(error):
    raise error


def inventory(path):
    """Do not follow links, cross devices, or approve unusual filesystem entries."""
    size = 0
    newest = 0
    device = path.lstat().st_dev
    if path.is_mount() or device != path.parent.stat().st_dev:
        raise ValueError(f'mounted evidence directory: {path}')
    for folder, dirs, files in os.walk(path, followlinks=False, onerror=walk_error):
        for name in ['.'] + dirs + files:
            entry = Path(folder) / name
            info = entry.lstat()
            if info.st_dev != device or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
                raise ValueError(f'link, mount, or special entry: {entry}')
            if stat.S_ISREG(info.st_mode) and info.st_nlink != 1:
                raise ValueError(f'hard-linked file: {entry}')
            size += info.st_size if stat.S_ISREG(info.st_mode) else 0
            newest = max(newest, info.st_mtime_ns)
    return size, newest


def metadata_files(path):
    # SDK Data contains game saves and mailbox payloads (including deliberately
    # corrupt save-contract fixtures), not host evidence dependency declarations.
    for folder, dirs, files in os.walk(path, followlinks=False, onerror=walk_error):
        dirs[:] = [name for name in dirs if name not in ('Source', 'frames', 'runtime-data')
                   and not name.endswith('.pdx') and not (Path(folder) / name).is_symlink()]
        for name in files:
            if name.endswith('.json') and not re.fullmatch(r'\d+-(request|result)\.json', name):
                yield Path(folder) / name


def checkpoint(name, scenario):
    match = re.match(r'm(5)([0-9])([abc]?)(?:-|$)', name)
    if match:
        return f'{match[1]}.{match[2]}{match[3]}'
    text = json.dumps(scenario)
    for word, number in [('brock', '5.1'), ('cerulean', '5.3'), ('vermilion', '5.4')]:
        if word in text:
            return number
    return None


def processes():
    return subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True)


def alive(pid):
    if type(pid) is not int or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def plan(project, root, min_age_hours):
    project = project.resolve(strict=True)
    root = root.resolve(strict=True)
    paths = {p.name: p for p in sorted(root.iterdir()) if p.is_dir() or p.is_symlink()}
    reasons = defaultdict(set)
    sizes, stamps, scenarios, outcomes, completed, compiled = {}, {}, {}, {}, {}, set()
    warnings = set()
    process_text = processes()
    for name, path in paths.items():
        if path.is_symlink():
            reasons[name].add('symlink')
            sizes[name] = 0
            continue
        try:
            sizes[name], stamps[name] = inventory(path)
            if time.time_ns() - stamps[name] < min_age_hours * 3600 * 1e9:
                reasons[name].add('recent or changing')
            if name == 'chain':
                reasons[name].add('earned chain saves')
            if str(path) in process_text or re.search(r'(?<![\w.-])' + re.escape(name) + r'(?![\w.-])', process_text):
                reasons[name].add('live process reference')
            metadata = {}
            for file in metadata_files(path):
                # Retain earned resume exports even before repository acceptance.
                if file.name in ('partial-save.json', 'provenance.json'):
                    reasons[name].add('save or provenance export')
                if file.parent == path or file.name == 'process.json':
                    value = read_json(file)
                    metadata[file.name] = value
                    records = [value] + value.get('processes', [])
                    if any(alive(record.get(key)) for record in records if isinstance(record, dict)
                           for key in ('pid', 'simulator_pid', 'owner_pid')):
                        reasons[name].add('live recorded PID (including possible reuse)')
                    data_dir = value.get('data_dir')
                    if data_dir and Path(data_dir).expanduser().exists():
                        reasons[name].add('private runtime data still exists')
            if 'scenario.json' in metadata:
                scenarios[name] = json.dumps(metadata['scenario.json'], sort_keys=True)
            if type(metadata.get('outcome.json', {}).get('ok')) is bool:
                outcomes[name] = metadata['outcome.json']['ok']
                completed[name] = (path / 'outcome.json').stat().st_mtime_ns
            # Absence of run.json alone does not prove that a build was compile-only.
            declared = any(value.get('simulator_executed') is False and
                           'compile-only' in str(value.get('mode', value.get('status', '')))
                           for value in metadata.values())
            runtime = any((path / entry).exists() for entry in
                          ('run.json', 'outcome.json', 'runtime-data', 'processes', 'process.json',
                           'ready.json', 'simulator.log', 'startup-probe.json', 'trace.jsonl',
                           'captures.json', 'journey-summary.json', 'RuntimeSnapshot.json', 'result.json'))
            runtime = runtime or any(path.glob('frames/*')) or any(
                value.get('simulator_executed') is True for value in metadata.values())
            if declared and not runtime and any(path.glob('*.pdx/main.pdz')):
                compiled.add(name)
        except (OSError, ValueError, TypeError) as error:
            reasons[name].add('uncertain or unreadable metadata/tree')
            warnings.add(str(error))
            sizes.setdefault(name, 0)

    # A retained symlink can point into another candidate. Preserve that target
    # even if the link is never mentioned in an acceptance record.
    for folder, dirs, files in os.walk(root, followlinks=False, onerror=walk_error):
        for name in dirs + files:
            link = Path(folder) / name
            if link.is_symlink():
                try:
                    target = link.resolve().relative_to(root)
                    if target.parts:
                        reasons[target.parts[0]].add('target of retained symlink')
                    else:
                        for target_name in paths:
                            reasons[target_name].add('target of retained symlink')
                except (ValueError, RuntimeError):
                    pass

    groups = defaultdict(list)
    failures = defaultdict(list)
    for name, scenario in scenarios.items():
        if name in outcomes:
            groups[scenario].append(name)
            if outcomes[name] is False:
                key = checkpoint(name, json.loads(scenario))
                if key is None:
                    reasons[name].add('failure with unknown checkpoint')
                else:
                    failures[key].append(name)
    for key, names in failures.items():
        newest = max(completed[name] for name in names)
        for name in names:
            if completed[name] == newest:
                reasons[name].add(f'newest failure for checkpoint {key}')
    eligible = {name: 'explicit compile-only bundle' for name in compiled}
    for names in groups.values():
        successes = [name for name in names if outcomes[name] is True]
        if successes:
            successor = max(successes, key=lambda name: completed[name])
            for name in names:
                if completed[name] < completed[successor]:
                    eligible[name] = f'superseded by successful identical scenario: {successor}'

    # Scan all tracked repository JSON, a conservative superset of acceptances,
    # plus untracked acceptance JSON and progress.md. Bare names, relative paths,
    # historical absolute paths and <starter> templates all protect whole roots.
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=project, text=True).split('\0')
    sources = {project / name for name in tracked if name.endswith('.json')}
    sources.update(project.rglob('*accept*.json'))
    sources.update((project / 'docs/validation').rglob('*.json'))
    sources.update((project / 'docs/validation').glob('**/chain-saves.json'))
    progress = project / 'docs/validation/progress.md'
    sources.add(progress)
    required = project / 'docs/validation/chain-saves.json'
    if required not in sources or not required.is_file():
        raise ValueError(f'missing required save index: {required}')
    if not progress.is_file():
        raise ValueError(f'missing required progress ledger: {progress}')
    # Tokenize ordinary names once rather than trying hundreds of alternatives
    # at every character of large archived snapshots.
    tokens = re.compile(r'[\w.-]+')
    unusual = [name for name in paths if not re.fullmatch(r'[\w.-]+', name)]
    unusual_pattern = re.compile(r'(?<![\w.-])(' + '|'.join(re.escape(n) for n in unusual) + r')(?![\w.-])') if unusual else None

    def resolve_reference(value, file):
        if '/' not in value or '\n' in value or len(value) > 4096:
            return
        value = value.replace('${POKEMON_ENV}', str(root.parent)).replace('$POKEMON_ENV', str(root.parent))
        try:
            relative = Path(value).expanduser()
        except RuntimeError:
            # Archived prose can begin with a tilde without naming a real home.
            # Literal evidence names and templates still get protection below.
            location = root / file.relative_to(root).parts[0] if file.is_relative_to(root) else file
            warnings.add('unresolved home reference in ' + str(location))
            return
        candidates = [relative] if relative.is_absolute() else [base / relative for base in (file.parent, project, root, root.parent)]
        for candidate in candidates:
            try:
                if not candidate.exists() and not candidate.is_symlink():
                    continue
                parts = candidate.resolve().relative_to(root).parts
                for name in ([parts[0]] if parts else paths):
                    if name in paths:
                        reasons[name].add('resolved reference: ' + str(file))
            except (OSError, ValueError, RuntimeError):
                # Literal names and historical evidence paths are also matched
                # below, even when a reference can no longer resolve on disk.
                continue

    def references(file):
        if file.is_symlink():
            raise ValueError(f'symlink reference source: {file}')
        text = file.read_text()
        if file.suffix == '.json':
            # Decode escaped path characters; malformed inputs fail closed.
            try:
                value = json.loads(text)
            except ValueError as error:
                raise ValueError(f'malformed protection JSON {file}: {error}') from error
            text = json.dumps(value, ensure_ascii=False)
            pending_values = [value]
            while pending_values:
                value = pending_values.pop()
                if isinstance(value, dict):
                    pending_values.extend(value.values())
                elif isinstance(value, list):
                    pending_values.extend(value)
                elif isinstance(value, str) and (value.rstrip('/').endswith('/evidence')
                                                 or value == 'evidence/'):
                    for name in paths:
                        reasons[name].add('reference to evidence root: ' + str(file))
                elif isinstance(value, str):
                    resolve_reference(value, file)
        else:
            for value in re.findall(r'(?:/|~|\.\.?/|\$POKEMON_ENV)[^\s`"\'\)]+', text):
                resolve_reference(value, file)
        matches = {match[0] for match in tokens.finditer(text) if match[0] in paths}
        if unusual_pattern:
            matches.update(unusual_pattern.findall(text))
        for token in re.findall(r'evidence/([^\s`"\'\)]+)', text):
            component = token.split('/')[0].rstrip('.,;:')
            pattern = re.sub(r'<[^>]+>', '*', component)
            matches.update(name for name in paths if fnmatch.fnmatchcase(name, pattern))
        for name in matches:
            reasons[name].add('reference: ' + str(file))

    for file in sorted(sources):
        references(file)
    # Retained runs may depend on older runs via starting-save / receipts. Follow
    # their metadata until closure, including unknown directories and loose JSON.
    pending = set(root.glob('*.json'))
    scanned = set()
    while True:
        for name, path in paths.items():
            if name not in scanned and (reasons[name] or name not in eligible):
                pending.update(metadata_files(path))
                scanned.add(name)
        if not pending:
            break
        for file in sorted(pending):
            references(file)
        pending.clear()

    entries = []
    final_process_text = processes()
    for name, path in paths.items():
        if name not in eligible:
            reasons[name].add('classification uncertain or no successful replacement')
        elif not reasons[name]:
            if str(path) in final_process_text or re.search(r'(?<![\w.-])' + re.escape(name) + r'(?![\w.-])', final_process_text):
                reasons[name].add('live process reference')
            try:
                if inventory(path) != (sizes[name], stamps[name]):
                    reasons[name].add('changed during scan')
            except (OSError, ValueError) as error:
                reasons[name].add('changed during scan')
                warnings.add(str(error))
        entries.append({'path': str(path), 'bytes': sizes[name],
                        'action': 'keep' if reasons[name] else 'remove',
                        'reasons': sorted(reasons[name]) if reasons[name] else [eligible[name]]})
    return {'mode': 'dry-run', 'evidence': str(root), 'project': str(project),
            'bytes_basis': 'logical regular-file bytes; excludes filesystem overhead and clone sharing',
            'reclaimable_bytes': sum(e['bytes'] for e in entries if e['action'] == 'remove'),
            'candidate_count': sum(e['action'] == 'remove' for e in entries),
            'kept_count': sum(e['action'] == 'keep' for e in entries),
            'exclusions': dict(Counter(reason for e in entries if e['action'] == 'keep'
                                       for reason in {item.split(': ')[0] for item in e['reasons']})),
            'warnings': sorted(warnings), 'entries': entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=PROJECT, help='checkout containing current acceptance records')
    parser.add_argument('--env', type=Path, default=os.environ.get('POKEMON_ENV'), help='POKEMON_ENV directory (required)')
    parser.add_argument('--min-age-hours', type=float, default=1, help='keep entries changed within this many hours (minimum 1)')
    parser.add_argument('--execute', action='store_true', help='delete only the freshly computed eligible directories')
    args = parser.parse_args()
    if args.env is None:
        parser.error('set POKEMON_ENV or pass --env')
    if not 1 <= args.min_age_hours < float('inf'):
        parser.error('--min-age-hours must be finite and at least 1')
    project = args.project.expanduser().resolve(strict=True)
    env = args.env.expanduser().resolve(strict=True)
    root = env / 'evidence'
    if root.is_symlink() or not root.is_dir():
        parser.error('evidence must be a real directory directly under POKEMON_ENV')
    try:
        with ExitStack() as stack:
            if args.execute:
                # Cooperate with the existing runtime and suite ownership locks.
                # Never truncate their owner records or import the Simulator runner.
                for owner in ('suite', 'simulator'):
                    lock = Path('/private/tmp') / f'pokemon-playdate-{owner}-{os.getuid()}.lock'
                    stream = stack.enter_context(lock.open('a+'))
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            report = plan(project, root, args.min_age_hours)
            if args.execute:
                for entry in report['entries']:
                    if entry['action'] != 'remove':
                        continue
                    # Refresh references, process ownership and tree classification
                    # before every removal. Never execute a saved dry-run report.
                    fresh = plan(project, root, args.min_age_hours)
                    current = next(e for e in fresh['entries'] if e['path'] == entry['path'])
                    if current['action'] != 'remove' or current['bytes'] != entry['bytes']:
                        raise ValueError(f'evidence changed; stopped before removing {entry["path"]}')
                    path = Path(entry['path'])
                    if path.parent != root or path.is_symlink():
                        raise ValueError(f'unsafe removal boundary: {path}')
                    shutil.rmtree(path)
                    entry['action'] = 'removed'
                report['mode'] = 'execute'
            print(json.dumps(report, indent=2))
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Cleanup refused: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
