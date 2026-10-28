#!/usr/bin/env python3
"""Project exact Blue Tower and Snorlax scripts; raw reference stays outside Git."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUTPUT = ROOT / 'Source/data/towerStory'
FILES = [f'scripts/{name}.asm' for name in ('PokemonTower2F', 'PokemonTower6F', 'PokemonTower7F', 'MrFujisHouse', 'Route12', 'Route16')]
FILES += [f'data/maps/objects/{name}.asm' for name in ('PokemonTower2F', 'PokemonTower6F', 'PokemonTower7F', 'MrFujisHouse', 'Route12', 'Route16')]
FILES += ['engine/items/item_effects.asm', 'engine/battle/common_text.asm', 'engine/battle/core.asm']


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def build(reference):
    revision = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != REVISION:
        raise ValueError('reference must be exact pinned pokered revision')
    sources, pins = {}, {}
    for name in FILES:
        raw = (reference / name).read_bytes()
        canonical = subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}'])
        if raw != canonical:
            raise ValueError('modified reference input: ' + name)
        sources[name] = raw.decode()
        pins[name] = hashlib.sha256(raw).hexdigest()
    tower = sources['scripts/PokemonTower7F.asm']
    rows = re.findall(r'map_coord_movement\s+(\d+),\s*(\d+),\s*(\w+)', tower)
    assert len(rows) == 12
    actors = []
    for index, home in enumerate(((9, 11), (12, 9), (9, 7)), 1):
        positions, variants = set(), []
        for x, y, label in rows[(index - 1) * 4:index * 4]:
            player = dict(x=int(x), y=int(y))
            path = re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)', tower.split(label + ':', 1)[1].split('db -1', 1)[0])
            path = [d.lower() for d in path]
            # Trainer approaches horizontally until adjacent. The first row
            # per Rocket is a talk from below; no approach in that case.
            px, py = player['x'], player['y']
            origin = home if py != home[1] else (px - 1 if index != 2 else px + 1, py)
            nx, ny = origin
            for step in [None] + path:
                if step:
                    dx, dy = dict(up=(0, -1), down=(0, 1), left=(-1, 0), right=(1, 0))[step]
                    nx, ny = nx + dx, ny + dy
                positions.add((nx, ny))
            assert 0 < len(path) <= 8 and ny > home[1]
            variants.append(dict(player=player, origin=dict(x=origin[0], y=origin[1]), path=path,
                                 destination=dict(x=nx, y=ny), source_label=label))
        # Include source horizontal approach cells; moving them remains the
        # trainer owner, but a resumed completed source pose must validate.
        for x in range(min(v['origin']['x'] for v in variants), max(v['origin']['x'] for v in variants) + 1):
            positions.add((x, home[1]))
        actors.append(dict(id=f'pokered:POKEMON_TOWER_7F:objects:{index}',
                           home=dict(x=home[0], y=home[1]), variants=variants,
                           script_positions=[dict(x=x, y=y) for x, y in sorted(positions)]))
    source6 = sources['scripts/PokemonTower6F.asm']
    match = re.search(r'PokemonTower6FMarowakCoords:\s*dbmapcoord\s+(\d+),\s*(\d+)', source6)
    assert match and match.groups() == ('10', '16')
    assert 'ld a, 30' in source6 and 'SetEvent EVENT_BEAT_GHOST_MAROWAK' in source6
    flute = sources['engine/items/item_effects.asm']
    snorlax = []
    for route, obj in ((12, 1), (16, 7)):
        block = flute.split(f'Route{route}SnorlaxFluteCoords:', 1)[1].split('db -1', 1)[0]
        points = [dict(x=int(x), y=int(y)) for x, y in re.findall(r'dbmapcoord\s+(\d+),\s*(\d+)', block)]
        source = sources[f'scripts/Route{route}.asm']
        assert 'ld a, 30' in source and f'SetEvent EVENT_BEAT_ROUTE{route}_SNORLAX' in source
        objects = re.findall(r'object_event\s+(\d+),\s*(\d+),\s*(\w+)', sources[f'data/maps/objects/Route{route}.asm'])
        x, y, sprite = objects[obj - 1]
        assert sprite == 'SPRITE_SNORLAX'
        snorlax.append(dict(id=f'pokered:ROUTE_{route}:objects:{obj}', map_id=f'pokered:ROUTE_{route}',
                            x=int(x), y=int(y), flute_positions=points, species='snorlax', level=30,
                            defeated_flag=f'EVENT_BEAT_ROUTE{route}_SNORLAX',
                            fight_flag=f'EVENT_FIGHT_ROUTE{route}_SNORLAX',
                            woke_text=f'_Route{route}SnorlaxWokeUpText',
                            after_text='_Route12SnorlaxCalmedDownText' if route == 12 else '_Route16SnorlaxReturnedToMountainsText'))
    source2 = sources['scripts/PokemonTower2F.asm']
    rival_paths = {}
    positions = {(14,5)}
    for name, label in [('left', 'PokemonTower2FRivalDownThenRightMovement'), ('below', 'PokemonTower2FRivalRightThenDownMovement')]:
        block = source2.split(label + ':',1)[1].split('db -1',1)[0]
        route = [d.lower() for d in re.findall(r'db NPC_MOVEMENT_(UP|DOWN|LEFT|RIGHT)', block)]
        x, y = 14, 5
        for direction in route:
            dx, dy = dict(up=(0,-1), down=(0,1), left=(-1,0), right=(1,0))[direction]
            x, y = x+dx, y+dy
            positions.add((x,y))
        assert (x,y) == (18,9)
        rival_paths[name] = route
    scenes = dict(rockets=actors, snorlax=snorlax,
                  rival=dict(id='pokered:POKEMON_TOWER_2F:objects:1', origin=dict(x=14,y=5),
                             triggers=[dict(x=15,y=5,left=True,player_facing='left',actor_facing='right'),
                                       dict(x=14,y=6,left=False,player_facing='up',actor_facing='down')],
                             paths=rival_paths, script_positions=[dict(x=x,y=y) for x,y in sorted(positions)],
                             rival_party_indices=dict(charmander=4,squirtle=5,bulbasaur=6)),
                  ghost=dict(id='pokered:POKEMON_TOWER_6F:hidden_events:1', x=10, y=16,
                             species='marowak', level=30, flag='EVENT_BEAT_GHOST_MAROWAK'),
                  fuji=dict(id='pokered:POKEMON_TOWER_7F:objects:4',
                            house_id='pokered:MR_FUJIS_HOUSE:objects:5',
                            destination=dict(map_id='pokered:MR_FUJIS_HOUSE', x=3, y=7, facing='up')))
    return {'scenes.json': encoded(dict(schema=1, source_revision=REVISION, scenes=scenes)),
            'provenance.json': encoded(dict(schema=1, source_revision=REVISION, files=pins))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, data in build(args.reference).items():
        path = OUTPUT / name
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                raise SystemExit('stale scene projection: ' + str(path))
        else:
            path.write_bytes(data)


if __name__ == '__main__':
    main()
