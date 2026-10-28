#!/usr/bin/env python3
"""Pinned Blue ship pixels and presentation constants; no active map writes."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.generate_kanto_maps import decode_png, tile_grids, quadrant_ids, compose_grid
from tools.generate_vermilion_story import global_block

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/vermilion-ship'
OUTPUT = ROOT / 'Source/data/vermilionShip'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode()


def verified(reference=REFERENCE):
    pin = json.loads((REFERENCE / 'manifest.json').read_bytes())
    if pin['revision'] != REVISION:
        raise ValueError('ship source revision differs')
    result = {}
    for path, digest in pin['files'].items():
        raw = (Path(reference) / path).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('unverified pinned ship source: ' + path)
        result[path] = raw
    return result


def build(reference=REFERENCE):
    source = verified(reference)
    script = source['scripts/VermilionDock.asm'].decode()
    departure = global_block(script, 'VermilionDockSSAnneLeavesScript')
    erase = global_block(script, 'VermilionDock_EraseSSAnne')
    smoke = global_block(script, 'VermilionDock_EmitSmokePuff')
    drift = global_block(script, 'VermilionDock_AnimSmokePuffDriftRight')
    sync = global_block(script, 'VermilionDock_SyncScrollWithLY')
    dust = source['engine/overworld/dust_smoke.asm'].decode()
    oam = source['home/oam.asm'].decode()
    # Read literals only within their exact global-label owners. These checks
    # document fixed dispatch/OAM semantics; no ASM is emulated by the host.
    initial_wait = int(re.search(r'ld c, (\d+)\n\tcall DelayFrames', departure)[1])
    final_wait = int(re.search(r'ld c, (\d+)\n\tcall DelayFrames', erase)[1])
    chunks = int(re.search(r'ld e, \$(\w+)\n\.shift_columns_up', departure)[1], 16)
    steps = int(re.search(r'ld b, \$(\w+)\n\.smoke_puff_drift_loop', departure)[1], 16)
    frames_per_pixel = int(re.search(r'ld c, \$(\w+)\n\.delay_between_drifts', departure)[1], 16)
    band_top, band_bottom = [int(n, 16) for n in re.findall(r'ld l, \$(\w+)', sync)]
    assert 'call Delay3' in departure and 'call CopyScreenTileBufferToVRAM' in departure
    assert 'ld [wSSAnneSmokeDriftAmount], a\n\tldh [rOBP1], a' in departure
    assert 'ld a, $1\n\tld de, VermilionDockOAMBlock\n\tcall WriteOAMBlock' in smoke
    assert 'ld hl, wShadowOAMSprite04XCoord' in drift and '\tinc [hl]\n\tinc [hl]' in drift
    assert 'ldh [rSCX], a' in sync and 'ld h, $0' in sync
    assert 'ld hl, vChars1 tile $7c\n\tld c, 4' in dust
    assert 'INCBIN "gfx/overworld/smoke.2bpp"' in dust
    assert 'call .writeOneEntry ; upper left' in oam and 'swap a ; multiply by 16' in oam
    assert 'ld [hl], b ; Y coordinate' in oam and 'ld [hl], c ; X coordinate' in oam
    dock = global_block(script, 'VermilionDock_Script')
    assert 'SetEventReuseHL EVENT_STARTED_WALKING_OUT_OF_DOCK\n\tcall Delay3' in dock
    copies = source['home/copy2.asm'].decode()
    copy_screen = global_block(copies, 'CopyScreenTileBufferToVRAM')
    copy_tiles = global_block(copies, 'CopyVideoData')
    assert copy_screen.count('call DelayFrame') == 2 and 'jp DelayFrame' in copy_screen
    assert 'cp 8' in copy_tiles and 'sub 8' in copy_tiles
    assert copy_tiles.count('call DelayFrame') == 2
    delay3 = global_block(source['home/palettes.asm'].decode(), 'Delay3')
    assert 'ld c, 3' in delay3 and 'jp DelayFrames' in delay3
    reload_player = global_block(source['home/overworld.asm'].decode(), 'LoadPlayerSpriteGraphicsCommon')
    assert reload_player.count('lb bc, BANK(RedSprite), $0c') == 2
    assert 'call CopyVideoData' in reload_player and 'jp CopyVideoData' in reload_player
    constants = source['constants/map_constants.asm'].decode()
    dims = re.search(r'map_const VERMILION_DOCK,\s+(\d+),\s+(\d+)', constants)
    width, height = [int(n) for n in dims.groups()]
    assert (width, height) == (14, 6)
    assert 'map_header VermilionDock, VERMILION_DOCK, SHIP_PORT' in source['data/maps/headers/VermilionDock.asm'].decode()
    layout = source['maps/VermilionDock.blk']
    assert len(layout) == width * height
    blocks = source['gfx/blocksets/ship_port.bst']
    tiles = tile_grids(decode_png(source['gfx/tilesets/ship_port.png']))
    # The scroll band is source screen lines $50..$7f. On this dock its art is
    # map cell rows 3..5. Translate the band with the existing 2x map scale and
    # camera, preserving its source height instead of stretching to 400x240.
    hull_cells = []
    for y in range(3, 6):
        row = []
        for x in range(10, 18):
            offset = y // 2 * width + x // 2
            ids = quadrant_ids(blocks, layout[offset], (y % 2) * 2 + x % 2)
            row.append(dict(source_x=x, source_y=y, source_tile_ids=ids,
                            grid=compose_grid(tiles, ids)))
        hull_cells.append(row)
    puff = decode_png(source['gfx/overworld/smoke.png'])
    assert len(puff) == 8 and all(len(row) == 8 for row in puff)
    # rOBP1=$00 maps ALL nonzero sprite indices to white. Index zero remains
    # transparent. LoadSmokeTileFourTimes repeats the SAME original 8x8 tile.
    mask = [''.join('1' if puff[y % 8][x % 8] != 0 else '0' for x in range(16)) for y in range(16)]
    header = dict(schema=1, source_revision=REVISION)
    art = dict(header, pattern_phase=[0, 0], map_width_cells=width * 2,
               band=dict(source_y=3, height_cells=3), hull=dict(source_x=10, cells=hull_cells),
               water_grid=compose_grid(tiles, [0x14] * 4),
               smoke=dict(source_indices=puff, mask=mask, palette=0, copies=4,
                          policy='source index zero transparent; OBP1=0 nonzero indices white'))
    timing = dict(header, source_hz=60, native_hz=30, initial_wait=initial_wait,
                  smoke_load_wait=4, transfer_wait=6, erase_transfer_wait=2, player_reload_wait=4, walkout_wait=3, chunks=chunks, pixels_per_chunk=steps,
                  source_frames_per_pixel=frames_per_pixel, final_wait=final_wait,
                  band_top=band_top, band_bottom=band_bottom,
                  oam_initial_x=int(re.search(r'ld a, (\d+)\n\tld \[wSSAnneSmokeX\]', departure)[1]),
                  oam_y=int(re.search(r'ld b, (\d+)', smoke)[1]),
                  puff_chunk_decrement=int(re.search(r'sub (\d+)', smoke)[1]),
                  puff_step_drift=2, oam_x_offset=8, oam_y_offset=16,
                  reference_view_left=96, hardware_width=160,
                  audio_cues=[dict(symbol='SFX_STOP_ALL_MUSIC', source_frame=0),
                              dict(symbol='MUSIC_SURFING', source_frame=0),
                              dict(symbol='SFX_SS_ANNE_HORN', source_frame=4 + initial_wait + 6),
                              dict(symbol='SFX_SS_ANNE_HORN', source_frame=4 + initial_wait + 6 + chunks * steps * frames_per_pixel + 2)],
                  audio_status='cue-only; no audio engine/playback or audio acceptance',
                  coordinate_policy='world 2x source scale; source screen band anchored to dock rows 3..5; OAM byte wrap and offscreen clipping retained')
    return {'art.json': encoded(art), 'timing.json': encoded(timing)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, default=REFERENCE)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    if args.check:
        for name, raw in artifacts.items():
            assert (OUTPUT / name).read_bytes() == raw, 'ship output differs: ' + name
    else:
        assert args.output, 'explicit output directory required'
        args.output.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (args.output / name).write_bytes(raw)

if __name__ == '__main__':
    main()
