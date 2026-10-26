#!/usr/bin/env python3
"""Generate only new scene records from vendored checksum-pinned Blue inputs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from PIL import Image
from tools.generate_cerulean_content import text_recipes

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / 'tools/references/tutorial-escort.json'
INPUT = ROOT / 'tools/references/tutorial-escort'
OUTPUT = ROOT / 'Source/data/tutorialEscort/scenes.json'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
DIRECTIONS = {'UP': 'up', 'DOWN': 'down', 'LEFT': 'left', 'RIGHT': 'right', 'NO_INPUT': 'wait'}


def inputs(directory=INPUT):
    pin = json.loads(PIN.read_text())
    assert pin['revision'] == REVISION and pin['repository'] == 'https://github.com/pret/pokered'
    result = {}
    for entry in pin['files']:
        raw = (Path(directory) / entry['path']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == entry['sha256'], entry['path']
        result[entry['path']] = raw
    return result


def section(text, label):
    return text.split(label + ':', 1)[1].split('\n\tdb -1', 1)[0]


def rle(text, label, prefix):
    result = []
    for direction, count in re.findall(r'db (\w+), (\d+)', section(text, label)):
        key = direction.removeprefix(prefix)
        result.extend([DIRECTIONS[key]] * int(count))
    assert result
    return result


def build(directory=INPUT):
    source = inputs(directory)
    text = lambda path: source[path].decode()
    auto = text('engine/overworld/auto_movement.asm')
    # Simulated joypad is a LIFO buffer; NPC directions are consumed forwards.
    player = list(reversed(rle(auto, 'RLEList_PewterGymPlayer', 'PAD_')))
    npc = rle(auto, 'RLEList_PewterGymGuy', 'NPC_MOVEMENT_')
    approaches = {}
    coords = text('engine/events/pewter_guys.asm').split('PewterGymGuyCoords:', 1)[1]
    for y, x, name in re.findall(r'db (\d+), (\d+)\s+dw \.(\w+)', coords):
        row = re.split(r'^\.' + name + r'\n', coords, maxsplit=1, flags=re.M)[1].split('$ff', 1)[0]
        directions = re.findall(r'PAD_(UP|DOWN|LEFT|RIGHT)|\$00', row)
        route = [DIRECTIONS[d] if d else 'wait' for d in directions]
        approaches[x + ',' + y] = list(reversed(route)) + player
    script = text('scripts/PewterCity.asm')
    triggers = [[int(x), int(y)] for x, y in re.findall(r'dbmapcoord (\d+), (\d+)', section(script, 'PewterCityPlayerLeavingEastCoords'))]
    departure = [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(\w+)', section(script, 'MovementData_PewterGymGuyExit'))]
    texts = {}
    for path in ('text/ViridianCity.asm', 'text/PewterCity.asm'):
        for label, recipe in text_recipes(text(path)).items():
            if 'OldMan' in label or 'ViridianCityGirl' in label or 'PewterCityYoungster' in label:
                texts[label] = {'source': path, 'recipe': recipe}
    art = {}
    for name, path in {'oldmanBack': 'gfx/battle/oldmanb.png', 'weedle': 'gfx/pokemon/front/weedle.png',
                       'youngster': 'gfx/sprites/youngster.png', 'gambler': 'gfx/sprites/gambler.png',
                       'sleepy': 'gfx/sprites/gambler_asleep.png'}.items():
        image = Image.open(io.BytesIO(source[path])); image.load()
        assert image.mode == 'L' and set(image.getdata()) <= {0, 85, 170, 255}
        mapping = {255: '.', 170: '1', 85: '2', 0: '#'}
        art[name] = {'source': path, 'width': image.width, 'height': image.height,
                     'rows': [''.join(mapping[image.getpixel((x, y))] for x in range(image.width)) for y in range(image.height)]}
    # Stable IDs are object ordinals in the pinned objects, never runtime order.
    ids = {}
    for map_name, constant, selections in [('ViridianCity', 'VIRIDIAN_CITY', {'sleepy': 5, 'girl': 4, 'oldman': 7}),
                                          ('PewterCity', 'PEWTER_CITY', {'escort': 5})]:
        rows = re.findall(r'object_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\w+),\s*(\w+),\s*(\w+)', text('data/maps/objects/' + map_name + '.asm'))
        for key, index in selections.items():
            x, y, sprite, movement, facing, label = rows[index - 1]
            ids[key] = {'id': f'pokered:{constant}:objects:{index}', 'x': int(x), 'y': int(y),
                        'sprite': sprite, 'movement': movement, 'facing': facing, 'text_id': label}
    return {'schema': 1, 'source_revision': REVISION, 'actors': ids, 'texts': texts, 'art': art,
            'escort': {'triggers': triggers, 'player_routes': approaches, 'npc_route': npc, 'departure': departure,
                       'player_end': [10, 18], 'npc_end': [12, 18], 'final_facing': 'left'},
            'tutorial': {'species': 'weedle', 'level': 5, 'ball': 'pokeBall', 'display_quantity': 50,
                         'scripted_catch': True, 'yes_means': 'in-a-hurry', 'gate': 'EVENT_GOT_POKEDEX',
                         'sleepy_trigger': [19, 9]}}


def encoded(directory=INPUT):
    return (json.dumps(build(directory), ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()
    data = encoded()
    if args.check:
        assert args.output.read_bytes() == data, 'scene output differs'
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(data)

if __name__ == '__main__':
    main()
