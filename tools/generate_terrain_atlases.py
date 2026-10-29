#!/usr/bin/env python3
"""Pack canonical terrain pixels into lazy per-tileset SDK matrix tables.

Uses the previously qualified terrain formula and current pinned map grids.
Pillow is required; no unmerged Git object, Simulator or USB access is needed.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import zlib
import sys

from PIL import Image

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.generate_kanto_maps import encode_png
from tools.terrain_atlases.pixels import render
from tools.generate_source_map_cache import build as build_cache, canonical, require

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Source/terrainAtlases'
PIXEL_COMMIT = '5a03fc3aab025418f80f06ab523a4ec8f3510d72'
SHADES = '.12#'


def identity(rows, policy):
    require(len(rows) == 16 and all(isinstance(row, str) and len(row) == 16
            and set(row) <= set(SHADES) for row in rows), 'invalid canonical terrain grid')
    cells = ''.join(rows)
    packed = ''.join(f'{SHADES.index(cells[i]) * 4 + SHADES.index(cells[i + 1]):x}'
                     for i in range(0, 256, 2))
    patterns = [''.join(f'{byte:02x}' for byte in policy[name]) for name in ('light', 'dark')]
    return '/'.join(patterns + [packed[i:i + 16] for i in range(0, 128, 16)]) + '.png'


def build():
    inputs = {}

    def read(relative):
        path = ROOT / relative
        require(path.is_file() and not path.is_symlink(), 'missing or symlinked input: ' + relative)
        raw = path.read_bytes()
        inputs[relative] = hashlib.sha256(raw).hexdigest()
        return json.loads(raw)

    policy = read('Source/data/importedTonePatterns.json')
    require(policy == dict(schema=1, enabled=True, approval='approved', preview=False,
                           family='bayer8', phase=[0, 0],
                           light=[85, 187, 85, 255, 85, 187, 85, 255],
                           dark=[0, 170, 68, 170, 0, 170, 68, 170]),
            'exact approved 31.25/68.75 fixed-phase Bayer bytes required')
    manifest = read('Source/data/sourceMaps.json')
    for entry in manifest['maps'].values():
        read('Source/' + entry['path'])
    source = ROOT / 'Source'
    grids = read('Source/data/sourceMapCache/tile-grids.json')
    require(canonical(grids) == build_cache(source / 'data/sourceMaps.json', source)['tile-grids.json'],
            'canonical source tile cache differs from pinned maps')
    replacements = read('Source/data/fieldMoveTiles.json')
    require(replacements['schema'] == 1 and replacements['source_revision'] == grids['source_revision'],
            'field replacement revision differs')
    pixels = {}
    groups, used, skipped = {}, set(), []
    for inventory in (grids['tiles'], replacements['tiles']):
        for key, tile in sorted(inventory.items()):
            name = identity(tile['grid'], policy)
            raw = render(tile['grid'], policy)
            require(name not in pixels or pixels[name] == raw, 'terrain identity collision: ' + key)
            pixels[name] = raw
            used.add(name)
            if key.startswith('adapter:'):
                skipped.append(key)
                continue
            parts = key.split(':')
            require(len(parts) == 4 and parts[0] == 'pokered' and parts[2] == 'cell'
                    and parts[1].replace('_', '').isalpha() and parts[1].isupper(),
                    'unexpected tileset key: ' + key)
            entries = groups.setdefault(parts[1], {})
            value = dict(grid=''.join(tile['grid']), pixel=name)
            require(key not in entries or entries[key] == value, 'conflicting source grid: ' + key)
            entries[key] = value
    artifacts, summaries = {}, {}
    for tileset, entries in sorted(groups.items()):
        names = sorted({entry['pixel'] for entry in entries.values()})
        # A one-column matrix has no padding frames; getImage(n) is source order.
        raster = []
        for name in names:
            image = Image.open(io.BytesIO(pixels[name]))
            require(image.mode == '1' and image.size == (32, 32), 'invalid historical terrain PNG')
            raster.extend([[int(image.getpixel((x, y)) != 0) for x in range(32)] for y in range(32)])
        stem = tileset.lower()
        png_name = stem + '-table-32-32.png'
        artifacts[png_name] = encode_png(raster, 1)
        indices = {name: i + 1 for i, name in enumerate(names)}
        table = dict(schema=1, tileset=tileset, source_revision=grids['source_revision'],
                     policy=policy, frame_count=len(names),
                     entries={key: dict(index=indices[value['pixel']], grid=value['grid'])
                              for key, value in sorted(entries.items())})
        artifacts[stem + '.json'] = canonical(table)
        # Check the assembled atlas cells independently against current source/patterns.
        image = Image.open(io.BytesIO(artifacts[png_name]))
        for key, entry in table['entries'].items():
            for y in range(32):
                for x in range(32):
                    shade = entry['grid'][(y // 2) * 16 + x // 2]
                    expected = 1 if shade == '.' else 0 if shade == '#' else (
                        policy['light' if shade == '1' else 'dark'][y % 8] >> (7 - x % 8)) & 1
                    require(int(image.getpixel((x, (entry['index'] - 1) * 32 + y)) != 0) == expected,
                            'atlas pixel differs from approved source/pattern: ' + key)
        summaries[tileset] = dict(keys=len(entries), frames=len(names),
                                  png=png_name, compiled=stem + '.pdt')
    provenance = dict(schema=1, base_commit='4957e67109657942e055b575ce74d94bd6c9738b',
                      source_revision=grids['source_revision'], qualification_pixel_commit=PIXEL_COMMIT,
                      unique_images=len(pixels), inputs=inputs,
                      generators={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                  for name in ('tools/generate_terrain_atlases.py',
                                               'tools/generate_source_map_cache.py',
                                               'tools/generate_kanto_maps.py',
                                               'tools/terrain_atlases/pixels.py')},
                      excluded_adapter_keys=sorted(set(skipped)), tilesets=summaries,
                      render_contract=dict(size=[32, 32], scale=2, phase=[0, 0], opaque=True,
                                           bit_order='MSB first; 1 is white',
                                           packing='one-column matrix, no padding frames'),
                      artifacts={name: dict(sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw))
                                 for name, raw in sorted(artifacts.items())})
    artifacts['provenance.json'] = canonical(provenance)
    return artifacts


def check(artifacts, output):
    require(output.is_dir() and not output.is_symlink(), 'missing or symlinked atlas directory')
    paths = list(output.rglob('*'))
    require(not any(path.is_symlink() for path in paths), 'symlinked atlas artifact')
    require({path.relative_to(output).as_posix() for path in paths if path.is_file()} == set(artifacts),
            'atlas artifact inventory differs')
    for name, raw in artifacts.items():
        require((output / name).read_bytes() == raw, 'atlas artifact drift: ' + name)


def compiled_inventory(artifacts, bundle):
    directory = bundle / 'terrainAtlases'
    tables = {name.removesuffix('-table-32-32.png') + '.pdt'
              for name in artifacts if name.endswith('.png')}
    require({path.name for path in directory.glob('*.pdt')} == tables, 'compiled PDT inventory differs')
    require(not list(directory.rglob('*.pdi')), 'unexpected per-image PDI in atlas directory')
    for name in tables:
        path = directory / name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size > 16,
                'missing or empty compiled table: ' + name)
        raw = path.read_bytes()
        require(raw[:16] == b'Playdate IMT\0\0\0\x80',
                'unexpected SDK 3.1.2 compressed imagetable header: ' + name)
        size, width, height, count = struct.unpack_from('<4I', raw, 16)
        descriptor = json.loads(artifacts[name.removesuffix('.pdt') + '.json'])
        require((width, height, count) == (32, 32, descriptor['frame_count']),
                'compiled PDT dimensions/frame inventory differs: ' + name)
        require(len(zlib.decompress(raw[32:])) == size, 'compiled PDT payload size differs: ' + name)
    for name, raw in artifacts.items():
        if name.endswith('.json'):
            require((directory / name).read_bytes() == raw, 'compiled atlas metadata differs: ' + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--compiled-bundle', type=Path)
    args = parser.parse_args()
    artifacts = build()
    if args.check:
        check(artifacts, args.output)
    else:
        require(not args.output.exists(), 'fresh atlas output directory required')
        args.output.mkdir(parents=True)
        for name, raw in artifacts.items():
            (args.output / name).write_bytes(raw)
    if args.compiled_bundle:
        compiled_inventory(artifacts, args.compiled_bundle)
    provenance = json.loads(artifacts['provenance.json'])
    print(f"Verified {len(provenance['tilesets'])} flat SDK tables, "
          f"{sum(item['frames'] for item in provenance['tilesets'].values())} frames, "
          f"{provenance['unique_images']} unique pixel images")


if __name__ == '__main__':
    main()
