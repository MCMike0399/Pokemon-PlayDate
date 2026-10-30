#!/usr/bin/env python3
"""Generate small traversal policy and checksum pins; source stays outside Git."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
INPUTS = (
    'engine/menus/start_sub_menus.asm',
    'constants/map_constants.asm',
    'constants/map_object_constants.asm',
    'constants/sprite_constants.asm',
    'engine/overworld/field_move_messages.asm',
    'engine/overworld/push_boulder.asm',
    'engine/overworld/toggleable_objects.asm',
    'engine/items/town_map.asm',
    'engine/items/item_effects.asm',
    'home/overworld.asm',
    'data/maps/special_warps.asm',
    'data/maps/objects/WardensHouse.asm',
    'data/tilesets/pair_collision_tile_ids.asm',
    'data/tilesets/water_tilesets.asm',
)
CITIES = ('PalletTown', 'ViridianCity', 'PewterCity', 'CeruleanCity',
          'LavenderTown', 'VermilionCity', 'CeladonCity', 'FuchsiaCity',
          'CinnabarIsland', 'IndigoPlateau', 'SaffronCity')


def generate(reference):
    actual = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != REVISION:
        raise ValueError('wrong pokered revision')
    sources = {name: (reference / name).read_bytes() for name in INPUTS}
    for name, raw in sources.items():
        committed = subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}'])
        if committed != raw:
            raise ValueError(f'modified pinned input: {name}')
    warps = sources['data/maps/special_warps.asm'].decode()
    fly = []
    for name in CITIES:
        constant, x, y = re.search(rf'^\.{name}:\s+fly_warp (\w+),\s+(\d+),\s+(\d+)', warps, re.M).groups()
        fly.append({'name': name, 'id': 'pallet_town' if name == 'PalletTown' else f'pokered:{constant}',
                    'source_map': constant, 'x': int(x), 'y': int(y)})
    pairs = sources['data/tilesets/pair_collision_tile_ids.asm'].decode().split('TilePairCollisionsWater::')[1]
    water_pairs = [{'tileset': tileset, 'a': int(a, 16), 'b': int(b, 16)}
                   for tileset, a, b in re.findall(r'db (\w+), \$([0-9A-F]+), \$([0-9A-F]+)', pairs)]
    policy = {'schema': 1, 'source_revision': REVISION, 'fly': fly, 'water_pairs': water_pairs,
              'water_tilesets': re.findall(r'^\s*db ([A-Z_]+)$', sources['data/tilesets/water_tilesets.asm'].decode(), re.M)}
    pins = {'schema': 1, 'source_revision': REVISION,
            'inputs': {name: hashlib.sha256(raw).hexdigest() for name, raw in sources.items()}}
    return {'Source/data/fieldTravel.json': policy, 'tools/references/field-travel.json': pins}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, value in generate(args.reference).items():
        text = json.dumps(value, indent=2) + '\n'
        path = ROOT / name
        if args.check:
            if path.read_text() != text:
                raise SystemExit(f'stale generated policy: {name}')
        else:
            path.write_text(text)
    print('Traversal source policy and pins verified.')


if __name__ == '__main__':
    main()
