#!/usr/bin/env python3
"""Cerulean Cave, the Hall of Fame rematch, and the post-credits Continue spawn.

Reads the pinned pokered revision. Does not invent a wild slot, an item, a
second champion roster, or a Mew.
"""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUTPUT = ROOT / 'Source/data/postgame'
FILES = [
    'data/wild/maps/CeruleanCave1F.asm',
    'data/wild/maps/CeruleanCave2F.asm',
    'data/wild/maps/CeruleanCaveB1F.asm',
    'data/wild/probabilities.asm',
    'data/maps/objects/CeruleanCave1F.asm',
    'data/maps/objects/CeruleanCave2F.asm',
    'data/maps/objects/CeruleanCaveB1F.asm',
    'data/maps/objects/HallOfFame.asm',
    'scripts/HallOfFame.asm',
    'scripts/ChampionsRoom.asm',
    'constants/event_constants.asm',
    'constants/battle_constants.asm',
    'constants/trainer_constants.asm',
    'home/trainers.asm',
    'engine/battle/end_of_battle.asm',
    'home/overworld.asm',
    'engine/menus/main_menu.asm',
    'data/maps/special_warps.asm',
    'text/CeruleanCaveB1F.asm',
    'data/text/text_1.asm',
    'data/trainers/parties.asm',
]
FLOORS = ('CeruleanCave1F', 'CeruleanCave2F', 'CeruleanCaveB1F')


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def pinned(reference):
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
    return sources, pins


def item_ids():
    text = (ROOT / 'Source/data/items.lua').read_text()
    found = dict(re.findall(r'\["([A-Z0-9_]+)"\] = "([A-Za-z0-9]+)"', text))
    if 'FULL_RESTORE' not in found or 'MAX_ELIXER' not in found:
        raise ValueError('item symbol table changed')
    return found


def weights(text):
    found = [int(value) for value in re.findall(r'wild_chance\s+(\d+)', text)]
    if len(found) != 10 or sum(found) != 256:
        raise ValueError('wild slot weights are not the 256-roll table')
    return found


def grass_table(text):
    rate, water, slots = None, None, []
    mode, skip = None, False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith('IF DEF(_RED)'):
            skip = True
            continue
        if stripped.startswith('IF DEF(_BLUE)'):
            skip = False
            continue
        if stripped == 'ENDC':
            skip = False
            continue
        if skip:
            continue
        grass = re.match(r'def_grass_wildmons\s+(\d+)', stripped)
        water_match = re.match(r'def_water_wildmons\s+(\d+)', stripped)
        if grass:
            mode, rate = 'grass', int(grass.group(1))
            continue
        if water_match:
            mode, water = 'water', int(water_match.group(1))
            continue
        if stripped.startswith('end_grass_wildmons') or stripped.startswith('end_water_wildmons'):
            mode = None
            continue
        slot = re.match(r'db\s+(\d+),\s*([A-Z0-9_]+)', stripped)
        if slot and mode == 'grass':
            slots.append((int(slot.group(1)), slot.group(2)))
    if rate is None or water is None or len(slots) != 10:
        raise ValueError('grass table is not 10 Blue slots')
    return rate, water, slots


def map_objects(text):
    label = re.search(r'def_warps_to\s+([A-Z0-9_]+)', text)
    if label is None:
        raise ValueError('map object label missing')
    constant = label.group(1)
    items, statics, people, index = [], [], [], 0
    for line in text.splitlines():
        found = re.match(
            r'\tobject_event\s+(\d+),\s+(\d+),\s+(\w+),\s+\w+,\s+\w+,\s+\w+(?:,\s+([A-Z0-9_]+))?(?:,\s+(\d+))?\s*$',
            line)
        if not found:
            continue
        index += 1
        row = dict(index=index, x=int(found.group(1)), y=int(found.group(2)), sprite=found.group(3),
                   id='pokered:' + constant + ':objects:' + str(index))
        if found.group(5):
            row['species'] = found.group(4)
            row['level'] = int(found.group(5))
            statics.append(row)
        elif found.group(4):
            row['symbol'] = found.group(4)
            items.append(row)
        else:
            people.append(row)
    return constant, items, statics, people


def text_record(text, label, source):
    lines = text.splitlines()
    start = next((index for index, line in enumerate(lines) if line.startswith(label + '::')), None)
    if start is None:
        raise ValueError('missing text ' + label)
    recipe = []
    for index in range(start + 1, len(lines)):
        raw = lines[index]
        if raw.startswith('_') or (raw and not raw.startswith('\t') and not raw.startswith(';')):
            break
        stripped = raw.strip()
        if not stripped or stripped.startswith(';'):
            continue
        line_no = index + 1
        if stripped.startswith('text_ram '):
            recipe.append(dict(op='text_ram', source_line=line_no, symbol=stripped.split()[1]))
        elif stripped == 'text_end':
            recipe.append(dict(op='control', source='text_end', source_line=line_no))
        elif stripped == 'done':
            recipe.append(dict(op='control', source='done', source_line=line_no))
        else:
            found = re.match(r'(text|line|cont|para) "(.*)"$', stripped)
            if not found:
                raise ValueError('unparsed text line: ' + stripped)
            recipe.append(dict(op=found.group(1), source_line=line_no, text=found.group(2)))
    if not recipe:
        raise ValueError('empty text ' + label)
    return dict(recipe=recipe, source=source)


