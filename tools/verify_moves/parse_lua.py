"""Fail-closed reader for declarative Lua tables, not a Lua evaluator/transpiler.

Only reads the named data tables; nested DSL expressions are retained as opaque
expressions. Any unsupported data declaration fails rather than disappearing.
"""
from dataclasses import dataclass
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r'\s+|--[^\n]*|"(?:\\.|[^"\\])*"|[A-Za-z_]\w*|-?\d+(?:\.\d+)?|.', re.S)


class ParseError(ValueError):
    pass


@dataclass(frozen=True)
class Expression:
    text: str


def to_camel_case(name):
    parts = name.split('-')
    return parts[0] + ''.join(part[:1].upper() + part[1:] for part in parts[1:])


def tokens(text):
    return [m.group() for m in TOKEN.finditer(text) if not m.group().isspace() and not m.group().startswith('--')]


class Reader:
    def __init__(self, values):
        self.tokens = values
        self.pos = 0

    def peek(self, offset=0):
        i = self.pos + offset
        return self.tokens[i] if i < len(self.tokens) else None

    def take(self, expected=None):
        value = self.peek()
        if value is None or (expected is not None and expected != value):
            raise ParseError(f'expected {expected}, got {value} at token {self.pos}')
        self.pos += 1
        return value

    def value(self):
        if self.peek() == '{':
            return self.table()
        start, depth = self.pos, 0
        while self.peek() is not None:
            token = self.peek()
            if depth == 0 and token in (',', '}'):
                break
            if token in ('{', '(', '['): depth += 1
            if token in ('}', ')', ']'): depth -= 1
            if depth < 0: raise ParseError('unbalanced expression')
            self.pos += 1
        seq = self.tokens[start:self.pos]
        if not seq or depth:
            raise ParseError('missing/unbalanced value')
        if len(seq) == 1:
            value = seq[0]
            if value.startswith('"'): return json.loads(value)
            if re.fullmatch(r'-?\d+', value): return int(value)
            if value == 'nil': return None
            if value in ('true', 'false'): return value == 'true'
        return Expression(' '.join(seq))

    def table(self):
        self.take('{')
        mapping, sequence = {}, []
        while self.peek() != '}':
            if self.peek() is None: raise ParseError('unterminated table')
            if self.peek(1) == '=':
                key = self.take(); self.take('=')
                if key in mapping: raise ParseError(f'duplicate key: {key}')
                # Move{...} wraps a declarative definition, never execute it.
                if self.peek() == 'Move' and self.peek(1) == '{': self.take('Move')
                mapping[key] = self.value()
            else:
                sequence.append(self.value())
            if self.peek() == ',': self.take(',')
            elif self.peek() != '}': raise ParseError('expected table separator')
        self.take('}')
        if mapping and sequence: raise ParseError('mixed tables are unsupported')
        return mapping if mapping else sequence


def read_table(path, name):
    values = tokens(Path(path).read_text())
    anchors = [i for i in range(len(values) - 2) if values[i:i+3] == [name, '=', '{']]
    if len(anchors) != 1: raise ParseError(f'expected one {name} declaration')
    reader = Reader(values)
    reader.pos = anchors[0] + 2
    table = reader.table()
    if not isinstance(table, dict) or not table: raise ParseError(f'{name} must be a nonempty keyed table')
    return table


class LuaParser:
    def __init__(self, lua_path=None):
        self.lua_path = Path(lua_path) if lua_path else ROOT / 'Source/data/pokemon.lua'

    def parse(self):
        rows = read_table(self.lua_path, 'pokemonData')
        dexes = set()
        for key, row in rows.items():
            if not isinstance(row, dict) or type(row.get('dex')) is not int or not isinstance(row.get('moves'), list):
                raise ParseError(f'invalid species definition: {key}')
            if row['dex'] in dexes: raise ParseError(f'duplicate dex: {row["dex"]}')
            dexes.add(row['dex'])
            if any(not isinstance(move, str) for move in row['moves']): raise ParseError(f'invalid move list: {key}')
        return rows

    def sorted_by_dex(self):
        return sorted(self.parse().items(), key=lambda item: item[1]['dex'])


def read_moves(path=None):
    rows = read_table(path or ROOT / 'Source/battle/moves.lua', 'moveData')
    for key, row in rows.items():
        if not isinstance(row, dict): raise ParseError(f'invalid move: {key}')
        for field in ('name', 'type', 'category'):
            if not isinstance(row.get(field), str): raise ParseError(f'{key}: invalid {field}')
        for field in ('power', 'accuracy', 'pp'):
            if type(row.get(field)) is not int: raise ParseError(f'{key}: invalid {field}')
    return rows
