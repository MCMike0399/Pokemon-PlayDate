#!/usr/bin/env python3
"""Decode pinned Route 1 / Viridian Mart into staged map data and opaque previews.

No network, ROM, runtime Source writes, Lua rewriting, or Simulator execution.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
SCHEMA = 1
PILOT_MAPS = ('Route1', 'ViridianMart')
LIGHT = (0xBB, 0xFF, 0xEE, 0xFF, 0xBB, 0xFF, 0xEE, 0xFF)
DARK = (0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA)
CODES = '.12#'


class MapError(ValueError):
    pass


def sha(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + '\n').encode()


class Reference:
    """Read each immutable source once, verifying its consumed bytes first."""
    def __init__(self, root, pins=None):
        self.root = Path(root).expanduser().resolve()
        if not self.root.is_dir():
            raise MapError(f'explicit reference directory missing: {self.root}')
        if pins is None:
            main = json.loads((ROOT / 'tools/references/kanto-source.json').read_text())
            extra = json.loads((ROOT / 'tools/references/map-pilot.json').read_text())
            if main.get('revision') != REVISION or extra.get('revision') != REVISION:
                raise MapError('reference pin revision mismatch')
            pins = {row['path']: row['sha256'] for row in main['files']}
            for row in extra['additional_source_files']:
                if row['path'] in pins and pins[row['path']] != row['sha256']:
                    raise MapError('conflicting source pins')
                pins[row['path']] = row['sha256']
        self.pins = dict(pins)
        self.consumed = {}
        self.cache = {}

    def bytes(self, relative):
        relative = str(relative)
        if relative not in self.pins:
            raise MapError(f'unpinned consumed source: {relative}')
        if relative not in self.cache:
            path = (self.root / relative).resolve()
            if not path.is_relative_to(self.root):
                raise MapError('source escapes explicit reference directory')
            try:
                content = path.read_bytes()
            except OSError as error:
                raise MapError(f'missing source {relative}') from error
            actual = sha(content)
            if actual != self.pins[relative]:
                raise MapError(f'source checksum mismatch: {relative}')
            self.cache[relative] = content
            self.consumed[relative] = actual
        return self.cache[relative]

    def text(self, relative):
        return self.bytes(relative).decode('utf-8')


def integer(token):
    token = token.strip()
    try:
        return int(token[1:], 16) if token.startswith('$') else int(token, 10)
    except ValueError as error:
        raise MapError(f'unsupported numeric expression: {token}') from error


def records(text, macro):
    found = []
    for line_number, line in enumerate(text.splitlines(), 1):
        clean = line.split(';', 1)[0].strip()
        match = re.fullmatch(re.escape(macro) + r'(?:\s+(.*))?', clean)
        if match:
            found.append({'args': [part.strip() for part in (match[1] or '').split(',') if part.strip()], 'line': line_number})
    return found


def blue_text(text):
    result, stack, active = [], [], True
    for line in text.splitlines():
        clean = line.split(';', 1)[0].strip()
        match = re.fullmatch(r'IF DEF\((_RED|_BLUE)\)', clean)
        if match:
            branch = match[1] == '_BLUE'
            stack.append((active, branch))
            active = active and branch
        elif clean == 'ELSE':
            if not stack: raise MapError('unmatched version ELSE')
            parent, branch = stack[-1]
            stack[-1] = parent, not branch
            active = parent and not branch
        elif clean == 'ENDC':
            if not stack: raise MapError('unmatched version ENDC')
            active, _ = stack.pop()
        elif re.match(r'(IF|ELIF)\b', clean):
            raise MapError('unsupported version conditional: ' + clean)
        elif active:
            result.append(line)
    if stack: raise MapError('unterminated version conditional')
    return '\n'.join(result)


def map_constants(reference):
    values = {}
    for row in records(reference.text('constants/map_constants.asm'), 'map_const'):
        if len(row['args']) != 3: raise MapError('invalid map constant')
        name, width, height = row['args']
        values[name] = {'id': len(values), 'width': integer(width), 'height': integer(height)}
    return values


def bindings(text, suffix):
    result, pending = {}, []
    for line in text.splitlines():
        match = re.match(r'(\w+)_' + re.escape(suffix) + r'::?', line)
        if match: pending.append(match[1])
        match = re.search(r'INCBIN "([^"]+)"', line)
        if match:
            for name in pending: result[name] = match[1]
            pending = []
    return result


def decode_png(data):
    """Strict source format: non-interlaced 2-bit grayscale, with PNG CRCs."""
    if data[:8] != b'\x89PNG\r\n\x1a\n': raise MapError('not a PNG')
    position, compressed, header, ended = 8, b'', None, False
    while position < len(data):
        if position + 12 > len(data): raise MapError('truncated PNG chunk')
        size = struct.unpack('>I', data[position:position+4])[0]
        kind = data[position+4:position+8]
        content = data[position+8:position+8+size]
        if position + size + 12 > len(data): raise MapError('truncated PNG data')
        crc = struct.unpack('>I', data[position+8+size:position+12+size])[0]
        if zlib.crc32(kind + content) != crc: raise MapError('PNG CRC mismatch')
        if kind == b'IHDR':
            if header is not None or size != 13: raise MapError('invalid PNG header')
            header = struct.unpack('>IIBBBBB', content)
        elif kind == b'IDAT': compressed += content
        elif kind == b'IEND':
            ended = True
            if size or position + 12 != len(data): raise MapError('invalid PNG end')
        elif kind == b'tRNS': raise MapError('terrain PNG must have no alpha')
        elif kind[0] & 32 == 0 and kind != b'PLTE': raise MapError('unsupported critical PNG chunk')
        position += size + 12
    if not ended or header is None: raise MapError('incomplete PNG')
    width, height, depth, color, compression, filtering, interlace = header
    if (depth, color, compression, filtering, interlace) != (2, 0, 0, 0, 0):
        raise MapError('source must be non-interlaced 2-bit grayscale without alpha')
    if not width or not height or width % 8 or height % 8 or width * height > 1048576:
        raise MapError('invalid source tilesheet dimensions')
    stride = (width * 2 + 7) // 8
    try: raw = zlib.decompress(compressed)
    except zlib.error as error: raise MapError('invalid PNG compression') from error
    if len(raw) != height * (stride + 1): raise MapError('PNG raster size mismatch')
    rows, previous = [], [0] * stride
    for y in range(height):
        start = y * (stride + 1)
        mode, row = raw[start], list(raw[start+1:start+stride+1])
        if mode > 4: raise MapError('invalid PNG filter')
        for x in range(stride):
            a, b, c = (row[x-1] if x else 0), previous[x], (previous[x-1] if x else 0)
            if mode == 0: predictor = 0
            elif mode == 1: predictor = a
            elif mode == 2: predictor = b
            elif mode == 3: predictor = (a + b) // 2
            else:
                p = a + b - c
                pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
            row[x] = (row[x] + predictor) & 255
        # PNG grayscale increases black->white; canonical GB shades reverse it.
        rows.append([3 - ((row[x//4] >> (6-2*(x % 4))) & 3) for x in range(width)])
        previous = row
    return rows


def tile_grids(raster):
    height, width = len(raster), len(raster[0])
    return [[raster[ty+y][tx:tx+8] for y in range(8)]
            for ty in range(0, height, 8) for tx in range(0, width, 8)]


def quadrant_ids(blockset, block_id, quadrant):
    if not 0 <= quadrant <= 3: raise MapError('invalid block quadrant')
    if block_id < 0 or block_id * 16 + 16 > len(blockset): raise MapError('block reference outside blockset')
    qx, qy = quadrant % 2, quadrant // 2
    return [blockset[block_id*16 + (2*qy+r)*4 + 2*qx+c] for r in range(2) for c in range(2)]


def compose_grid(tiles, ids):
    if len(ids) != 4: raise MapError('cell requires four 8px tile references')
    if any(index < 0 or index >= len(tiles) for index in ids): raise MapError('8px tile reference outside PNG sheet')
    rows = []
    for y in range(16):
        rows.append(''.join(CODES[tiles[ids[(y//8)*2+x//8]][y % 8][x % 8]] for x in range(16)))
    return rows


def collision_tiles(text, name):
    labels, answer = [], None
    for line in text.splitlines():
        match = re.match(r'(\w+)_Coll::', line)
        if match: labels.append(match[1])
        found = records(line, 'coll_tiles')
        if found:
            if name in labels: answer = [integer(value) for value in found[0]['args']]
            labels = []
    if answer is None: raise MapError('collision list missing for tileset ' + name)
    return answer


def warp_tiles(text, tileset_index):
    pointers = re.findall(r'^\s*dw (\.\w+)', text, re.M)
    if not 0 <= tileset_index < len(pointers): raise MapError('warp tile pointer missing')
    target = pointers[tileset_index]
    match = re.search(r'^' + re.escape(target) + r':\s*$', text, re.M)
    if not match: raise MapError('warp tile label missing')
    values = []
    for line in text[match.end():].splitlines():
        plain = line.split(';', 1)[0].strip()
        if plain.startswith('db '): values += [integer(value) for value in plain[3:].split(',')]
        found = records(line, 'warp_tiles')
        if found: return values + [integer(value) for value in found[0]['args']]
    raise MapError('unterminated warp tile list')


def object_events(reference, name, constant, width, height, constants):
    path = f'data/maps/objects/{name}.asm'
    text = reference.text(path)
    answer = {'warps': [], 'background_events': [], 'objects': []}
    for macro, collection in [('warp_event', 'warps'), ('bg_event', 'background_events'), ('object_event', 'objects')]:
        for ordinal, row in enumerate(records(text, macro), 1):
            args = row['args']
            expected = (4,) if macro == 'warp_event' else (3,) if macro == 'bg_event' else (6, 7, 8)
            if len(args) not in expected: raise MapError('invalid ' + macro)
            x, y = integer(args[0]), integer(args[1])
            if not (0 <= x < width and 0 <= y < height): raise MapError(f'{macro} outside map: {x},{y}')
            event = {'id': f'pokered:{constant}:{collection}:{ordinal}', 'source_index': ordinal,
                     'x': x, 'y': y, 'source_line': row['line']}
            if macro == 'warp_event':
                target, warp = args[2], integer(args[3])
                if warp < 1: raise MapError('warp destination index must be 1-based')
                if target == 'LAST_MAP':
                    event['destination'] = {'kind': 'last_outdoor_map', 'warp_index': warp, 'resolved': False}
                else:
                    if target not in constants: raise MapError('unknown warp destination ' + target)
                    event['destination'] = {'kind': 'map', 'map': target, 'map_id': constants[target]['id'], 'warp_index': warp, 'resolved': False}
            elif macro == 'bg_event': event['text_id'] = args[2]
            else:
                event.update(sprite=args[2], movement=args[3], range_or_facing=args[4], text_id=args[5],
                             kind='npc' if len(args)==6 else 'item' if len(args)==7 else 'trainer_or_static_pokemon',
                             extra=args[6:], runtime_sprite=None, runtime_status='requires explicit existing or pinned sprite mapping')
            answer[collection].append(event)
    return answer


def encounters(reference, map_id):
    text = reference.text('data/wild/grass_water.asm')
    pointers = re.findall(r'^\s*dw (\w+)', text, re.M)
    if map_id >= len(pointers): raise MapError('wild pointer missing')
    pointer = pointers[map_id]
    path = 'data/wild/maps/nothing.asm' if pointer == 'NothingWildMons' else 'data/wild/maps/' + pointer.removesuffix('WildMons') + '.asm'
    selected = blue_text(reference.text(path))
    weights = [integer(row['args'][0]) for row in records(reference.text('data/wild/probabilities.asm'), 'wild_chance')]
    if len(weights) != 10 or sum(weights) != 256: raise MapError('invalid wild slot weights')
    tables, mode = {}, None
    for line in selected.splitlines():
        for kind in ('grass', 'water'):
            found = records(line, f'def_{kind}_wildmons')
            if found:
                mode = kind
                rate = integer(found[0]['args'][0])
                if not 0 <= rate <= 255: raise MapError('invalid encounter rate byte')
                tables[kind] = {'rate_byte': rate, 'slots': []}
        if mode:
            found = records(line, 'db')
            if found and len(found[0]['args']) == 2:
                level, species = found[0]['args']
                level = integer(level)
                if not 1 <= level <= 100: raise MapError('invalid encounter level')
                tables[mode]['slots'].append({'level': level, 'species_source': species})
    for kind in ('grass', 'water'):
        if kind not in tables: raise MapError('missing encounter table section')
        table = tables[kind]
        if len(table['slots']) != (10 if table['rate_byte'] else 0): raise MapError('encounter table slot count mismatch')
        for index, slot in enumerate(table['slots']):
            slot.update(index=index, weight_256=weights[index])
    return {'version': 'English Blue', 'source_pointer': pointer, 'source': path,
            'rate_interpretation': 'original rate byte; not a percentage or current runtime rule', **tables}


def decode_map(reference, name, *, linked_layout_tail=None):
    constants = map_constants(reference)
    header_path = f'data/maps/headers/{name}.asm'
    header = reference.text(header_path)
    rows = records(header, 'map_header')
    if len(rows) != 1 or len(rows[0]['args']) != 3: raise MapError('one map header required')
    declared_name, constant, tileset_constant = rows[0]['args']
    if declared_name != name or constant not in constants: raise MapError('map header binding mismatch')
    dims = constants[constant]
    width, height = dims['width'] * 2, dims['height'] * 2
    if not width or not height: raise MapError('empty map dimensions')
    layout_path = bindings(reference.text('maps.asm'), 'Blocks').get(name)
    if not layout_path: raise MapError('map block layout binding missing')
    layout = reference.bytes(layout_path)
    layout_extent = None
    if linked_layout_tail is not None:
        # Opt-in bounded ROMX continuation, never implicit padding. Some source
        # layouts intentionally run into the immediately following INCBIN.
        tail_path, tail_size = linked_layout_tail
        declaration = (r'^' + re.escape(name) + r'_Blocks: INCBIN "' + re.escape(layout_path)
                       + r'"\n\w+_Blocks: INCBIN "' + re.escape(tail_path) + r'"$')
        if (type(tail_size) is not int or tail_size <= 0
                or len(layout) + tail_size != dims['width'] * dims['height']
                or not re.search(declaration, reference.text('maps.asm'), re.M)):
            raise MapError('unverified adjacent layout continuation')
        tail = reference.bytes(tail_path)
        if len(tail) < tail_size:
            raise MapError('short adjacent layout continuation')
        layout_extent = {'primary': layout_path, 'primary_size': len(layout),
                         'continuation': tail_path, 'offset': 0, 'size': tail_size,
                         'proof': 'consecutive INCBIN declarations in pinned maps.asm'}
        layout += tail[:tail_size]
    if len(layout) != dims['width'] * dims['height']:
        raise MapError(f'{name}: layout dimensions mismatch: {len(layout)} bytes vs {dims["width"]}x{dims["height"]}; no padding exception')
    tile_constants = re.findall(r'^\s*const (\w+)', reference.text('constants/tileset_constants.asm'), re.M)
    if tileset_constant not in tile_constants: raise MapError('unknown tileset constant')
    index = tile_constants.index(tileset_constant)
    tile_rows = records(reference.text('data/tilesets/tileset_headers.asm'), 'tileset')
    if index >= len(tile_rows) or len(tile_rows[index]['args']) != 6: raise MapError('invalid tileset header')
    tile_name, *settings = tile_rows[index]['args']
    graphics_text = reference.text('gfx/tilesets.asm')
    blockset_path = bindings(graphics_text, 'Block').get(tile_name)
    gfx_path = bindings(graphics_text, 'GFX').get(tile_name)
    if not blockset_path or not gfx_path or not gfx_path.endswith('.2bpp'): raise MapError('tileset source binding missing')
    png_path = gfx_path[:-5] + '.png'
    blockset = reference.bytes(blockset_path)
    if not blockset or len(blockset) % 16: raise MapError('blockset requires complete 4x4 tile definitions')
    tiles = tile_grids(decode_png(reference.bytes(png_path)))
    allowed = set(collision_tiles(reference.text('data/tilesets/collision_tile_ids.asm'), tile_name))
    counters = [integer(value) for value in settings[:3] if integer(value) >= 0]
    grass = integer(settings[3])
    warping = warp_tiles(reference.text('data/tilesets/warp_tile_ids.asm'), index)
    water_sets = {row['args'][0] for row in records(reference.text('data/tilesets/water_tilesets.asm'), 'db') if len(row['args'])==1}
    combinations, source_refs = set(), []
    for y in range(height):
        row = []
        for x in range(width):
            offset = (y//2) * dims['width'] + x//2
            block, quadrant = layout[offset], (y % 2)*2 + x % 2
            ids = tuple(quadrant_ids(blockset, block, quadrant))
            combinations.add(ids)
            row.append([offset, block, quadrant])
        source_refs.append(row)
    dictionary, lookup = [], {}
    for ordinal, ids in enumerate(sorted(combinations), 1):
        grid = compose_grid(tiles, ids)
        foot = ids[2]
        entry = {'id': ordinal, 'stable_id': f'pokered:{tileset_constant}:cell:' + '-'.join(f'{value:02x}' for value in ids),
                 'source_tile_ids': list(ids), 'grid': grid, 'canonical_shade_sha256': sha(bytes(CODES.index(c) for row in grid for c in row)),
                 'opaque': True, 'terrain': {'foot_tile': foot, 'land_passable': foot in allowed,
                 'grass': grass >= 0 and foot == grass, 'counter': foot in counters,
                 'water_candidate': tileset_constant in water_sets and foot == 0x14, 'warp_tile': foot in warping}}
        lookup[ids] = ordinal
        dictionary.append(entry)
    tile_ids, collision = [], []
    for row in source_refs:
        ids_row, collision_row = [], []
        for offset, block, quadrant in row:
            ids = tuple(quadrant_ids(blockset, block, quadrant));local_id = lookup[ids]
            ids_row.append(local_id);collision_row.append(0 if ids[2] in allowed else 1)
        tile_ids.append(ids_row);collision.append(collision_row)
    events = object_events(reference, name, constant, width, height, constants)
    connections = []
    for row in records(header, 'connection'):
        if len(row['args']) != 4: raise MapError('invalid connection')
        direction, target_name, target_constant, offset = row['args'];offset=integer(offset)
        if direction not in ('north','south','east','west') or target_constant not in constants: raise MapError('invalid connection target/direction')
        connections.append({'direction':direction,'target_header':target_name,'target_map':target_constant,
                            'offset_blocks':offset,'entry_lateral_adjustment_cells':-2*offset,
                            'interpretation':'source macro entry adjustment; runtime traversal unresolved'})
    script_path = f'scripts/{name}.asm'
    script = reference.text(script_path)
    ledges = []
    if tileset_constant == 'OVERWORLD':
        for row in records(reference.text('data/tilesets/ledge_tiles.asm'), 'db'):
            if len(row['args']) == 4:
                direction, standing, target, button = row['args']
                ledges.append({'facing':direction,'standing_foot_tile':integer(standing),'target_foot_tile':integer(target),'input':button})
    pairs = []
    for row in records(reference.text('data/tilesets/pair_collision_tile_ids.asm'), 'db'):
        if len(row['args']) == 3 and row['args'][0] == tileset_constant:
            pairs.append([integer(value) for value in row['args'][1:]])
    result = {'schema':SCHEMA,'source_revision':REVISION,'version':'English Blue','id':f'pokered:{constant}',
            'name':name,'source_map_id':dims['id'],'source_map_constant':constant,
            'dimensions':{'blocks':[dims['width'],dims['height']],'cells':[width,height],'original_pixels':[width*16,height*16],'playdate_pixels':[width*32,height*32]},
            'tileset':{'constant':tileset_constant,'index':index,'name':tile_name,'graphics':png_path,'blockset':blockset_path,
                       'counter_tiles':counters,'grass_tile':grass,'animation':settings[4],'preview_phase':'source PNG static phase'},
            'grids':dictionary,'tile_ids':tile_ids,'collision':collision,'source_refs':source_refs,
            'source_refs_fields':['layout_byte_offset','block_id','quadrant_0_TL_1_TR_2_BL_3_BR'],
            'events':events,'connections':connections,'encounters':encounters(reference,dims['id']),
            'directional_rules':{'ledges':ledges,'forbidden_tile_pairs':pairs,'status':'data only; not executed by binary collision grid'},
            'script':{'source':script_path,'sha256':sha(script.encode()),'events_referenced':sorted(set(re.findall(r'\bEVENT_[A-Z0-9_]+',script))),
                      'states_referenced':sorted(set(re.findall(r'\bSCRIPT_[A-Z0-9_]+',script))),
                      'status':'unimplemented source script; no parcel/shop/NPC movement behavior claimed'},
            'runtime_adapter':{'integrated':False,'padding_cells':[0,0],'npc_images_rendered':False,'terrain_alpha':False}}
    if layout_extent is not None:
        result['layout_extent'] = layout_extent
    return result


def validate_grid(grid):
    if len(grid) != 16 or any(len(row) != 16 or any(c not in CODES for c in row) for row in grid):
        raise MapError('canonical cell grid must be 16x16 using .12#')


def render_map(definition, native=True):
    width, height = definition['dimensions']['cells'];scale = 2 if native else 1
    grids = {entry['id']:entry['grid'] for entry in definition['grids']}
    for grid in grids.values(): validate_grid(grid)
    image = []
    for y in range(height*16*scale):
        row=[]
        for x in range(width*16*scale):
            local = definition['tile_ids'][y//(16*scale)][x//(16*scale)]
            shade = grids[local][(y//scale)%16][(x//scale)%16]
            if not native: value = 3-CODES.index(shade)
            elif shade == '.': value=1
            elif shade == '#': value=0
            else: value = 1 if (LIGHT if shade=='1' else DARK)[y%8] & (0x80>>(x%8)) else 0
            row.append(value)
        image.append(row)
    return encode_png(image, 1 if native else 2)


def encode_png(rows, depth):
    """Opaque grayscale PNG, deterministic stored-deflate (no encoder metadata)."""
    if depth not in (1,2): raise MapError('PNG preview depth must be 1 or 2')
    height,width=len(rows),len(rows[0]);raw=bytearray()
    for row in rows:
        if len(row)!=width: raise MapError('ragged preview raster')
        raw.append(0)
        stride=bytearray((width*depth+7)//8)
        for x,value in enumerate(row):
            if not 0 <= value < 1<<depth: raise MapError('preview sample outside bit depth')
            stride[x*depth//8] |= value << (8-depth-(x*depth)%8)
        raw.extend(stride)
    compressed=bytearray(b'\x78\x01')
    for offset in range(0,len(raw),65535):
        block=raw[offset:offset+65535];compressed.append(1 if offset+len(block)==len(raw) else 0)
        compressed.extend(struct.pack('<HH',len(block),len(block)^0xffff));compressed.extend(block)
    compressed.extend(struct.pack('>I',zlib.adler32(raw)))
    def chunk(kind,content):return struct.pack('>I',len(content))+kind+content+struct.pack('>I',zlib.crc32(kind+content))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,depth,0,0,0,0))+chunk(b'IDAT',compressed)+chunk(b'IEND',b'')


def artifacts(reference, names):
    if len(names)!=len(set(names)) or not names: raise MapError('map selection must be nonempty and unique')
    result={};summaries=[]
    for name in names:
        if name not in (*PILOT_MAPS,'UndergroundPathNorthSouth'): raise MapError('pilot map selection unsupported: '+name)
        definition=decode_map(reference,name)
        if name not in PILOT_MAPS: raise MapError('map outside pilot scope')
        result[name+'.json']=json_bytes(definition)
        result[name+'-native.png']=render_map(definition,True)
        result[name+'-reference.png']=render_map(definition,False)
        summaries.append({'name':name,'dimensions':definition['dimensions'],'grid_count':len(definition['grids']),
                          'events':{key:len(value) for key,value in definition['events'].items()}})
    manifest={'schema':SCHEMA,'generator':'kanto-map-pilot-v1','generator_sha256':sha(Path(__file__).read_bytes()),'source_revision':REVISION,
              'version':'English Blue','status':'staged terrain/data pilot; no runtime/gameplay acceptance',
              'render_contract':{'cell_source_pixels':16,'cell_native_pixels':32,'alpha':False,'light':list(LIGHT),'dark':list(DARK),'pattern_phase':[0,0]},
              'source_files':[{'path':path,'sha256':digest} for path,digest in sorted(reference.consumed.items())],
              'maps':summaries,'artifacts':[{'path':name,'sha256':sha(data),'bytes':len(data)} for name,data in sorted(result.items())]}
    result['manifest.json']=json_bytes(manifest)
    return result


def publish(artifacts_by_name, output, check=False):
    output=Path(output).expanduser().resolve()
    if output.parent!=Path('/private/tmp') or not output.name.startswith('pokemon-map-pilot'):
        raise MapError('output must be /private/tmp/pokemon-map-pilot or a sibling with that prefix')
    if check:
        if not output.is_dir(): raise MapError('check output directory missing')
        actual={path.name for path in output.iterdir()}
        if any(path.is_symlink() for path in output.iterdir()): raise MapError('generated artifact must not be a symlink')
        if actual!=set(artifacts_by_name): raise MapError('generated artifact inventory mismatch')
        for name,data in artifacts_by_name.items():
            if (output/name).read_bytes()!=data: raise MapError('generated artifact differs: '+name)
    else:
        output.mkdir(parents=True,exist_ok=False)
        for name,data in artifacts_by_name.items():(output/name).write_bytes(data)
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',required=True,help='explicit checkout/extracted tree at pinned revision; no download')
    parser.add_argument('--output',required=True)
    parser.add_argument('--maps',nargs='+',default=list(PILOT_MAPS))
    parser.add_argument('--check',action='store_true',help='regenerate and compare every artifact without writing')
    args=parser.parse_args()
    try:
        generated=artifacts(Reference(args.reference),args.maps)
        destination=publish(generated,args.output,args.check)
        print(json.dumps({'ok':True,'check_only':args.check,'output':str(destination),'maps':args.maps,'artifacts':len(generated)}))
        return 0
    except (MapError,OSError,ValueError,KeyError,IndexError) as error:
        print(str(error),file=sys.stderr);return 1


if __name__=='__main__':raise SystemExit(main())