def indigo_events(text):
    body = text.split('DEF INDIGO_PLATEAU_EVENTS_START EQU const_value', 1)[1]
    body = body.split('DEF INDIGO_PLATEAU_EVENTS_END EQU const_value - 1', 1)[0]
    names = re.findall(r'const (EVENT_[A-Z0-9_]+)', body)
    if 'EVENT_BEAT_CHAMPION_RIVAL' not in names:
        raise ValueError('champion flag left the Hall of Fame reset range')
    return names


def battle_model(sources):
    end = sources['home/trainers.asm'].split('EndTrainerBattle::', 1)[1]
    end = end.split('ResetButtonPressedAndMapScript::', 1)[0]
    if 'cp LOST_BATTLE' not in end or 'jp z, ResetButtonPressedAndMapScript' not in end:
        raise ValueError('EndTrainerBattle no longer treats only a loss as incomplete')
    if 'TrainerFlagAction' not in end or 'cp OPP_ID_OFFSET' not in end or 'predef HideObject' not in end:
        raise ValueError('EndTrainerBattle no longer hides a wild static after the flag')
    if 'DEF LOST_BATTLE EQU $FF' not in sources['constants/battle_constants.asm']:
        raise ValueError('LOST_BATTLE changed')
    if 'DEF OPP_ID_OFFSET EQU 200' not in sources['constants/trainer_constants.asm']:
        raise ValueError('OPP_ID_OFFSET changed')
    faint = sources['home/overworld.asm'].split('.allPokemonFainted', 1)[1].split('NewBattle::', 1)[0]
    if 'ld a, LOST_BATTLE' not in faint or 'ld [wIsInBattle], a' not in faint:
        raise ValueError('a party wipe no longer marks the battle lost')
    reset = sources['engine/battle/end_of_battle.asm'].split('.resetVariables', 1)[1]
    if 'ld [wIsInBattle], a' not in reset.split('ld [wBattleType], a', 1)[0]:
        raise ValueError('EndOfBattle no longer clears wIsInBattle')
    # A run returns through EndOfBattle, which clears wIsInBattle, so EndTrainerBattle
    # sets the flag and hides the sprite. Only a party wipe writes LOST_BATTLE.
    return dict(hide_on=['victory', 'caught', 'run'], stay_on=['defeat'],
                lost_marker='LOST_BATTLE', source='home/trainers.asm:EndTrainerBattle')


def continue_spawn(sources):
    pressed = sources['engine/menus/main_menu.asm'].split('.pressedA', 1)[1].split('InitOptions:', 1)[0]
    down = pressed.find('PLAYER_DIR_DOWN')
    hall = pressed.find('cp HALL_OF_FAME')
    teams = pressed.find('ld a, [wNumHoFTeams]')
    destination = pressed.find('ld [wDestinationMap], a')
    if not (0 <= down < hall and 0 <= teams < hall < destination):
        raise ValueError('post-Hall Continue no longer special-warps')
    if 'xor a' not in pressed[hall:destination]:
        raise ValueError('Hall Continue destination is no longer map 0')
    found = re.search(r'\.PalletTown:\s+fly_warp PALLET_TOWN,\s+(\d+),\s+(\d+)',
                      sources['data/maps/special_warps.asm'])
    if found is None:
        raise ValueError('Pallet fly warp missing')
    return dict(zone_id='pokered:PALLET_TOWN', map='PALLET_TOWN', x=int(found.group(1)),
                y=int(found.group(2)), facing='down', source='data/maps/special_warps.asm:.PalletTown')


def champion_roster(sources):
    parties = sources['data/trainers/parties.asm']
    if parties.count('Rival3Data:') != 1 or 'Rival4Data:' in parties:
        raise ValueError('champion rematch roster is not the one Rival3 table')
    chunk = parties.split('Rival3Data:', 1)[1].split('LoreleiData:', 1)[0]
    teams = re.findall(r'db \$FF,.*', chunk)
    if len(teams) != 3:
        raise ValueError('Rival3 team count changed')
    script = sources['scripts/ChampionsRoom.asm']
    if 'ld a, [wRivalStarter]' not in script or 'ld a, OPP_RIVAL3' not in script:
        raise ValueError('champion battle no longer selects Rival3 by starter')
    return dict(roster='same', selector='wRivalStarter', party_label='Rival3Data', teams=3,
                opponent='OPP_RIVAL3')


