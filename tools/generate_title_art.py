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
