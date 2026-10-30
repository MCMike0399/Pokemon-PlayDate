#!/usr/bin/env python3
"""Project pinned Blue bicycle/fishing pixels and source OAM/timing, never RED grids."""
import argparse
import hashlib
import io
import json
import re
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import Reference, REVISION, integer
from tools.generate_viridian_slice import sprite_data
from tools.generate_overworld_sprites import mask_bytes

PIN = ROOT / 'tools/references/field-gear-art.json'
OUTPUT = ROOT / 'Source/data/fieldGearArt.json'
SHADES = {255: '.', 170: '1', 85: '2', 0: '#'}


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False) + '\n').encode()


def png(ref, path, size):
    raw = ref.bytes(path)
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        if image.mode != 'L' or image.size != size or not set(image.getdata()) <= set(SHADES):
            raise ValueError('source image format/palette/size differs: ' + path)
        return [''.join(SHADES[image.getpixel((x, y))] for x in range(size[0])) for y in range(size[1])]


def build(reference):
    pin = json.loads(PIN.read_bytes())
    if pin['schema'] != 1 or pin['revision'] != REVISION:
        raise ValueError('unverified field gear art pin')
    ref = Reference(reference, pin['files'])
    # Verify all source inputs, including the exact opcode/macro/OAM contracts.
    for name in pin['files']:
        ref.bytes(name)
    bike = sprite_data(ref, 'red_bike')
    red = sprite_data(ref, 'red')  # Immutable source read; never writes protected RED.
    facings = ref.text('data/sprites/facings.asm')
    for direction, stand, walk in [('Down', 0, 0x80), ('Up', 4, 0x84), ('Left', 8, 0x88)]:
        for label, base in [('Standing', stand), ('Walking', walk)]:
            expected = ', '.join('$' + format(base + i, '02x') for i in range(4))
            if not re.search(r'\.' + label + direction + r':\s+db\s+' + re.escape(expected), facings):
                raise ValueError('source facing frame layout drift')
    source = ref.text('engine/overworld/player_animations.asm')
    body = source.split('FishingAnim:', 1)[1].split('_HandleMidJump::', 1)[0]
    delays = [int(v) for v in re.findall(r'ld c, (\d+)\n\tcall DelayFrames', body)]
    if delays != [10, 100] or 'ld b, 10\n.loop' not in body or 'call Delay3' not in body or 'xor $1' not in body:
        raise ValueError('source FishingAnim timing/shake drift')
    if not re.search(r'Delay3::.*?ld c, 3\n\tjp DelayFrames', ref.text('home/palettes.asm'), re.S):
        raise ValueError('source three-frame shake delay drift')
    emote = ref.text('engine/overworld/emotion_bubbles.asm')
    if 'ld c, 60\n\tcall DelayFrames' not in emote or 'call DelayFrame\n\tjp UpdateSprites' not in emote:
        raise ValueError('source EmotionBubble timing drift')
    if 'cp SPRITE_FACING_UP' not in body or 'ld a, $44' not in body:
        raise ValueError('source up-facing rod visibility drift')
    gfx = ref.text('gfx/fishing.asm')
    lower = {}
    fishing = {}
    for direction, suffix, label, index, tile in [('down', 'front', 'Front', 0, 2),
                                                ('up', 'back', 'Back', 1, 6),
                                                ('left', 'side', 'Side', 2, 10)]:
        path = f'gfx/overworld/red_fish_{suffix}.png'
        if f'RedFishingTiles{label}:'.replace(':', '') not in gfx or path.replace('.png', '.2bpp') not in gfx:
            raise ValueError('source fishing graphic binding drift')
        if not re.search(r'fishing_gfx RedFishingTiles' + label + r',\s*2, \$' + format(tile, '02x'), body):
            raise ValueError('source lower two-tile replacement drift')
        rows = png(ref, path, (16, 8))
        lower[direction] = dict(source=path, sha256=pin['files'][path], grid=rows, vram_first_tile=tile)
        fishing[direction] = red['frames'][str(index)][:8] + rows
    rod_rows = png(ref, 'gfx/overworld/fishing_rod.png', (8, 24))
    rod_tiles = {}
    for index in range(3):
        rows = rod_rows[index * 8:(index + 1) * 8]
        rod_tiles[format(0xfd + index, '02x')] = dict(grid=rows,
            mask=[''.join('0' if c == '.' else '1' for c in row) for row in rows])
    oam = re.findall(r'^\s*dbsprite\s+(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\$\w+),\s*(\w+)',
                     body.split('FishingRodOAM:', 1)[1].split('MACRO fishing_gfx', 1)[0], re.M)
    if len(oam) != 4:
        raise ValueError('four source rod direction records required')
    if 'db (\\2 * TILE_WIDTH) % $100 + \\4, (\\1 * TILE_WIDTH) % $100 + \\3, \\5, \\6' not in ref.text('macros/gfx.asm'):
        raise ValueError('source dbsprite coordinate macro drift')
    # IsSpriteInFrontOfPlayer's canonical standing screen position: Y60/X64.
    if 'lb bc, $3c, $40 ; Y and X position of player sprite' not in ref.text('home/overworld.asm'):
        raise ValueError('source standing player screen origin drift')
    origin_x, origin_y = 64, 60
    rods = {}
    for direction, values in zip(('down', 'up', 'left', 'right'), oam):
        tx, ty, px, py = map(int, values[:4])
        tile, attributes = values[4:]
        if attributes not in ('0', 'OAM_XFLIP'):
            raise ValueError('unsupported source rod OAM transform')
        hardware_x, hardware_y = tx * 8 + px, ty * 8 + py
        rods[direction] = dict(tile=format(integer(tile), '02x'), flip_x=attributes == 'OAM_XFLIP',
            hardware_x=hardware_x, hardware_y=hardware_y,
            source_offset=[hardware_x - 8 - origin_x, hardware_y - 16 - origin_y],
            native_offset=[2 * (hardware_x - 8 - origin_x), 2 * (hardware_y - 16 - origin_y)])
    shock = png(ref, 'gfx/emotes/shock.png', (16, 16))
    existing_path = ROOT / 'Source/data/pewterSlice/emote.json'
    existing = json.loads(existing_path.read_bytes())
    if existing['grid'] != shock or existing['source_sha256'] != pin['files']['gfx/emotes/shock.png']:
        raise ValueError('existing pinned exclamation differs; never regenerate it here')
    # Host checks use the established border flood-fill witness, not new masks.
    masks = {f'bicycle:{i}': hashlib.sha256(mask_bytes(grid)).hexdigest() for i, grid in bike['frames'].items()}
    masks.update({f'fishing:{d}': hashlib.sha256(mask_bytes(grid)).hexdigest() for d, grid in fishing.items()})
    data = dict(schema=1, source_revision=REVISION,
        source_files=ref.consumed, pattern_phase=[0, 0],
        rendering='legacy character LIGHT12.5%/DARK50%; faithful source .12#; explicit zero phase; no imported-terrain renderer',
        bicycle=bike, fishing=dict(frames=fishing, lower_tiles=lower,
            construction='source RED standing top8 rows + source fishing lower8 rows; right mirrors left'),
        rod=dict(source='gfx/overworld/fishing_rod.png', tiles=rod_tiles, directions=rods,
            unused_by_oam=['ff'], mask_policy='original OBJ index0 transparent everywhere'),
        exclamation=dict(reuse='PewterSprites.exclamation', data='data/pewterSlice/emote.json',
            data_sha256=hashlib.sha256(existing_path.read_bytes()).hexdigest(), native_offset=[0, -32]),
        timing=dict(source_hz=60, native_hz=30, sampling='native tick n samples source frame 2*n+1; zero-based',
            precast_frames=delays[0], cast_frames=delays[1], shake_count=10, shake_hold_frames=3,
            shake_xor=1, shake_source_offsets=[1 if i % 2 == 0 else 0 for i in range(10)],
            bubble_frames=60, bubble_refresh_frames=1, up_rod_hidden_during_bubble=True,
            response_labels={'0': '_NoNibbleText', '1': '_ItsABiteText', '2': '_NothingHereText'},
            text_wait='source PrintText is input-driven; controller owns acknowledgement and restoration'),
        character_mask_sha256=masks,
        generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        status='source pixels/timing candidate; root native visual review pending')
    return canonical(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build(args.reference)
    target = args.output or OUTPUT
    if args.check:
        if target.read_bytes() != data:
            raise ValueError('field gear art output drift')
    else:
        if args.output is None:
            parser.error('explicit fresh --output required')
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as output:
            output.write(data)
    print('Verified six bicycle frames, three constructed fishing poses, three source rod tiles and existing exclamation')

if __name__ == '__main__':
    main()
