#!/usr/bin/env python3
"""Re-run the cited SDK move suites and refresh verified proof hashes.

The registry's owner and assertion hashes are rewritten from the source the
harness just executed. Each cited suite gets its own boot: one session cannot
hold every suite inside the 16 MiB pool. source_gap and source_only rows are
left untouched: they have no executed proof, so a new hash would requalify
them without one.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.verify_moves.parse_lua import read_moves
from tools.verify_moves.runtime_coverage import definition_hash, region

REGISTRY = ROOT / 'tools/references/runtime-move-coverage.json'
EVIDENCE = ROOT / 'docs/validation/coverage-evidence/move-proofs-rerun.json'
SUMMARY = ROOT / 'docs/validation/coverage-evidence/move-proofs-rerun-summary.json'


def cited_tests(registry):
    ordered = []
    seen = set()
    for entry in registry['moves'].values():
        for proof in entry['tests']:
            name = proof['accepted_name']
            if name not in seen:
                seen.add(name)
                ordered.append(name)
    return ordered


def cited_suites(registry):
    suites = []
    seen = set()
    for name in cited_tests(registry):
        suite = name.split(': ', 1)[0]
        if suite not in seen:
            seen.add(suite)
            suites.append(suite)
    return suites


def current_hash(project, proof):
    body = region(project, proof)
    if body is None:
        raise SystemExit('proof region missing: ' + proof.get('path', '') + ' ' + proof.get('start', ''))
    return hashlib.sha256(body.encode()).hexdigest()


def test_record(name, value):
    """Keep the SDK's own test object. A bare true is only the host fixture."""
    if value is True:
        return {'name': name, 'ok': True}
    if isinstance(value, dict) and value.get('name') == name and value.get('ok') is True:
        return value
    raise SystemExit('SDK test record is not a pass: ' + name)


def apply_refresh(registry, project, passed_names, build_id, source_sha256):
    """Return updated registry, SDK evidence and summary. Refuse a partial run."""
    required = cited_tests(registry)
    missing = [name for name in required if name not in passed_names]
    if missing:
        raise SystemExit('SDK run did not pass every cited test: ' + ', '.join(missing[:8]))
    moves = read_moves(project / 'Source/battle/moves.lua')
    updated = json.loads(json.dumps(registry))
    refreshed = []
    held = []
    records = {name: test_record(name, passed_names[name]) for name in required}
    for key, entry in updated['moves'].items():
        if entry['state'] != 'verified_subset':
            held.append(key)
            continue
        entry['definition_sha256'] = definition_hash(moves[key])
        for proof in entry['owners']:
            proof['sha256'] = current_hash(project, proof)
        for proof in entry['tests']:
            proof['sha256'] = current_hash(project, proof)
            proof['executed'] = records[proof['accepted_name']]
        refreshed.append(key)
    by_suite = {}
    for name in required:
        by_suite.setdefault(name.split(': ', 1)[0], []).append(records[name])
    suites = [{'id': suite, 'ok': True, 'passed': len(tests), 'failed': 0} for suite, tests in by_suite.items()]
    passed = len(required)
    evidence = {
        'build_id': build_id,
        'failed': 0,
        'mode': 'production',
        'ok': True,
        'passed': passed,
        'protocol': 1,
        'results': [{
            'contracts': {
                'failed': 0,
                'ok': True,
                'passed': passed,
                'suites': suites,
                'tests': [test for tests in by_suite.values() for test in tests],
            },
            'op': 'contracts',
            'outcome': 'ok',
            'status': 'ok',
        }],
        'session_id': build_id.split(':', 1)[0],
        'simulator': True,
        'status': 'ok',
    }
    if not build_id.endswith(':' + source_sha256):
        raise SystemExit('SDK build id does not name the executed source')
    summary = {
        'schema': 1,
        'source_sha256': source_sha256,
        'sdk': {'passed': passed, 'failed': 0},
        'scope': 'Cited assertions re-executed on the current source. source_gap and source_only rows were not requalified.',
        'acceptance_context': registry.get('acceptance_context', 'accepted-main950'),
        'build_id': build_id,
        'refreshed_verified_subset': sorted(refreshed),
        'held_without_executed_proof': sorted(held),
    }
    return updated, evidence, summary


