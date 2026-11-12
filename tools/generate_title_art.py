#!/usr/bin/env python3
"""Generate new title/trainer assets with the pinned battle-art reader/threshold.

No existing Pokemon, tile or overworld sprite is rewritten. All inputs must
match the checked-in manifest before any output is created.
"""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.generate_battle_art import References, threshold, REVISION

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tools/references/title-art.json'


def copyright_tile_sequence(text):
    """title.asm .tileScreenCopyrightTiles, repeats included."""
    label = text.index('.tileScreenCopyrightTiles\n')
    line = text[label:].split('db', 1)[1].split('\n', 1)[0].split(';', 1)[0]
    return [int(item, 16) for item in line.replace('$', ' ').replace(',', ' ').split() if item]


def copyright_tile(nintendo, freak, tile):
    if 0x41 <= tile <= 0x45:
        offset = (tile - 0x41) * 8
        return nintendo.crop((offset, 0, offset + 8, 8))
    if 0x46 <= tile <= 0x4E:
        offset = (tile - 0x46) * 8
        return freak.crop((offset, 0, offset + 8, 8))
    raise ValueError('copyright tile out of range')


def generate(reference_root, output, check=False):
    manifest = json.loads(MANIFEST.read_text())
    if manifest['schema'] != 1 or manifest['revision'] != REVISION:
        raise ValueError('unsupported title art source pin')
    reader = References(manifest, root=reference_root)
    for entry in manifest['sources']:
        if hashlib.sha256(reader.read(entry['path'])).hexdigest() != entry['sha256']:
            raise ValueError('pinned source table changed: ' + entry['path'])
    prepared = []
    for entry in manifest['inputs']:
        raw = reader.read(entry['path'])
        if hashlib.sha256(raw).hexdigest() != entry['sha256']:
            raise ValueError('pinned title input changed: ' + entry['path'])
        image = Image.open(io.BytesIO(raw)).convert('L')
        if list(image.size) != entry['size']:
            raise ValueError('unexpected title input dimensions')
        image = threshold(image)
        if entry['scale'] != 1:
            image = image.resize((image.width * entry['scale'], image.height * entry['scale']), Image.Resampling.NEAREST)
        prepared.append((entry['output'], image))
    by_output = dict(prepared)
    nintendo = by_output.get('font/copyright_tiles.png')
    freak = by_output.get('font/gamefreak_inc.png')
    if nintendo is not None and freak is not None:
        # .tileScreenCopyrightTiles repeats $42. The row is that sequence,
        # not the fourteen unique tiles in VRAM order.
        sequence = copyright_tile_sequence(reader.read('engine/movie/title.asm').decode())
        strip = Image.new('1', (8 * len(sequence), 8), 1)
        for index, tile in enumerate(sequence):
            strip.paste(copyright_tile(nintendo, freak, tile), (index * 8, 0))
        prepared.append(('font/title_copyright.png', strip))
    for relative, image in prepared:
        target = output / relative
        if check:
            actual = Image.open(target).convert('L')
            if actual.size != image.size or actual.tobytes() != image.convert('L').tobytes():
                raise ValueError('title output differs: ' + relative)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            image.save(target)
    return len(prepared)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    print(f'{generate(args.reference_root, args.output_dir, args.check)} pinned title/trainer images verified')


if __name__ == '__main__':
    main()
