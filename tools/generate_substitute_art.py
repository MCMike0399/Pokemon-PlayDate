#!/usr/bin/env python3
"""Reproduce Red/Blue's Substitute pictures from immutable MonsterSprite tiles.

Reads local pinned inputs only. Writes only the two declared new assets, never
an existing Pokemon sprite, grid, protected pin or catalog baseline.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re

from PIL import Image
from tools.generate_battle_art import References, threshold

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tools/references/substitute-art.json'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
DEFAULT_REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', str(Path.home() / 'Developer/Pokemon-PlayDate-env/pokered')))
OUTPUT = ROOT / 'Source/images/battle-effects'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def load_inputs(reference, manifest):
    if manifest['revision'] != REVISION or manifest['schema'] != 1:
        raise ValueError('unknown Substitute art source contract')
    reader = References(manifest, root=reference)
    data = {}
    for name, checksum in manifest['inputs'].items():
        raw = reader.read(name)
        if sha(raw) != checksum:
            raise ValueError('pinned Substitute input checksum: ' + name)
        data[name] = raw
    return data


def placements(data):
    asm = data['engine/battle/animations.asm'].decode()
    body = asm.split('\nAnimationSubstitute:\n', 1)[1].split('\nCopyMonsterSpriteData:', 1)[0]
    pairs = [(int(tile), int(x), int(y)) for tile, x, y in re.findall(
        r'ld hl, MonsterSprite tile (\d+)[^\n]*\n\tld de, wTempPic \+ tile \(PIC_HEIGHT \* (\d+) \+ (\d+)\)', body)]
    expected = [(0,2,4), (1,3,4), (2,2,5), (3,3,5), (4,3,4), (5,4,4), (6,3,5), (7,4,5)]
    if pairs != expected:
        raise ValueError('Substitute tile index/order/placement changed')
    assert 'ld bc, PIC_SIZE tiles\n\tcall FillMemory' in body
    assert 'ld a, BANK(MonsterSprite)\n\tjp FarCopyData2' in asm
    assert 'ld de, wTempPic\n\tld bc, PIC_SIZE\n\tjp CopyVideoData' in asm
    assert 'MonsterSprite::          INCBIN "gfx/sprites/monster.2bpp"' in data['gfx/sprites.asm'].decode()
    assert 'DEF PIC_WIDTH  EQU 7' in data['constants/gfx_constants.asm'].decode()
    assert 'DEF PIC_HEIGHT EQU PIC_WIDTH' in data['constants/gfx_constants.asm'].decode()
    tilemaps = data['data/tilemaps.asm'].decode()
    assert 'tile_ids MonTiles,               7,  7' in tilemaps
    assert 'MonTiles:\n\tINCBIN "gfx/pokemon/front.tilemap"' in tilemaps
    tilemap = data['gfx/pokemon/front.tilemap']
    if list(tilemap) != [x * 7 + y for y in range(7) for x in range(7)]:
        raise ValueError('Substitute display tile order changed')
    make = data['Makefile'].decode()
    assert '$(RGBGFX) --colors dmg $(RGBGFXFLAGS) -o $@ $<' in make
    assert 'RGBGFXFLAGS  ?= -Weverything' in make
    assert 'gfx/sprites/monster.2bpp:' not in make
    return pairs, tilemap


def encode_dmg_tiles(strip):
    """Independent row-major DMG 2bpp packing for the provenance receipt."""
    raw = bytearray()
    colors = {255:0, 170:1, 85:2, 0:3}
    for ty in range(0, strip.height, 8):
        for tx in range(0, strip.width, 8):
            for y in range(8):
                low = high = 0
                for x in range(8):
                    color = colors[strip.getpixel((tx+x, ty+y))]
                    low |= (color & 1) << (7-x)
                    high |= (color >> 1) << (7-x)
                raw.extend((low, high))
    return bytes(raw)


def build(reference=DEFAULT_REFERENCE, manifest=None):
    manifest = manifest or json.loads(MANIFEST.read_text())
    data = load_inputs(reference, manifest)
    pairs, tilemap = placements(data)
    strip = Image.open(io.BytesIO(data['gfx/sprites/monster.png']))
    if strip.mode != 'L' or strip.size != (16, 96) or set(strip.getdata()) != {0,85,170,255}:
        raise ValueError('unexpected MonsterSprite dimensions/palette')
    artifacts = {}
    receipt = {'revision': REVISION, 'inputs': manifest['inputs'],
               'derived_dmg_2bpp_sha256': sha(encode_dmg_tiles(strip)), 'views': {}}
    for view, selected in [('front', pairs[:4]), ('back', pairs[4:])]:
        canvas = Image.new('L', (56,56), 255)
        for index, x, y in selected:
            crop = ((index % 2)*8, (index // 2)*8, (index % 2)*8+8, (index // 2)*8+8)
            display_index = tilemap.index(x*7+y)
            canvas.paste(strip.crop(crop), ((display_index % 7)*8, (display_index // 7)*8))
        image = threshold(canvas)  # Existing battle art's pinned >=128 mapping.
        output = io.BytesIO()
        image.save(output, format='PNG', compress_level=9)
        name = 'substitute-' + view + '.png'
        artifacts[name] = output.getvalue()
        receipt['views'][view] = {'tiles': [list(p) for p in selected], 'size': [56,56],
            'source_canvas_l8_sha256': sha(canvas.tobytes()), 'pixels_1bpp_sha256': sha(image.tobytes()),
            'png_sha256': sha(artifacts[name])}
    return artifacts, receipt


def check(artifacts, output=OUTPUT):
    for name, raw in artifacts.items():
        if (output / name).read_bytes() != raw:
            raise ValueError('Substitute asset drift: ' + name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-root', type=Path, default=DEFAULT_REFERENCE)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if args.check == args.write:
        parser.error('choose exactly one of --check or --write')
    artifacts, receipt = build(args.reference_root)
    manifest = json.loads(MANIFEST.read_text())
    if receipt != manifest['reproduction']:
        raise ValueError('Substitute reproduction differs from pinned recipe')
    if args.check:
        check(artifacts, args.output_dir)
    else:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (args.output_dir / name).write_bytes(raw)
    if args.report:
        args.report.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt, indent=2))
