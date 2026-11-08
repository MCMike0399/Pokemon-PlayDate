#!/usr/bin/env python3
"""Pinned late-Kanto, League and postgame scene plan from pokered.

The 171-map manifest does not install these maps yet. This plan records the
source objects, badge gates and room order so a later map activation can use
them without inventing coordinates or a Mew location.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUTPUT = ROOT / 'Source/data/lateKanto'
FILES = [
    'data/maps/objects/SeafoamIslandsB4F.asm',
    'data/maps/objects/PokemonMansionB1F.asm',
    'data/maps/objects/CinnabarGym.asm',
    'data/maps/objects/PowerPlant.asm',
    'data/maps/objects/ViridianGym.asm',
    'data/maps/objects/VictoryRoad2F.asm',
    'data/maps/objects/CeruleanCaveB1F.asm',
    'data/maps/objects/IndigoPlateauLobby.asm',
    'data/maps/objects/LoreleisRoom.asm',
    'data/maps/objects/BrunosRoom.asm',
    'data/maps/objects/AgathasRoom.asm',
    'data/maps/objects/LancesRoom.asm',
    'data/maps/objects/ChampionsRoom.asm',
    'data/maps/objects/HallOfFame.asm',
    'scripts/Route23.asm',
    'scripts/ChampionsRoom.asm',
    'scripts/HallOfFame.asm',
    'data/trainers/parties.asm',
    'constants/pokemon_constants.asm',
    'constants/map_constants.asm',
]
MISSING_MAPS = [
    'SeafoamIslandsB4F', 'PokemonMansionB1F', 'CinnabarGym', 'PowerPlant',
    'ViridianGym', 'VictoryRoad2F', 'CeruleanCaveB1F', 'IndigoPlateauLobby',
    'LoreleisRoom', 'BrunosRoom', 'AgathasRoom', 'LancesRoom', 'ChampionsRoom',
    'HallOfFame',
]
STATICS = {
    'articuno': ('SeafoamIslandsB4F.asm', 'ARTICUNO'),
    'zapdos': ('PowerPlant.asm', 'ZAPDOS'),
    'moltres': ('VictoryRoad2F.asm', 'MOLTRES'),
    'mewtwo': ('CeruleanCaveB1F.asm', 'MEWTWO'),
}
TRAINERS = {
    'blaine': ('CinnabarGym.asm', 'OPP_BLAINE'),
    'giovanni': ('ViridianGym.asm', 'OPP_GIOVANNI'),
}


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def map_constant(label, constants):
    folded = label.upper()
    matches = [name for name in re.findall(r'^\s*map_const\s+([A-Z0-9_]+),', constants, re.M)
               if name.replace('_', '') == folded]
    if len(matches) != 1:
        raise ValueError('map constant for ' + label + ': ' + repr(matches))
    return matches[0]


def object_row(source, species, constants):
    found = None
    index = 0
    for line in source.splitlines():
        if not line.strip().startswith('object_event'):
            continue
        index += 1
        parts = [part.strip() for part in line.split(',')]
        if species not in parts:
            continue
        if found is not None:
            raise ValueError('expected one ' + species + ' object')
        position = parts.index(species)
        level = int(parts[position + 1]) if position + 1 < len(parts) and parts[position + 1].isdigit() else None
        found = (int(parts[0].split()[-1]), int(parts[1]), level, index)
    if found is None:
        raise ValueError('expected one ' + species + ' object')
    x, y, level, index = found
    map_name = re.search(r'^(\w+)_Object:', source, re.M)[1]
    constant = map_constant(map_name, constants)
    trainer = species.startswith('OPP_')
    row = dict(map=map_name, map_constant=constant,
               id='pokered:' + constant + ':objects:' + str(index),
               x=x, y=y, species=species, kind='trainer' if trainer else 'static')
    if trainer:
        if level is None:
            raise ValueError('trainer party index missing: ' + species)
        row['party_index'] = level
    else:
        row['level'] = level
    return row


def north_room(source):
    warps = re.findall(r'warp_event\s+\d+,\s+(\d+),\s+(\w+),', source)
    forward = [(int(y), room) for y, room in warps if room != 'LAST_MAP']
    if not forward:
        return None
    return min(forward)[1]


def champion_branches(script, parties):
    chunk = script.split('ld a, [wRivalStarter]', 1)[1].split('ld [wTrainerNo], a', 1)[0]
    found = dict(re.findall(r'cp (STARTER\d)\s+jr nz, \.\w+\s+ld a, \$(\d+)', chunk))
    fallback = re.search(r'(?m)^\.NotStarter3\s+ld a, \$(\d+)', chunk)
    if set(found) != {'STARTER2', 'STARTER3'} or fallback is None:
        raise ValueError('champion starter selector changed')
    found['STARTER1'] = fallback[1]
    result = {}
    for starter, number in found.items():
        index = int(number)
        if not 1 <= index <= len(parties):
            raise ValueError('champion team index missing')
        species = [part.strip() for part in parties[index - 1].split(',')]
        result[starter] = dict(trainer_no=index, ace=species[-2])
    return result


def build(reference):
    reference = Path(reference)
    head = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if head != REVISION:
        raise ValueError('exact pinned pokered reference required')
    sources, pins = {}, {}
    for name in FILES:
        raw = (reference / name).read_bytes()
        if raw != subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}']):
            raise ValueError('modified source: ' + name)
        sources[name] = raw.decode()
        pins[name] = hashlib.sha256(raw).hexdigest()
    if 'DEF STARTER1 EQU CHARMANDER' not in sources['constants/pokemon_constants.asm']:
        raise ValueError('starter constants changed')
    if 'DEF STARTER2 EQU SQUIRTLE' not in sources['constants/pokemon_constants.asm']:
        raise ValueError('starter constants changed')
    if 'DEF STARTER3 EQU BULBASAUR' not in sources['constants/pokemon_constants.asm']:
        raise ValueError('starter constants changed')
    encounters = {}
    for name, (filename, species) in STATICS.items():
        encounters[name] = object_row(sources['data/maps/objects/' + filename], species,
                                      sources['constants/map_constants.asm'])
        if encounters[name]['kind'] != 'static':
            raise ValueError(name + ' is not a static encounter')
    trainers = {}
    for name, (filename, species) in TRAINERS.items():
        trainers[name] = object_row(sources['data/maps/objects/' + filename], species,
                                    sources['constants/map_constants.asm'])
    secret = object_row(sources['data/maps/objects/PokemonMansionB1F.asm'], 'SECRET_KEY',
                        sources['constants/map_constants.asm'])
    checks = re.findall(r'EventFlagBit a, (EVENT_PASSED_\w+)', sources['scripts/Route23.asm'])
    if len(checks) != 7 or len(set(checks)) != 7:
        raise ValueError('Route 23 badge gates changed')
    order, room = [], 'INDIGO_PLATEAU_LOBBY'
    seen = set()
    while room not in seen:
        seen.add(room)
        order.append(room)
        if room == 'HALL_OF_FAME':
            break
        room = north_room(sources['data/maps/objects/' + {
                              'INDIGO_PLATEAU_LOBBY': 'IndigoPlateauLobby.asm',
                              'LORELEIS_ROOM': 'LoreleisRoom.asm',
                              'BRUNOS_ROOM': 'BrunosRoom.asm',
                              'AGATHAS_ROOM': 'AgathasRoom.asm',
                              'LANCES_ROOM': 'LancesRoom.asm',
                              'CHAMPIONS_ROOM': 'ChampionsRoom.asm',
                              'HALL_OF_FAME': 'HallOfFame.asm',
                          }[room]])
        if room is None:
            raise ValueError('league room chain broke')
    parties = re.findall(r'db \$FF,.*', sources['data/trainers/parties.asm'].split('Rival3Data:', 1)[1].split('LoreleiData:', 1)[0])
    if len(parties) != 3:
        raise ValueError('champion party count changed')
    hall = sources['scripts/HallOfFame.asm']
    if 'ld a, TOGGLE_CERULEAN_CAVE_GUY' not in hall or 'predef HideObject' not in hall.split('TOGGLE_CERULEAN_CAVE_GUY', 1)[1][:120]:
        raise ValueError('Hall of Fame no longer hides the Cerulean Cave guard')
    if any('MEW' == row['species'] or row['species'].endswith('_MEW') for row in list(encounters.values()) + list(trainers.values())):
        raise ValueError('Mew was not in these source objects')
    scenes = dict(
        missing_maps=MISSING_MAPS,
        statics=encounters,
        trainers=trainers,
        secret_key=secret,
        route23_badge_checks=[flag.removeprefix('EVENT_PASSED_').removesuffix('_CHECK') for flag in checks],
        elite_four=order,
        champion=dict(selector='wRivalStarter', by_rival_starter=champion_branches(sources['scripts/ChampionsRoom.asm'], parties)),
        hall_of_fame=dict(hides=['TOGGLE_CERULEAN_CAVE_GUY']),
    )
    return {
        'scenes.json': encoded(dict(schema=1, source_revision=REVISION, scenes=scenes)),
        'provenance.json': encoded(dict(schema=1, source_revision=REVISION, files=pins,
                                        status='source plan only; maps are not installed and this is not campaign acceptance')),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    if args.check:
        for name, raw in artifacts.items():
            if (args.output / name).read_bytes() != raw:
                raise SystemExit('late Kanto scene drift: ' + name)
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (args.output / name).write_bytes(raw)
    print('late Kanto source plan: ' + ', '.join(artifacts))


if __name__ == '__main__':
    main()
