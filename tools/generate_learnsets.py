#!/usr/bin/env python3
"""Generate complete B2W2 level-up metadata from immutable raw CSVs.

Independent of the verifier comparator/oracle and battle-data generator.
Only the explicit --output file is written; --check never writes it.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.verify_moves.fetch_pokeapi import PinnedSources, SourceError
from tools.verify_moves.parse_lua import LuaParser, read_moves

VERSION_GROUP = 14


class GenerationError(ValueError):
    pass


def camel(identifier):
    head, *tail = identifier.split('-')
    return head + ''.join(part[:1].upper() + part[1:] for part in tail)


def collect_learnsets(move_rows, learned_rows, local_keys, dexes):
    names = {}
    for row in move_rows:
        identity = int(row['id'])
        if identity in names: raise GenerationError(f'duplicate source move ID {identity}')
        names[identity] = camel(row['identifier'])
    result = defaultdict(list)
    seen, missing = set(), set()
    for row in learned_rows:
        if int(row['version_group_id']) != VERSION_GROUP or int(row['pokemon_move_method_id']) != 1:
            continue
        dex, identity = int(row['pokemon_id']), int(row['move_id'])
        if dex not in dexes: continue
        if identity not in names: raise GenerationError(f'unknown source move ID {identity}')
        level = int(row['level'])
        order = int(row['order']) if row['order'] else None
        if not 0 <= level <= 100 or (order is not None and order < 0): raise GenerationError('invalid source level/order')
        signature = dex, identity, level, order
        if signature in seen: raise GenerationError(f'duplicate source learn event {signature}')
        seen.add(signature)
        key = names[identity]
        if key not in local_keys: missing.add(key)
        result[dex].append({'move': key, 'level': level, 'order': order, 'id': identity})
    if missing:
        raise GenerationError('missing production moveData definitions: ' + ', '.join(sorted(missing)))
    absent = dexes - result.keys()
    if absent: raise GenerationError(f'missing source learnsets for dex {sorted(absent)}')
    for entries in result.values():
        entries.sort(key=lambda e: (e['level'], e['order'] is None, e['order'] or 0, e['id']))
    return dict(result)


def initial_moves(entries, level):
    """Reference policy helper: forward FIFO4; known duplicates never reorder existing slots."""
    selected = []
    for entry in entries:
        if 1 <= entry['level'] <= level and entry['move'] not in selected:
            if len(selected) == 4: selected.pop(0)
            selected.append(entry['move'])
    return selected


def render(source, roster, learnsets):
    def replace(match):
        key, body = match.group(1), match.group(2)
        if key not in roster: raise GenerationError(f'unparsed species block {key}')
        body = re.sub(r'        -- BEGIN B2W2 LEARNSET\n.*?        -- END B2W2 LEARNSET\n', '', body, flags=re.S)
        entries = learnsets[roster[key]['dex']]
        lines = ['        moves = { ' + ', '.join(json.dumps(e['move']) for e in entries) + ' },',
                 '        -- BEGIN B2W2 LEARNSET', '        learnset = {']
        for entry in entries:
            order = 'nil' if entry['order'] is None else str(entry['order'])
            lines.append(f'            {{ move = "{entry["move"]}", level = {entry["level"]}, order = {order}, id = {entry["id"]} }},')
        lines.extend(['        }', '        -- END B2W2 LEARNSET'])
        body, count = re.subn(r'^        moves = \{[^\n]*\},?\n', '\n'.join(lines) + '\n', body, flags=re.M)
        if count != 1: raise GenerationError(f'expected one flat moves declaration for {key}')
        return '    ' + key + ' = {\n' + body + '    },'
    pattern = re.compile(r'^    (\w+) = \{\n(.*?)^    \},', re.M | re.S)
    generated, count = pattern.subn(replace, source)
    if count != len(roster): raise GenerationError(f'species coverage: rendered {count}, parsed {len(roster)}')
    generated = generated.replace('-- Gen 1 Pokemon data - all 151 Gen I species with Gen 5 (B/W) movesets',
                                  '-- Gen I species with complete B2W2 level-up learnsets (version group 14).')
    return generated


def generate(pokemon_path, moves_path, sources):
    roster = LuaParser(pokemon_path).parse()
    dexes = {entry['dex'] for entry in roster.values()}
    if dexes != set(range(1, 152)): raise GenerationError('expected the complete original 151-species roster')
    groups = sources.load('version_groups.csv')
    if not any(row['id'] == '14' and row['identifier'] == 'black-2-white-2' for row in groups):
        raise GenerationError('pinned version group identity mismatch')
    learnsets = collect_learnsets(sources.load('moves.csv'), sources.load('pokemon_moves.csv'), read_moves(moves_path).keys(), dexes)
    output = render(Path(pokemon_path).read_text(), roster, learnsets)
    metadata = {'version_group': VERSION_GROUP, 'source_revision': sources.manifest['revision'],
                'source_sha256': {name: sources.manifest['files'][name]['sha256'] for name in ('moves.csv', 'pokemon_moves.csv', 'version_groups.csv')},
                'species': len(roster), 'events': sum(len(entries) for entries in learnsets.values()),
                'move_keys': len({entry['move'] for entries in learnsets.values() for entry in entries}),
                'output_sha256': hashlib.sha256(output.encode()).hexdigest()}
    return output, metadata


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pokemon', type=Path, default=ROOT / 'Source/data/pokemon.lua')
    parser.add_argument('--moves', type=Path, default=ROOT / 'Source/battle/moves.lua')
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--fetch', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--check', action='store_true', help='compare to explicit output; nonzero for drift; never write')
    args = parser.parse_args(argv)
    try:
        content, metadata = generate(args.pokemon, args.moves, PinnedSources(args.cache, args.fetch))
        if args.check:
            if not args.output.is_file() or args.output.read_text() != content:
                raise GenerationError(f'generated learnset drift: {args.output}')
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            temporary = args.output.with_suffix(args.output.suffix + '.tmp')
            temporary.write_text(content)
            temporary.replace(args.output)
        print(json.dumps(metadata, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
