#!/usr/bin/env python3
"""Verify ordered level-aware B2W2 data; exit 1 for content gaps, 2 for invalid inputs."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.verify_moves.compare import Oracle, verify
from tools.verify_moves.runtime_coverage import load_runtime_coverage
from tools.verify_moves.fetch_pokeapi import PinnedSources, SourceError
from tools.verify_moves.parse_lua import LuaParser, ParseError, ROOT, read_moves


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('species', nargs='*', help='local species keys; default all151')
    parser.add_argument('--fetch', action='store_true', help='download missing immutable pinned files; existing cache always verified')
    parser.add_argument('--cache', type=Path, help='directory containing the nine pinned CSVs')
    parser.add_argument('--pokemon', type=Path, default=ROOT / 'Source/data/pokemon.lua')
    parser.add_argument('--moves', type=Path, default=ROOT / 'Source/battle/moves.lua')
    parser.add_argument('--runtime-project', type=Path, help='explicit runtime source tree for separately labeled private proof; default current checkout')
    parser.add_argument('--runtime-evidence', type=Path, help='reviewed source+executed SDK subset registry; default checked-in snapshot')
    parser.add_argument('--output', type=Path, required=True, help='new JSON report; legacy reports are never rewritten')
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error('output already exists; choose a fresh report path')
    report = {}
    code = 2
    try:
        source = PinnedSources(args.cache, args.fetch)
        species, moves = LuaParser(args.pokemon).parse(), read_moves(args.moves)
        if args.species:
            missing = set(args.species) - species.keys()
            if missing: raise ParseError(f'unknown species filter: {sorted(missing)}')
            species = {key: species[key] for key in args.species}
        elif set(row['dex'] for row in species.values()) != set(range(1, 152)):
            raise ParseError('full roster must contain dex1..151 exactly')
        runtime = load_runtime_coverage(args.runtime_project or ROOT, moves, args.runtime_evidence)
        report = verify(species, moves, Oracle(source.all()), runtime)
        report['sources'] = source.manifest
        report['production_inputs'] = {str(path.resolve()): hashlib.sha256(path.read_bytes()).hexdigest()
                                       for path in (args.pokemon, args.moves, (args.runtime_project or ROOT) / 'Source/battle/battle.lua', (args.runtime_project or ROOT) / 'Source/battle/dsl.lua')}
        report['semantics_policy'] = 'Current reviewed handler+exact executed assertion hashes qualify only named subsets. Changed evidence becomes stale; no field-presence or historical static gap proves full runtime support.'
        code = 0 if report['ok'] else 1
        print(json.dumps(report['counts'], sort_keys=True))
        print('Learnset issue codes:', dict(Counter(issue['code'] for row in report['learnsets'] for issue in row['issues'])))
    except (OSError, ValueError, KeyError, TypeError) as error:
        report = {'ok': False, 'error': str(error), 'kind': 'source-or-schema-error'}
        print(str(error), file=sys.stderr)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Report: {args.output}')
    return code


if __name__ == '__main__':
    sys.exit(main())
