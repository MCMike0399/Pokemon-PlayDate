#!/usr/bin/env python3
"""Generate the inactive Cut/Flash extension from checksum-verified primary inputs.

Host work only: never runs Lua, a ROM, the SDK, or a Simulator.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.generate_kanto_maps import (Reference, REVISION, bindings, records, integer,
                                      quadrant_ids, decode_png, tile_grids, compose_grid,
                                      collision_tiles, map_constants)

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / 'tools/references/field-moves'


def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def build(inputs=INPUT):
    pins = json.loads((inputs / 'pins.json').read_bytes())
    assert pins['schema'] == 1 and pins['source_revision'] == REVISION
    reference = Reference(inputs / 'pokered', pins['pokered'])
    # Verify all provenance, including lifetime/fade sources that aren't parsed.
    for path in pins['pokered']:
        reference.bytes(path)
    ps = {}
    oracle = json.loads((ROOT / 'tools/references/move-support.json').read_bytes())['oracle']
    assert pins['showdown']['revision'] == oracle['revision']
    for path, digest in pins['showdown']['files'].items():
        raw = (inputs / 'showdown' / path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == digest == oracle['source_sha256'][path], path
        ps[path] = raw.decode()
    def move(text, name):
        match = re.search(r'^\t' + name + r': \{\n(.*?)^\t\},', text, re.M | re.S)
        return match.group(1) if match else ''
    for key in ('cut', 'flash'):
        body = move(ps['data/moves.ts'], key)
        assert body
        for generation in (8, 7, 6, 5):
            mod = move(ps[f'data/mods/gen{generation}/moves.ts'], key)
            assert not mod or re.fullmatch(r'\s*inherit: true,\s*isNonstandard: null,\s*', mod), 'review changed oracle override'
    cut, flash = (move(ps['data/moves.ts'], key) for key in ('cut', 'flash'))
    assert 'accuracy: 95,' in cut and 'basePower: 50,' in cut and 'pp: 30,' in cut
    assert 'accuracy: 100,' in flash and 'accuracy: -1,' in flash and 'pp: 20,' in flash
    swaps = [tuple(integer(v) for v in row['args']) for row in
             records(reference.text('data/tilesets/cut_tree_blocks.asm'), 'db') if len(row['args']) == 2]
    constants = map_constants(reference)
    layouts = bindings(reference.text('maps.asm'), 'Blocks')
    result = {'schema': 1, 'source_revision': REVISION, 'maps': {}, 'tiles': {},
              'tree_frames': 8, 'flash_white_frames': 3, 'dark_maps': ['pokered:ROCK_TUNNEL_1F', 'pokered:ROCK_TUNNEL_B1F']}
    for name in pins['maps']:
        header = records(reference.text(f'data/maps/headers/{name}.asm'), 'map_header')[0]['args']
        _, constant, tileset = header
        assert tileset in ('OVERWORLD', 'GYM')
        size = constants[constant]
        width, height = size['width'] * 2, size['height'] * 2
        layout = reference.bytes(layouts[name])
        assert len(layout) == size['width'] * size['height']
        stem, title, foot = ('overworld', 'Overworld', 0x3d) if tileset == 'OVERWORLD' else ('gym', 'Gym', 0x50)
        blocks = reference.bytes(f'gfx/blocksets/{stem}.bst')
        raster = tile_grids(decode_png(reference.bytes(f'gfx/tilesets/{stem}.png')))
        allowed = collision_tiles(reference.text('data/tilesets/collision_tile_ids.asm'), title)
        def cell(block, quadrant):
            ids = quadrant_ids(blocks, block, quadrant)
            key = f'pokered:{tileset}:cell:' + '-'.join(f'{i:02x}' for i in ids)
            terrain = dict(foot_tile=ids[2], land_passable=ids[2] in allowed,
                           grass=tileset == 'OVERWORLD' and ids[2] == 0x52,
                           counter=False, warp_tile=ids[2] in ([0x1b, 0x58] if tileset == 'OVERWORLD' else [0x4a]),
                           water_candidate=tileset == 'OVERWORLD' and ids[2] == 0x14)
            return dict(key=key, grid=compose_grid(raster, ids), collision=int(not terrain['land_passable']), terrain=terrain)
        sites = []
        for offset, block in enumerate(layout):
            targets = [q for q in range(4) if quadrant_ids(blocks, block, q)[2] == foot]
            if not targets:
                continue
            after = next((b for a, b in swaps if a == block), None)
            assert after is not None, (name, block)
            x, y = offset % size['width'] * 2, offset // size['width'] * 2
            cells = []
            for q in range(4):
                before, replacement = cell(block, q), cell(after, q)
                for entry in (before, replacement):
                    old = result['tiles'].get(entry['key'])
                    assert old is None or old == entry
                    result['tiles'][entry['key']] = entry
                cells.append(dict(x=x + q % 2, y=y + q // 2, before=before['key'], after=replacement['key']))
            sites.append(dict(block=block, replacement=after, x=x, y=y, cells=cells,
                              targets=[dict(x=x+q % 2, y=y+q//2) for q in targets]))
        result['maps']['pokered:' + constant] = dict(name=name, width=width, height=height, tileset=tileset,
                                                     layout_sha256=hashlib.sha256(layout).hexdigest(), sites=sites)
    # OAM uses OVERWORLD art even for the GYM tree. Palette index zero is transparent.
    raster = tile_grids(decode_png(reference.bytes('gfx/tilesets/overworld.png')))
    result['tree_grid'] = compose_grid(raster, [0x2d, 0x2e, 0x3d, 0x3e])
    battle = '''-- Generated by tools/generate_field_moves.py from pinned Showdown gen5 chain.
-- Root imports this extension after battle/moves. No core battle edits.
assert(moveData.cut == nil and moveData.flash == nil, "HM move registration already owned")
moveData.cut = Move{ name="CUT", type="normal", category="physical", power=50,
    accuracy=95, pp=30, targetId=10, contact=true, protectable=true }
moveData.flash = Move{ name="FLASH", type="normal", category="status", power=0,
    accuracy=100, pp=20, targetId=10, contact=false, protectable=true,
    effects={ ModifyStat(DEFENDER, "acc", -1) } }
-- Intentionally leave MoveSupport untouched. Its existing unknown-dispatch guard
-- says "But it failed!" and records a gap until the battle owner reviews support.
'''
    return {'fieldMoves.json': canonical(result), 'fieldMoveBattleData.lua': battle.encode()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'Source/data')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build()
    for name, raw in artifacts.items():
        path = args.output / name
        if args.check:
            assert path.read_bytes() == raw, 'generated field data drift: ' + name
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print('Verified pinned field move inputs and ' + str(len(artifacts)) + ' artifacts.')


if __name__ == '__main__':
    main()
