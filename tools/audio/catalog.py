"""Resolve the complete pinned Blue score/header graph, without assembling game code."""
from collections import Counter
from dataclasses import dataclass
import re
import hashlib
from pathlib import Path

from .codec import ARITY, encode
from .source import AudioError, Line, number, parts, qualify

BANKS = {1: 2, 2: 8, 3: 31}


@dataclass
class Command:
    line: Line
    op: str
    args: list
    scope: str
    offset: int
    data: bytes


class Catalog:
    def __init__(self, source):
        self.source = source
        self.labels = {}
        self.commands = {}
        self.sections = {}
        self.headers = {}
        self.coverage = Counter()
        self.references = []
        self.conditionals = []
        self._load()

    @staticmethod
    def key(family, label):
        return f'audio{family}:{label}'

    def target(self, family, label, scope=''):
        key = self.key(family, qualify(label, scope))
        if key not in self.labels:
            raise AudioError(f'unresolved label {key}')
        return self.labels[key]

    def _load(self):
        # Hash every semantic dependency, including assembly engines interpreted by trace.py.
        for path in ['macros/scripts/audio.asm', 'constants/audio_constants.asm',
                     'constants/hardware.inc', 'constants/music_constants.asm', 'layout.link',
                     'ram/wram.asm', 'home/audio.asm', 'home/pokemon.asm', 'home/vblank.asm',
                     'audio/alternate_tempo.asm', 'audio/low_health_alarm.asm',
                     'audio/poke_flute.asm', 'audio/play_battle_music.asm']:
            self.source.read(path)
        for family in BANKS:
            self.source.read(f'audio/engine_{family}.asm')
        section = None
        scope = ''
        for line in self.source.lines('audio.asm'):
            match = re.fullmatch(r'SECTION "(.*?)", ROMX', line.text)
            if match:
                name = match[1]
                selected = re.fullmatch(r'(Sound Effects|Music) ([123])', name)
                section = (int(selected[2]), selected[1]) if selected else None
                if section:
                    self.sections[section] = bytearray()
                    scope = ''
                continue
            if section is None:
                continue
            if line.text.startswith('Audio') and line.text.endswith(':'):
                scope = line.text.rstrip(':')
                self.labels[self.key(section[0], scope)] = (section, len(self.sections[section]))
                continue
            match = re.fullmatch(r'INCLUDE "([^"]+)"', line.text)
            if not match:
                line.fail('unsupported audio layout statement')
            scope = self._data(section, match[1], scope)
        # Resolve relocations only after all bank-local labels exist.
        for (section, offset), cmd in self.commands.items():
            if cmd.op in ('sound_call', 'sound_loop', 'dw'):
                names = cmd.args if cmd.op == 'dw' else [cmd.args[-1]]
                for label in names:
                    try:
                        target = self.target(section[0], label, cmd.scope)
                    except AudioError as exc:
                        cmd.line.fail(str(exc))
                    if target[0] != section:
                        cmd.line.fail('cross-section data pointer requires a linked address model')
                    self.references.append({'from': cmd.line.location, 'target': self.key(section[0], qualify(label, cmd.scope))})
                    if cmd.op != 'dw' and target not in self.commands:
                        cmd.line.fail(f'control target is not a command: {label}')
                resolve = lambda label: self.target(section[0], label, cmd.scope)[1]
                if cmd.op == 'dw':
                    data = b''.join(bytes((resolve(x)&255, resolve(x)>>8)) for x in names)
                else:
                    data = encode(cmd.op, cmd.args, resolve)
                self.sections[section][offset:offset+len(data)] = data
                cmd.data = data
        for family in BANKS:
            self._headers(family)
        self._routes()
        self.notes = [number(parts(l)[1][0]) for l in self.source.lines('audio/notes.asm') if parts(l)[0] == 'dw']
        self.variants = {}
        for line in self.source.lines('audio/alternate_tempo.asm'):
            if line.text.endswith('::'):
                variant = line.text.rstrip(':')
                self.variants[variant] = []
            match = re.fullmatch(r'ld de, (Music_\w+)', line.text)
            if match:
                self.target(1, match[1])
                self.references.append({'from': line.location, 'target': self.key(1, match[1])})
                self.variants[variant].append(match[1])
        self.variants['Music_PokeFluteInBattle'] = ['SFX_Pokeflute_Ch5', 'SFX_Pokeflute_Ch6', 'SFX_Pokeflute_Ch7']
        for label in self.variants['Music_PokeFluteInBattle']:
            self.target(2, label)
            self.references.append({'from': 'audio/poke_flute.asm', 'target': self.key(2, label)})

    def _data(self, section, path, scope):
        data = self.sections[section]
        # Conditionals are included in provenance even though inactive Red commands are excluded.
        for i, raw in enumerate(self.source.read(path).splitlines(), 1):
            if raw.strip().startswith('IF '):
                self.conditionals.append({'file': path, 'line': i, 'expression': raw.strip()[3:], 'defines': ['_BLUE']})
        for line in self.source.lines(path):
            text = line.text
            if text.endswith(':') or re.fullmatch(r'\.\w+', text):
                label = text.rstrip(':')
                label = qualify(label, scope)
                if not text.startswith('.'):
                    scope = label
                key = self.key(section[0], label)
                if key in self.labels:
                    line.fail(f'duplicate label {key}')
                self.labels[key] = (section, len(data))
                continue
            op, args = parts(line)
            offset = len(data)
            try:
                if op == 'dw':
                    encoded = bytes(2*len(args))
                elif op == 'dn':
                    values = [number(x) for x in args]
                    if len(values) % 2 or any(not 0 <= v <= 15 for v in values):
                        line.fail('invalid dn')
                    encoded = bytes(values[i]<<4 | values[i+1] for i in range(0, len(values), 2))
                else:
                    encoded = encode(op, args)
            except AudioError as exc:
                line.fail(str(exc))
            self.commands[(section, offset)] = Command(line, op, args, scope, offset, encoded)
            self.coverage[op] += 1
            data.extend(encoded)
        return scope

    def _headers(self, family):
        offset = 0
        for kind in ('sfx', 'music'):
            expected = None
            header = None
            for line in self.source.lines(f'audio/headers/{kind}headers{family}.asm'):
                if line.text.endswith(':'):
                    if expected is not None and len(header['channels']) != expected:
                        line.fail('incomplete channel header')
                    label = line.text.rstrip(':')
                    header = {'key': self.key(family, label), 'bank': BANKS[family],
                              'family': family, 'label': label, 'kind': kind,
                              'id': offset//3, 'header_offset': offset, 'channels': [],
                              'source': line.location}
                    expected = None
                else:
                    op, args = parts(line)
                    if op == 'db' and args == ['$ff', '$ff', '$ff']:
                        offset += 3
                    elif op == 'channel_count':
                        expected = number(args[0])
                        if not 1 <= expected <= 4:
                            line.fail('invalid channel count')
                        self.headers[header['key']] = header
                    elif op == 'channel':
                        ch = number(args[0])
                        if expected is None or not 1 <= ch <= 8:
                            line.fail('channel outside header')
                        try:
                            self.target(family, args[1])
                        except AudioError as exc:
                            line.fail(str(exc))
                        header['channels'].append({'channel': ch, 'entry': args[1],
                                                   'header_byte': ((expected-1)<<6 if not header['channels'] else 0) | (ch-1)})
                        self.references.append({'from': line.location, 'target': self.key(family, args[1])})
                        offset += 3
                    else:
                        line.fail(f'unsupported header {op}')
            if expected is not None and len(header['channels']) != expected:
                line.fail('incomplete final header')

    def _routes(self):
        symbols = {}
        for line in self.source.lines('constants/music_constants.asm'):
            if line.text.startswith('music_const '):
                _, args = parts(line)
                symbols[args[0]] = args[1]
        self.music_symbols = symbols

        def resolve(symbol, family):
            if symbol not in symbols:
                raise AudioError(f'unknown route symbol {symbol}')
            label = symbols[symbol]
            label = re.sub(r'_[123]$', f'_{family}', label)
            key = self.key(family, label)
            if key not in self.headers:
                raise AudioError(f'unresolved routed header {key}')
            return key

        map_ids = self._constants('constants/map_constants.asm')
        self.maps = []
        for line in self.source.lines('data/maps/songs.asm'):
            op, args = parts(line)
            if op != 'db':
                continue
            if len(args) != 2 or not re.fullmatch(r'BANK\(Music_\w+\)', args[1]):
                line.fail('unsupported map route')
            label = args[1][5:-1]
            family = next((f for f in BANKS if self.key(f, label) in self.headers), None)
            if family is None:
                line.fail(f'unknown map music {label}')
            key = resolve(args[0], family)
            if key != self.key(family, label):
                line.fail('map bank/symbol mismatch')
            if map_ids.get(line.comment) != len(self.maps):
                line.fail('map route/index mismatch')
            self.references.append({'from': line.location, 'target': key})
            self.maps.append({'map_id': len(self.maps), 'map': line.comment, 'asset': key, 'symbol': args[0]})
        move_ids = self._constants('constants/move_constants.asm')
        self.moves = []
        self.move_sentinel = None
        for line in self.source.lines('data/moves/sfx.asm'):
            op, args = parts(line)
            if op == 'db':
                try:
                    key = resolve(args[0], 2)
                    self.references.append({'from': line.location, 'target': key})
                    route = {'move_id': len(self.moves)+1, 'move': line.comment,
                             'asset': key, 'symbol': args[0],
                             'pitch': number(args[1]), 'length': number(args[2])}
                    if not line.comment:
                        route.pop('move_id')
                        route['purpose'] = 'trailing source sentinel after NUM_ATTACKS assertion'
                        self.move_sentinel = route
                    else:
                        if move_ids.get(line.comment) != route['move_id']:
                            line.fail('move route/index mismatch')
                        self.moves.append(route)
                except AudioError as exc:
                    line.fail(str(exc))
        dex = []
        for line in self.source.lines('data/pokemon/dex_order.asm'):
            op, args = parts(line)
            if op == 'db':
                dex.append(args[0])
        dex_ids = self._constants('constants/pokedex_constants.asm')
        species_ids = self._constants('constants/pokemon_constants.asm')
        rows = []
        for line in self.source.lines('data/pokemon/cries.asm'):
            if line.text.startswith('mon_cry '):
                _, args = parts(line)
                rows.append((args, line))
        self.cries = []
        for internal_id, ((args, line), species) in enumerate(zip(rows, dex), 1):
            entries = {str(f): resolve(args[0], f) for f in BANKS}
            for key in entries.values():
                self.references.append({'from': line.location, 'target': key})
            if species == '0':
                continue
            name = species.removeprefix('DEX_')
            if species_ids.get(name) != internal_id:
                line.fail('internal species index mismatch')
            base = int(args[0].removeprefix('SFX_CRY_'), 16)
            self.cries.append({'species': name.lower(), 'internal_id': internal_id,
                               'dex_id': dex_ids[species], 'base': base, 'pitch': number(args[1]),
                               'length': number(args[2]), 'assets': entries})
        if len(rows) != len(dex) or len(self.cries) != 151 or len({x['dex_id'] for x in self.cries}) != 151:
            raise AudioError('cry/species table closure failed')

    def _constants(self, path):
        result = {}
        current = 0
        for line in self.source.lines(path):
            op, args = parts(line)
            if op == 'const_def': current = number(args[0]) if args else 0
            elif op == 'const_skip': current += number(args[0]) if args else 1
            elif op in ('const', 'map_const'):
                result[args[0]] = current
                current += 1
        return result

    def report(self):
        encoded = Counter((f'audio{section[0]}:{section[1]}:{cmd.data[0]:02x}')
                          for (section, _), cmd in self.commands.items() if cmd.op not in ('dn', 'dw'))
        return {'schema': 1,
                'tool_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in sorted(Path(__file__).parent.glob('*.py'))},
                'revision': self.source.revision, 'defines': ['_BLUE'],
                'consumed_sha256': dict(sorted(self.source.hashes.items())),
                'banks': {f'audio{f}': bank for f, bank in BANKS.items()},
                'address_policy': 'isolated section offsets; not linked ROM addresses',
                'music_constants': {symbol: {'label': label, 'expression': f'(({label} - SFX_Headers_1) / 3)'}
                                    for symbol, label in sorted(self.music_symbols.items())},
                'headers': list(self.headers.values()), 'maps': self.maps, 'cries': self.cries,
                'moves': self.moves, 'move_sentinel': self.move_sentinel, 'variants': self.variants, 'blue_conditionals': self.conditionals,
                'opcode_coverage': dict(sorted(self.coverage.items())),
                'encoded_opcode_counts': dict(sorted(encoded.items())),
                'reference_closure': {'resolved': len(self.references), 'unresolved': [], 'references': self.references},
                'labels': {key: {'section': value[0][1], 'offset': value[1]} for key, value in sorted(self.labels.items())}}
