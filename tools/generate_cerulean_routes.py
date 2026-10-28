#!/usr/bin/env python3
"""Project pinned Blue script paths and references, never duplicate teams or text."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import Reference, decode_map

REFERENCE = ROOT / 'tools/references/cerulean-routes'
OUTPUT = ROOT / 'Source/data/ceruleanRoutes/scenes.json'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
VECTORS = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}


def inputs(reference=REFERENCE):
    manifest = json.loads((REFERENCE / 'manifest.json').read_text())
    assert manifest['revision'] == REVISION
    result = {}
    for name, digest in manifest['files'].items():
        raw = (reference / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('pinned Blue input drift: ' + name)
        if name.endswith('.asm'):
            result[name] = raw.decode()
    return result


def block(text, label):
    match = re.search(r'^' + re.escape(label) + r':?\n(.*?)(?=^[A-Za-z_.][\w.]*:?\n|\Z)', text, re.M | re.S)
    if not match:
        raise ValueError('missing source block: ' + label)
    return match[1]


def movements(text, label):
    value = re.findall(r'\bdb NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)', block(text, label))
    if not value or len(value) > 16:
        raise ValueError('unbounded or empty source path: ' + label)
    return [direction.lower() for direction in value]


def coords(text, label):
    return [{'x': int(x), 'y': int(y)} for x, y in re.findall(r'dbmapcoord\s+(\d+),\s*(\d+)', block(text, label))]


def positions(origin, paths):
    found = {(origin['x'], origin['y'])}
    for path in paths:
        x, y = origin['x'], origin['y']
        for direction in path:
            dx, dy = VECTORS[direction]
            x, y = x + dx, y + dy
            found.add((x, y))
    return [{'x': x, 'y': y} for x, y in sorted(found)]


def build(reference=REFERENCE):
    source = inputs(reference)
    pins = json.loads((REFERENCE / 'manifest.json').read_text())['files']
    decoded = {name: decode_map(Reference(reference, pins), name) for name in ('Route22', 'CeruleanCity')}
    route = source['scripts/Route22.asm']
    city = source['scripts/CeruleanCity.asm']
    bridge = source['scripts/Route24.asm']
    starters = {key: value.lower() for key, value in re.findall(r'DEF (STARTER\d) EQU (\w+)', source['constants/pokemon_constants.asm'])}
    table = block(route.split('Route22Rival1StartBattleScript:', 1)[1], '.StarterTable')
    route_numbers = {starters[key]: int(number) for key, number in re.findall(r'db (STARTER\d), (\d+)', table)}
    # The city branch has the same starter order. Parse its three literal loads.
    # Branch text includes jr .done before the next labels, so take the complete
    # region ending at the actual .done label instead.
    selection = city.split('; select which team', 1)[1].split('\n.done\n', 1)[0]
    numbers = [int(n, 16) for n in re.findall(r'ld a, \$(\w+)', selection)]
    assert len(numbers) == 3
    city_numbers = dict(zip([starters['STARTER2'], starters['STARTER3'], starters['STARTER1']], numbers))
    maps = {}
    for name in ('Route22', 'CeruleanCity', 'Route24'):
        rows = re.findall(r'object_event\s+(\d+),\s*(\d+),\s*(\w+)', source['data/maps/objects/' + name + '.asm'])
        maps[name] = [{'x': int(x), 'y': int(y), 'sprite': sprite} for x, y, sprite in rows]
    route_approach = movements(route, 'Route22RivalMovementData')
    # CheckCoords increments before comparing: upper is index 1, lower index 2.
    assert 'inc [hl]' in source['home/map_objects.asm'].split('CheckCoords::', 1)[1].split('.compareXCoord', 1)[0]
    route_paths = [route_approach, route_approach[1:]]
    route_exits = [movements(route, 'Route22Rival1ExitMovementData1'), movements(route, 'Route22Rival1ExitMovementData2')]
    route_origin = {key: maps['Route22'][0][key] for key in ('x', 'y')}
    city_origin = {key: maps['CeruleanCity'][0][key] for key in ('x', 'y')}
    # The scripted MAPX assignment is an internal sprite coordinate with +4 bias.
    alternate_x = int(re.search(r'ld \[hl\], (\d+)', city.split('.playerOnRightSideOfBridge', 1)[1])[1]) - 4
    city_origins = [city_origin, dict(city_origin, x=alternate_x)]
    city_approach = movements(city, 'CeruleanCityMovement1')
    city_exits = [movements(city, 'CeruleanCityMovement4'), movements(city, 'CeruleanCityMovement3')]
    result = {'schema': 1, 'source_revision': REVISION, 'rivals': {}, 'triggers': {
        'route22': coords(route, '.Route22RivalBattleCoords'),
        'cerulean': coords(city, 'CeruleanCityCoords2'),
        'thief': coords(city, 'CeruleanCityCoords1'),
        'nugget': coords(bridge, '.PlayerCoordsArray')},
        'source_toggle': 'TOGGLE_CERULEAN_ROCKET'}
    assert result['source_toggle'] in source['constants/toggle_constants.asm']
    for name, stable, origin_list, approaches, exits, roster_numbers in [
        ('route22', 'pokered:ROUTE_22:objects:1', [route_origin]*2, route_paths, route_exits, route_numbers),
        ('cerulean', 'pokered:CERULEAN_CITY:objects:1', city_origins, [city_approach]*2, city_exits, city_numbers)]:
        cells = set()
        variants = []
        for origin, approach, departure in zip(origin_list, approaches, exits):
            for cell in positions(origin, [approach + departure]):
                cells.add((cell['x'], cell['y']))
            variants.append({'origin': origin, 'approach': approach, 'departure': departure})
        collision = decoded['Route22' if name == 'route22' else 'CeruleanCity']['collision']
        exceptions = [{'x': x, 'y': y} for x, y in sorted(cells) if collision[y][x] != 0]
        result['rivals'][name] = {'id': stable, 'class': 'OPP_RIVAL1', 'roster_by_rival_starter': roster_numbers,
            'sprite_source': maps['Route22' if name == 'route22' else 'CeruleanCity'][0]['sprite'],
            'variants': variants, 'script_collision_positions': exceptions, 'script_positions': [{'x': x, 'y': y} for x, y in sorted(cells)]}
    # Preserve source label references only. The ordinary importer owns strings.
    result['labels'] = sorted(set(re.findall(r'text_far (_\w+)', route + city + bridge)))
    return result


def encoded(reference=REFERENCE):
    return json.dumps(build(reference), indent=2, sort_keys=True) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, default=REFERENCE)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = encoded(args.reference)
    if args.check:
        assert OUTPUT.read_text() == result, 'Cerulean routes projection drift'
    elif args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result)
    else:
        parser.error('choose --check or --output')


if __name__ == '__main__':
    main()