def build(reference):
    sources, pins = pinned(reference)
    symbols = item_ids()
    slot_weights = weights(sources['data/wild/probabilities.asm'])
    model = battle_model(sources)
    floors = []
    mewtwo = None
    for name in FLOORS:
        rate, water, slots = grass_table(sources['data/wild/maps/' + name + '.asm'])
        constant, items, statics, people = map_objects(sources['data/maps/objects/' + name + '.asm'])
        if people:
            raise ValueError(name + ' has an unexpected non-item object')
        if water != 0:
            raise ValueError(name + ' water rate changed')
        grass = []
        for index, (level, species) in enumerate(slots):
            if species in ('MEW', 'MEWTWO'):
                raise ValueError(name + ' wild table contains ' + species)
            grass.append(dict(index=index, level=level, species=species.lower(),
                              species_source=species, weight_256=slot_weights[index]))
        pickups = []
        for item in items:
            if item['sprite'] != 'SPRITE_POKE_BALL':
                raise ValueError(name + ' item is not a pokeball')
            pickups.append(dict(id=item['id'], index=item['index'], x=item['x'], y=item['y'],
                                symbol=item['symbol'], item=symbols[item['symbol']]))
        floors.append(dict(map=name, map_constant=constant, grass_rate=rate, water_rate=water,
                           grass=grass, items=pickups))
        for static in statics:
            if static['species'] == 'MEWTWO':
                if mewtwo is not None:
                    raise ValueError('more than one Mewtwo')
                mewtwo = static
                mewtwo['map'] = name
                mewtwo['map_constant'] = constant
    if mewtwo is None or mewtwo['level'] != 70 or (mewtwo['x'], mewtwo['y']) != (27, 13):
        raise ValueError('Mewtwo is not the B1F level 70 object at (27, 13)')
    if mewtwo['sprite'] != 'SPRITE_MONSTER' or mewtwo['id'] != 'pokered:CERULEAN_CAVE_B1F:objects:1':
        raise ValueError('Mewtwo object identity changed')
    hall_constant, hall_items, hall_statics, hall_people = map_objects(sources['data/maps/objects/HallOfFame.asm'])
    if hall_constant != 'HALL_OF_FAME' or hall_items or hall_statics or len(hall_people) != 1:
        raise ValueError('Hall of Fame object list changed')
    oak = hall_people[0]
    if oak['index'] != 1 or oak['sprite'] != 'SPRITE_OAK':
        raise ValueError('Hall of Fame Oak is not object 1')
    hall_script = sources['scripts/HallOfFame.asm']
    if 'TOGGLE_CERULEAN_CAVE_GUY' not in hall_script or 'predef HideObject' not in hall_script:
        raise ValueError('Hall of Fame no longer hides the cave guard')
    if 'ResetEventRange INDIGO_PLATEAU_EVENTS_START, INDIGO_PLATEAU_EVENTS_END, 1' not in hall_script:
        raise ValueError('Hall of Fame no longer resets the full Indigo range')
    positions = [[mewtwo['x'], mewtwo['y'] - 1], [mewtwo['x'], mewtwo['y'] + 1],
                 [mewtwo['x'] - 1, mewtwo['y']], [mewtwo['x'] + 1, mewtwo['y']]]
    story = dict(
        schema=1, source_revision=REVISION,
        cave=dict(
            hide='TOGGLE_CERULEAN_CAVE_GUY',
            opens_when='HallOfFame HideObject',
            floors=floors,
            mewtwo=dict(id=mewtwo['id'], map=mewtwo['map'], map_constant=mewtwo['map_constant'],
                        x=mewtwo['x'], y=mewtwo['y'], level=mewtwo['level'], species=mewtwo['species'],
                        sprite=mewtwo['sprite'], flag='EVENT_BEAT_MEWTWO', text='_MewtwoBattleText',
                        cry='mewtwo', positions=positions, battle=model),
        ),
        rematch=dict(
            champion_flag='EVENT_BEAT_CHAMPION_RIVAL',
            indigo_events=indigo_events(sources['constants/event_constants.asm']),
            oak_id='pokered:HALL_OF_FAME:objects:1',
            hall_zone='pokered:HALL_OF_FAME',
            hook_id='pokered:HALL_OF_FAME:script:rematch',
            roster=champion_roster(sources),
            continue_spawn=continue_spawn(sources),
        ),
    )
    play = dict(
        schema=1, source_revision=REVISION,
        texts={
            '_MewtwoBattleText': text_record(sources['text/CeruleanCaveB1F.asm'], '_MewtwoBattleText',
                                             'text/CeruleanCaveB1F.asm'),
            '_FoundItemText': text_record(sources['data/text/text_1.asm'], '_FoundItemText',
                                          'data/text/text_1.asm'),
            '_NoMoreRoomForItemText': text_record(sources['data/text/text_1.asm'], '_NoMoreRoomForItemText',
                                                  'data/text/text_1.asm'),
        },
    )
    return {
        'story.json': encoded(story),
        'play.json': encoded(play),
        'provenance.json': encoded(dict(schema=1, source_revision=REVISION, files=pins)),
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    if args.check:
        for name, raw in artifacts.items():
            if (args.output / name).read_bytes() != raw:
                raise SystemExit('postgame story drift: ' + name)
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (args.output / name).write_bytes(raw)
    print('postgame source plan: ' + ', '.join(artifacts))


if __name__ == '__main__':
    main()