def bind_outputs(registry, evidence_bytes, summary_bytes):
    evidence_hash = hashlib.sha256(evidence_bytes).hexdigest()
    summary_hash = hashlib.sha256(summary_bytes).hexdigest()
    summary = json.loads(summary_bytes)
    evidence = json.loads(evidence_bytes)
    registry['accepted_summary'] = {
        'path': SUMMARY.relative_to(ROOT).as_posix(),
        'sha256': summary_hash,
        'source_sha256': summary['source_sha256'],
        'sdk_passed': summary['sdk']['passed'],
    }
    registry['sdk_result_sha256'] = evidence_hash
    registry['sdk_result'] = {
        'path': EVIDENCE.relative_to(ROOT).as_posix(),
        'sha256': evidence_hash,
        'source_sha256': summary['source_sha256'],
        'build_id': evidence['build_id'],
        'passed': evidence['passed'],
        'failed': 0,
        'suite_count': len(evidence['results'][0]['contracts']['suites']),
        'suite_passed': evidence['passed'],
    }
    return registry


def passed_from_evidence(evidence_dir):
    passed = {}
    build_id = None
    for path in sorted(Path(evidence_dir).glob('[0-9][0-9][0-9][0-9][0-9]-result.json')):
        packet = json.loads(path.read_text())
        if packet.get('status') != 'ok':
            raise SystemExit('SDK command failed: ' + path.name)
        build_id = packet.get('build_id', build_id)
        for result in packet.get('results', []):
            report = result.get('contracts')
            if not report:
                continue
            if report.get('ok') is not True or report.get('failed', 1) != 0:
                raise SystemExit('contract suite failed: ' + path.name)
            for test in report['tests']:
                if test.get('ok') is True and isinstance(test.get('name'), str):
                    passed[test['name']] = test
    if build_id is None:
        raise SystemExit('SDK evidence has no build id')
    return passed, build_id


def execute(output):
    """One boot per suite. One session cannot hold every cited suite in the 16 MiB pool."""
    registry = json.loads(REGISTRY.read_text())
    suites = cited_suites(registry)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    passed = {}
    build_id = None
    source_sha256 = None
    for index, suite in enumerate(suites, 1):
        suite_dir = output / f'{index:02d}-{suite}'
        command = [sys.executable, '-m', 'tools.harness.run', '--output', str(suite_dir),
                   '--timeout', '300', '--ready-timeout', '150', '--max-frames', '18000',
                   'contracts ' + suite]
        completed = subprocess.run(command, cwd=ROOT)
        if completed.returncode != 0:
            raise SystemExit(completed.returncode)
        suite_passed, suite_build = passed_from_evidence(suite_dir)
        metadata = json.loads((suite_dir / 'build.json').read_text())
        if metadata['build_id'] != suite_build:
            raise SystemExit('result build id disagrees with build.json')
        if build_id is None:
            build_id = suite_build
            source_sha256 = metadata['source_sha256']
        elif suite_build != build_id or metadata['source_sha256'] != source_sha256:
            raise SystemExit('cited suites did not share one source build')
        passed.update(suite_passed)
        print('passed', suite, len(suite_passed), flush=True)
    updated, evidence, summary = apply_refresh(
        registry, ROOT, passed, build_id, source_sha256)
    evidence_bytes = (json.dumps(evidence, indent=2) + '\n').encode()
    summary_bytes = (json.dumps(summary, indent=2) + '\n').encode()
    EVIDENCE.write_bytes(evidence_bytes)
    SUMMARY.write_bytes(summary_bytes)
    bind_outputs(updated, evidence_bytes, summary_bytes)
    REGISTRY.write_text(json.dumps(updated, indent=2) + '\n')
    print('refreshed', len(summary['refreshed_verified_subset']),
          'held', ','.join(summary['held_without_executed_proof']))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--output', type=Path, required=False)
    args = parser.parse_args(argv)
    if not args.execute:
        registry = json.loads(REGISTRY.read_text())
        print('suites', ' '.join(cited_suites(registry)))
        print('cited', len(cited_tests(registry)))
        return 0
    if args.output is None:
        parser.error('--execute requires --output')
    execute(args.output)
    return 0


if __name__ == '__main__':
    sys.exit(main())
