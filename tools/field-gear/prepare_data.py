#!/usr/bin/env python3
"""Generate bounded Blue bicycle/fishing policy; retain only small checksum pins."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
INPUTS = (
    'home/overworld.asm',
    'data/tilesets/bike_riding_tilesets.asm',
    'engine/overworld/player_state.asm',
    'engine/items/item_effects.asm',
    'engine/menus/start_sub_menus.asm',
    'data/maps/force_bike_surf.asm',
    'data/wild/good_rod.asm',
    'data/wild/super_rod.asm',
    'scripts/Route16Gate1F.asm',
    'scripts/Route18Gate1F.asm',
)


def generate(reference):
    actual = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != REVISION:
        raise ValueError('wrong pokered revision')
    sources = {}
    for name in INPUTS:
        raw = (reference / name).read_bytes()
        committed = subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}'])
        if raw != committed:
            raise ValueError(f'modified pinned input: {name}')
        sources[name] = raw
    overworld = sources['home/overworld.asm'].decode()
    bike_section = sources['data/tilesets/bike_riding_tilesets.asm'].decode().split('BikeRidingTilesets::')[1].split('db -1')[0]
    tilesets = re.findall(r'\bdb ([A-Z_]+)', bike_section)
    force = sources['data/maps/force_bike_surf.asm'].decode()
    triggers = [{'map': name, 'x': int(x), 'y': int(y)}
                for name, x, y in re.findall(r'force_bike_surf (ROUTE_\d+),\s+(\d+),\s+(\d+)', force)]
    gates = []
    for name in ('Route16Gate1F', 'Route18Gate1F'):
        script = sources[f'scripts/{name}.asm'].decode()
        section = script.split('.StopsPlayerCoords:')[1].split('db -1')[0]
        cells = [{'x': int(x), 'y': int(y)} for x, y in re.findall(r'dbmapcoord\s+(\d+),\s+(\d+)', section)]
        gates.append({'map': 'ROUTE_16_GATE_1F' if name.startswith('Route16') else 'ROUTE_18_GATE_1F',
                      'stops': cells, 'return_direction': 'right'})
    super_source = sources['data/wild/super_rod.asm'].decode()
    groups = {}
    for number, section in re.findall(r'\.Group(\d+):\s*\n(.*?)(?=\n\.Group|\Z)', super_source, re.S):
        rows = [{'level': int(level), 'species': species.lower()}
                for level, species in re.findall(r'\bdb (\d+), ([A-Z_]+)', section)]
        count = int(re.search(r'\bdb (\d+)\s*\n', section).group(1))
        if count != len(rows) or not 1 <= count <= 4:
            raise ValueError('unsupported fishing group')
        groups[number] = rows
    super_maps = {name: number for name, number in re.findall(r'dbw (\w+),\s+\.Group(\d+)', super_source)}
    good = [{'level': int(level), 'species': species.lower()}
            for level, species in re.findall(r'\bdb (\d+), ([A-Z_]+)', sources['data/wild/good_rod.asm'].decode())]
    items = sources['engine/items/item_effects.asm'].decode()
    old_section = items.split('ItemUseOldRod:')[1].split('ItemUseGoodRod:')[0]
    level, species = re.search(r'lb bc, (\d+), ([A-Z_]+)', old_section).groups()
    policy = {'schema': 1, 'source_revision': REVISION,
              'bicycle': {'tilesets': tilesets, 'maps': ['ROUTE_23', 'INDIGO_PLATEAU'],
                          'forced_entries': triggers, 'gates': gates},
              'fishing': {'old': {'level': int(level), 'species': species.lower()},
                          'good': good, 'super': super_maps, 'groups': groups}}
    pins = {'schema': 1, 'source_revision': REVISION,
            'inputs': {name: hashlib.sha256(raw).hexdigest() for name, raw in sources.items()}}
    return {'Source/data/fieldGear.json': policy, 'tools/references/field-gear.json': pins}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', required=True, type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, value in generate(args.reference).items():
        text = json.dumps(value, indent=2) + '\n'
        path = ROOT / name
        if args.check:
            if path.read_text() != text:
                raise SystemExit(f'stale generated gear policy: {name}')
        else:
            path.write_text(text)
    print('Bicycle and fishing source policy verified.')


if __name__ == '__main__':
    main()
