#!/usr/bin/env python3
"""Deterministic host-only inspect/trace/check CLI; deliberately no render command."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.audio.catalog import Catalog
from tools.audio.fixtures import run_fixtures
from tools.audio.oracle import qualify_bytes
from tools.audio.source import AudioError, REVISION, Source
from tools.audio.trace import Trace


def canonical(value):
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True)+'\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('inspect', 'trace', 'check'))
    parser.add_argument('--source', default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--revision', default=REVISION)
    parser.add_argument('--asset')
    parser.add_argument('--fixtures', action='store_true', help='check: execute representative traces and report bounds')
    parser.add_argument('--variant')
    parser.add_argument('--pitch', type=lambda x: int(x, 0), default=0)
    parser.add_argument('--length', type=lambda x: int(x, 0), default=128)
    parser.add_argument('--max-ticks', type=int, default=120000)
    parser.add_argument('--alarm', action='store_true')
    parser.add_argument('--events', type=Path, help='JSON list of tick/asset/pitch/length SFX requests')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--against', type=Path, help='Prior inspect output directory to compare exactly')
    args = parser.parse_args(argv)
    if not args.source:
        parser.error('--source or POKERED_REFERENCE_DIR is required')
    try:
        catalog = Catalog(Source(args.source, args.revision))
        report = catalog.report()
        oracle = qualify_bytes(catalog)
        # Oracle consumes its own macro dependencies too; include those pins.
        report['consumed_sha256'] = dict(sorted(catalog.source.hashes.items()))
        args.output.mkdir(parents=True, exist_ok=True)
        if args.command == 'trace':
            if not args.asset:
                parser.error('trace requires --asset')
            header = catalog.headers.get(args.asset)
            if header is None:
                raise AudioError(f'unknown asset {args.asset}')
            tracer = Trace(catalog, header['family'])
            tracer.load(args.asset, args.pitch, args.length)
            if args.variant: tracer.variant(args.variant)
            scheduled = json.loads(args.events.read_text()) if args.events else []
            result = tracer.run(args.max_ticks, scheduled, args.alarm)
            result['tool_sha256'] = report['tool_sha256']
            result['byte_oracle'] = oracle
            result['asset'] = args.asset
            result['variant'] = args.variant
            result['revision'] = catalog.source.revision
            result['consumed_sha256'] = report['consumed_sha256']
            (args.output/'trace.json').write_text(canonical(result))
            if result['status'] == 'bound':
                raise AudioError(f'trace did not end or repeat within {args.max_ticks} ticks; see trace.json')
        else:
            payload = canonical(report)
            if args.command == 'check' and args.against:
                if payload != (args.against/'catalog.json').read_text():
                    raise AudioError('catalog differs from --against catalog.json')
                if canonical(oracle) != (args.against/'byte-oracle.json').read_text():
                    raise AudioError('byte oracle differs from --against byte-oracle.json')
            (args.output/'catalog.json').write_text(payload)
            (args.output/'byte-oracle.json').write_text(canonical(oracle))
            fixtures = None
            if args.fixtures:
                fixtures = run_fixtures(catalog, args.output/'fixtures', args.max_ticks)
                (args.output/'fixtures.json').write_text(canonical(fixtures))
            (args.output/'check.json').write_text(canonical({
                'status': 'bounded' if fixtures and fixtures['bounded'] else 'pass',
                'revision': catalog.source.revision,
                'nonclosing_fixtures': fixtures['bounded'] if fixtures else [],
                'catalog_sha256': hashlib.sha256(payload.encode()).hexdigest(),
                'reference_count': len(catalog.references), 'unresolved': [],
                'byte_oracle': oracle['method']}))
            if fixtures and fixtures['bounded']:
                raise AudioError('nonclosing fixture bounds: '+', '.join(fixtures['bounded']))
        print(f'{args.command}: {args.output}')
        return 0
    except (AudioError, OSError, ValueError) as exc:
        print(f'audio: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
