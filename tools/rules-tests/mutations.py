#!/usr/bin/env python3
"""Stage isolated SDK contract mutants; compile by default, execute only on request.

Never changes production Source. Runtime execution uses the harness's SDK-wide
owner lock, UUID bundle IDs, exact-build handshake and process cleanup.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from tools.harness import run as harness  # noqa: E402
from tools.harness.protocol import atomic_json  # noqa: E402

BASELINE = '1cb82252e4d591e9819fdd23caa234e02128263c'
EXPECTED = {
    'control': [],
    'old-state-machine': ['State push during update waits for next update pass',
                          'Changed listener transitions wait until enter completes'],
    'old-signal': ['Signal clear cancels in-flight callbacks and permits new listeners',
                   'Signal errors unwind emission bookkeeping'],
    'shared-rng': ['Battle rules replay survives cosmetic RNG and repeated real SDK draws',
                    'Encounter selection and DSL random values replay independently'],
    'draw-timer': ['Battle scene draw is read-only; update preserves 20-frame iris and effects'],
}


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError(f'mutation anchor must occur once: {old!r}')
    return text.replace(old, new, 1)


def mutate(source, variant):
    if variant == 'control':
        return []
    if variant in ('old-state-machine', 'old-signal'):
        relative = 'lib/statemachine.lua' if variant == 'old-state-machine' else 'lib/oop.lua'
        content = subprocess.check_output(['git', 'show', f'{BASELINE}:Source/{relative}'], cwd=PROJECT)
    elif variant == 'shared-rng':
        relative = 'lib/rng.lua'
        content = replace_once((source / relative).read_text(),
                               'function RulesRNG.random(low, high) return rules:random(low, high) end',
                               'function RulesRNG.random(low, high)\n'
                               '    if low == nil then return math.random() end\n'
                               '    if high == nil then return math.random(low) end\n'
                               '    return math.random(low, high)\nend').encode()
    else:
        relative = 'battle/battleScene.lua'
        content = replace_once((source / relative).read_text(), 'function BattleScene:draw()\n',
                               'function BattleScene:draw()\n    self.introTimer = self.introTimer + 1 -- deliberate defect\n').encode()
    target = source / relative
    before = target.read_bytes()
    if before == content:
        raise RuntimeError(f'mutation {variant} did not change {relative}')
    target.write_bytes(content)
    return [{'path': relative, 'before_sha256': hashlib.sha256(before).hexdigest(),
             'after_sha256': hashlib.sha256(content).hexdigest()}]



def prepare_wrapper(original_prepare, variant):
    def prepare(project, sdk, output, session):
        metadata = original_prepare(project, sdk, output, session)
        source = output / 'Source'
        changes = mutate(source, variant)
        # Hash the frozen staged input, never reread live project Source.
        pdxinfo = source / 'pdxinfo'
        generated_pdxinfo = pdxinfo.read_text()
        pdxinfo.write_text(metadata['original_pdxinfo'])
        metadata['source_sha256'] = harness.fingerprint(output)
        source_manifest = {str(path.relative_to(source)): hashlib.sha256(path.read_bytes()).hexdigest()
                           for path in sorted(source.rglob('*')) if path.is_file()
                           and path.relative_to(source).as_posix() != 'dev/harness_build.lua'}
        atomic_json(output / 'source-manifest.json', source_manifest)
        pdxinfo.write_text(generated_pdxinfo)
        metadata['build_id'] = metadata['revision'] + ':' + metadata['source_sha256']
        metadata['mutation'] = {'variant': variant, 'baseline': BASELINE, 'changes': changes}
        values = []
        for key in ('protocol', 'session_id', 'build_id', 'output_dir', 'bundle_id', 'sdk_version', 'enabled', 'data_dir'):
            value = metadata[key]
            values.append(f'    {key} = ' + ('true' if value is True else json.dumps(value, ensure_ascii=False)) + ',')
        (source / 'dev/harness_build.lua').write_text('HarnessBuild = {\n' + '\n'.join(values) + '\n}\n')
        metadata['compiled_source_sha256'] = harness.fingerprint(output, exclude_generated=False)
        with (output / 'mutation-build.log').open('w') as log:
            subprocess.run([str(sdk / 'bin/pdc'), str(source), metadata['bundle']],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        atomic_json(output / 'build.json', metadata)
        return metadata
    return prepare


def inspect_run(output, variant, returncode):
    results = sorted(output.glob('[0-9][0-9][0-9][0-9][0-9]-result.json'))
    reports, evidence = [], []
    for path in results:
        result = json.loads(path.read_text())
        for entry in result.get('results', []):
            if entry.get('contracts'):
                reports.append(entry['contracts'])
                evidence.append(path)
    if len(reports) != 1:
        raise RuntimeError(f'{variant}: expected exactly one actual SDK contract report, found {len(reports)} across {len(results)} results')
    report = reports[0]
    failed = {test['name'] for test in report['tests'] if not test['ok']}
    missing = set(EXPECTED[variant]) - failed
    if missing:
        raise RuntimeError(f'{variant}: expected contracts did not fail: {sorted(missing)}; actual failures: {sorted(failed)}')
    if variant == 'control':
        if returncode != 0 or not report['ok'] or report['failed'] != 0:
            raise RuntimeError(f'control contracts failed: {report}')
    elif returncode == 0 or report['ok'] or not failed:
        raise RuntimeError(f'{variant}: mutant was incorrectly accepted')
    return {'variant': variant, 'qualified': True, 'returncode': returncode,
            'passed': report['passed'], 'failed': report['failed'], 'failed_tests': sorted(failed),
            'evidence': str(evidence[0])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, help='fresh parent evidence directory')
    parser.add_argument('--sdk')
    parser.add_argument('--execute', action='store_true', help='launch owner-controlled SDK sessions; default compile only')
    parser.add_argument('--variants', nargs='+', choices=list(EXPECTED), default=list(EXPECTED))
    args = parser.parse_args()
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    original_prepare = harness.prepare
    summary = {'ok': True, 'executed': args.execute, 'variants': []}
    try:
        for variant in args.variants:
            destination = output / variant
            harness.prepare = prepare_wrapper(original_prepare, variant)
            options = SimpleNamespace(sdk=args.sdk, output=str(destination), scenario=None,
                                      commands=['contracts'], build_only=not args.execute,
                                      timeout=60, ready_timeout=20, max_frames=1800)
            try:
                code = harness.run(options)
                if args.execute:
                    item = inspect_run(destination, variant, code)
                else:
                    if code != 0:
                        raise RuntimeError(f'{variant}: compilation returned {code}')
                    item = {'variant': variant, 'compiled': True, 'evidence': str(destination / 'build.json')}
            except Exception as error:
                summary['ok'] = False
                item = {'variant': variant, 'qualified': False, 'error': str(error)}
            summary['variants'].append(item)
            atomic_json(output / 'qualification.json', summary)
            print(json.dumps(item), flush=True)
    finally:
        harness.prepare = original_prepare
    return 0 if summary['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
