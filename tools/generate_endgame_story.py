#!/usr/bin/env python3
"""Generate the league story from pinned pokered scripts. No saves or badge writes."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import REVISION, Reference, blue_text, records
from tools.generate_cerulean_content import blue_source, item_ids, species, trainer_tables
from tools.generate_vermilion_preparation import text_recipes

OUTPUT = ROOT / 'Source/data/endgame'
REFERENCE_DEFAULT = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')
ROOMS = ('LoreleisRoom', 'BrunosRoom', 'AgathasRoom', 'LancesRoom')
PADS = {'PAD_UP': 'up', 'PAD_DOWN': 'down', 'PAD_LEFT': 'left', 'PAD_RIGHT': 'right'}
PLAYER_STARTERS = {'charmander': 'STARTER2', 'squirtle': 'STARTER3', 'bulbasaur': 'STARTER1'}


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def need(text, pattern, label):
    match = re.search(pattern, text, re.S)
    if not match:
        raise ValueError('source drift: ' + label)
    return match


def coords(text):
    return [{'x': int(x), 'y': int(y)} for x, y in re.findall(r'dbmapcoord\s+(\d+),\s*(\d+)', text)]


def rle(text, label):
    body = text.split(label + ':', 1)[1]
    steps = []
    for line in body.splitlines():
        clean = line.split(';', 1)[0].strip()
        if clean.startswith('db -1'):
            break
        match = re.fullmatch(r'db (PAD_[A-Z]+),\s*(\d+)', clean)
        if match:
            steps.append({'direction': PADS[match[1]], 'count': int(match[2])})
        elif clean and not clean.endswith(':'):
            if steps:
                break
    if not steps:
        raise ValueError('missing movement list: ' + label)
    return steps


def party_row(table, index):
    row = table['parties'][index - 1]
    return {'party': [{'level': mon['level'], 'species': mon['species']} for mon in row['party']],
            'payout': table['base_money'] * row['party'][-1]['level']}


def object_trainers(text):
    found = []
    seen = 0
    for index, line in enumerate(text.splitlines(), 1):
        clean = line.split(';', 1)[0]
        if not re.search(r'\bobject_event\b', clean):
            continue
        seen += 1
        match = re.search(
            r'object_event\s+(\d+),\s*(\d+),\s*(SPRITE_\w+),.*?(OPP_[A-Z0-9_]+),\s*(\d+)', clean)
        if match:
            found.append({'x': int(match[1]), 'y': int(match[2]), 'sprite_source': match[3],
                          'class_source': match[4], 'roster': int(match[5]),
                          'line': index, 'source_index': seen})
    return found


def headers(text):
    found = []
    for line in text.splitlines():
        clean = line.split(';', 1)[0].strip()
        match = re.fullmatch(r'trainer (EVENT_\w+),\s*(\d+),\s*(\w+),\s*(\w+),\s*(\w+)', clean)
        if match and '_TRAINER_' in match[1]:
            found.append({'flag': match[1], 'sight': int(match[2]),
                          'before': match[3], 'won': match[4], 'after': match[5]})
    return found


def far_label(text, anchor):
    body = text.split(anchor + ':', 1)[1]
    return need(body, r'text_far (_\w+)', anchor)[1]


def collect_texts(reference, pins, labels):
    texts = {}
    paths = sorted(path for path in pins if path.startswith('text/') or path.startswith('data/text/'))
    recipes = {}
    for path in paths:
        for label, recipe in text_recipes(blue_source(Reference(reference, pins).text(path))).items():
            recipes.setdefault(label, {'source': path, 'recipe': recipe})
    missing = []
    for label in labels:
        row = recipes.get(label)
        if row is None:
            missing.append(label)
        else:
            texts[label] = row
    if missing:
        raise ValueError('missing source text: ' + ', '.join(missing))
    return texts


def badge_bits(text):
    names = re.findall(r'const (BIT_\w+BADGE)', text)
    if names != ['BIT_BOULDERBADGE', 'BIT_CASCADEBADGE', 'BIT_THUNDERBADGE', 'BIT_RAINBOWBADGE',
                 'BIT_SOULBADGE', 'BIT_MARSHBADGE', 'BIT_VOLCANOBADGE', 'BIT_EARTHBADGE']:
        raise ValueError('badge bit order changed')
    flags = ['BADGE_' + name.removeprefix('BIT_').removesuffix('BADGE') for name in names]
    earth = names.index('BIT_EARTHBADGE')
    return flags, (0xFF ^ (1 << earth)) & 0xFF, earth


def viridian_gate(city, objects):
    need(city, r'CheckEvent EVENT_VIRIDIAN_GYM_OPEN\s+ret nz\s+ld a, \[wObtainedBadges\]\s+'
               r'cp ~\(1 << BIT_EARTHBADGE\)', 'viridian gym mask')
    trigger = need(city, r'\.gym_closed\s+ld a, \[wYCoord\]\s+cp (\d+)\s+ret nz\s+'
                         r'ld a, \[wXCoord\]\s+cp (\d+)', 'viridian gym tile')
    return {'open_event': 'EVENT_VIRIDIAN_GYM_OPEN',
            'trigger': {'x': int(trigger[2]), 'y': int(trigger[1])},
            'locked_text': far_label(city, 'ViridianCityGymLockedText'),
            'door': {'x': int(need(objects, r'warp_event\s+(\d+),\s*(\d+), VIRIDIAN_GYM,', 'gym door')[1]),
                     'y': int(need(objects, r'warp_event\s+(\d+),\s*(\d+), VIRIDIAN_GYM,', 'gym door')[2])}}


def arrows(text):
    body = text.split('ViridianGymArrowTilePlayerMovement:', 1)[1].split('db -1', 1)[0]
    rows = re.findall(r'map_coord_movement\s+(\d+),\s*(\d+),\s*(ViridianGymArrowMovement\d+)', body)
    if len(rows) != 12:
        raise ValueError('viridian arrow table changed')
    return [{'x': int(x), 'y': int(y), 'steps': rle(text, label)} for x, y, label in rows]


def giovanni(script, objects, tables, items):
    row = next(item for item in object_trainers(objects) if item['class_source'] == 'OPP_GIOVANNI')
    if (row['x'], row['y'], row['roster']) != (2, 1, 3):
        raise ValueError('Giovanni object changed')
    need(script, r'lb bc, TM_FISSURE, 1\s+call GiveItem', 'giovanni tm')
    need(script, r'set BIT_EARTHBADGE, \[hl\]', 'earth badge bit')
    need(script, r'SetEvent EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI', 'giovanni beat flag')
    need(script, r'SetEvents EVENT_2ND_ROUTE22_RIVAL_BATTLE, EVENT_ROUTE22_RIVAL_WANTS_BATTLE',
         'route 22 rival reappear')
    team = party_row(tables['OPP_GIOVANNI'], row['roster'])
    return {'id': 'pokered:VIRIDIAN_GYM:objects:1', 'map_id': 'pokered:VIRIDIAN_GYM',
            'x': row['x'], 'y': row['y'], 'sprite_source': row['sprite_source'],
            'class_source': 'OPP_GIOVANNI', 'roster': row['roster'], 'name': 'GIOVANNI',
            'party': team['party'], 'payout': team['payout'], 'item': items['TM_FISSURE'],
            'reward_flag': 'EVENT_GOT_TM27', 'badge': 'BADGE_EARTH',
            'before': [far_label(script, '.PreBattleText')],
            'won': [far_label(script, '.ReceivedEarthBadgeText')],
            'after': [far_label(script, '.PostBattleAdviceText')],
            'reward_before': [far_label(script, 'ViridianGymGiovanniEarthBadgeInfoText')],
            'reward_success': [far_label(script, 'ViridianGymGiovanniReceivedTM27Text'),
                               far_label(script, 'ViridianGymGiovanniTM27ExplanationText')],
            'reward_full': [far_label(script, 'ViridianGymGiovanniTM27NoRoomText')],
            'victory_flags': ['EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI', 'BADGE_EARTH',
                              'EVENT_2ND_ROUTE22_RIVAL_BATTLE', 'EVENT_ROUTE22_RIVAL_WANTS_BATTLE']}


def ordinary_trainers(map_name, script, objects, tables):
    people = object_trainers(objects)
    used = headers(script)
    # Giovanni and other scripted leaders are not TalkToTrainer headers.
    talkers = [person for person in people if person['class_source'] not in ('OPP_GIOVANNI', 'OPP_RIVAL3')]
    if map_name == 'ChampionsRoom':
        return []
    if len(used) != len(talkers) and map_name not in ROOMS:
        if len(used) != len(people):
            talkers = people
    if len(used) != len(talkers):
        raise ValueError(f'{map_name} trainer headers do not match its opponents')
    constant = {'LoreleisRoom': 'LORELEIS_ROOM', 'BrunosRoom': 'BRUNOS_ROOM',
                'AgathasRoom': 'AGATHAS_ROOM', 'LancesRoom': 'LANCES_ROOM',
                'ViridianGym': 'VIRIDIAN_GYM', 'VictoryRoad1F': 'VICTORY_ROAD_1F',
                'VictoryRoad2F': 'VICTORY_ROAD_2F', 'VictoryRoad3F': 'VICTORY_ROAD_3F'}[map_name]
    result = []
    for index, (person, header) in enumerate(zip(talkers, used), 1):
        # Object source indexes count every object, not only trainers.
        object_index = person['source_index']
        team = party_row(tables[person['class_source']], person['roster'])
        result.append({'id': f'pokered:{constant}:objects:{object_index}',
                       'map_id': 'pokered:' + constant, 'map': map_name,
                       'x': person['x'], 'y': person['y'], 'sprite_source': person['sprite_source'],
                       'name': tables[person['class_source']]['name'],
                       'class_source': person['class_source'], 'roster': person['roster'],
                       'party': team['party'], 'payout': team['payout'], 'sight': header['sight'],
                       'flag': header['flag'],
                       'before': [far_label(script, header['before'])],
                       'won': [far_label(script, header['won'])],
                       'after': [far_label(script, header['after'])]})
    return result


def route22_gate(script):
    need(script, r'ld a, \[wYCoord\]\s+cp 4\s+ld a, ROUTE_23\s+jr c, \.set_last_map\s+ld a, ROUTE_22',
         'route 22 gate last map')
    need(script, r'bit BIT_BOULDERBADGE', 'route 22 gate boulder check')
    points = coords(script.split('Route22GateScriptCoords:', 1)[1].split('db -1', 1)[0])
    if points != [{'x': 4, 'y': 2}, {'x': 5, 'y': 2}]:
        raise ValueError('route 22 gate guard tiles changed')
    return {'id': 'pokered:ROUTE_22_GATE:objects:1', 'coords': points, 'badge': 'BADGE_BOULDER',
            'y_split': 4, 'north_map': 'ROUTE_23', 'south_map': 'ROUTE_22',
            'denied_text': ['_Route22GateGuardNoBoulderbadgeText', '_Route22GateGuardICantLetYouPassText'],
            'accepted_text': ['_Route22GateGuardGoRightAheadText']}


def route22(script, objects, tables):
    body = script.split('.StarterTable:')[2].split('Route22Rival2AfterBattleScript', 1)[0]
    pairs = re.findall(r'db (STARTER\d), (\d+)', body)
    if pairs != [('STARTER2', '10'), ('STARTER3', '11'), ('STARTER1', '12')]:
        raise ValueError('route 22 rival roster changed')
    need(script, r'ld a, OPP_RIVAL2', 'route 22 rival class')
    need(objects, r'object_event\s+25,\s*5,\s*SPRITE_BLUE,.*TEXT_ROUTE22_RIVAL2', 'route 22 rival sprite')
    need(script, r'SetEvent EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE', 'route 22 second result')
    points = coords(script.split('.Route22RivalBattleCoords', 1)[1].split('db -1', 1)[0])
    if points != [{'x': 29, 'y': 4}, {'x': 29, 'y': 5}]:
        raise ValueError('route 22 rival tiles changed')
    by_player = {}
    for starter, rival in PLAYER_STARTERS.items():
        roster = int(dict(pairs)[rival])
        by_player[starter] = party_row(tables['OPP_RIVAL2'], roster)
    return {'id': 'pokered:ROUTE_22:objects:2', 'map_id': 'pokered:ROUTE_22',
            'sprite_source': 'SPRITE_BLUE', 'class_source': 'OPP_RIVAL2',
            'show_flags': ['EVENT_2ND_ROUTE22_RIVAL_BATTLE', 'EVENT_ROUTE22_RIVAL_WANTS_BATTLE'],
            'beat_flag': 'EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE',
            'clear_flags': ['EVENT_2ND_ROUTE22_RIVAL_BATTLE', 'EVENT_ROUTE22_RIVAL_WANTS_BATTLE'],
            'coords': points, 'by_rival_starter': {key: int(value) for key, value in pairs},
            'parties_by_player_starter': by_player,
            'before': ['_Route22RivalBeforeBattleText2'],
            'won': ['_Route22Rival2DefeatedText'], 'lost': ['_Route22Rival2VictoryText'],
            'after': ['_Route22RivalAfterBattleText2']}


def route23(script):
    block = script.split('Route23GuardsYCoords:', 1)[1].split('Route23CopyBadgeTextScript', 1)[0]
    ys = [int(value) for value in re.findall(r'^\s*db\s+(-?\d+)', block, re.M)]
    if ys[-1] != -1:
        raise ValueError('route 23 guard list is open')
    ys = ys[:-1]
    flags = re.findall(r'EventFlagBit a, (EVENT_PASSED_\w+)', script)
    if len(ys) != 7 or flags != [
            'EVENT_PASSED_EARTHBADGE_CHECK', 'EVENT_PASSED_VOLCANOBADGE_CHECK',
            'EVENT_PASSED_MARSHBADGE_CHECK', 'EVENT_PASSED_SOULBADGE_CHECK',
            'EVENT_PASSED_RAINBOWBADGE_CHECK', 'EVENT_PASSED_THUNDERBADGE_CHECK',
            'EVENT_PASSED_CASCADEBADGE_CHECK']:
        raise ValueError('route 23 badge gates changed')
    need(script, r'cp 35\s+jr nz, \.not_past_victory_road\s+ld a, \[wXCoord\]\s+cp 14\s+ret nc',
         'victory road x gate')
    guards = []
    for index, (y, flag) in enumerate(zip(ys, flags)):
        badge = 'BADGE_' + flag.removeprefix('EVENT_PASSED_').removesuffix('BADGE_CHECK')
        row = {'y': y, 'badge': badge, 'passed': flag, 'object_index': index + 1,
               'id': f'pokered:ROUTE_23:objects:{index + 1}'}
        if y == 35:
            row['x_below'] = 14
        guards.append(row)
    resets = re.findall(r'EVENT_VICTORY_ROAD_[23]_BOULDER_ON_SWITCH\d', script)
    if resets != ['EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1', 'EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2',
                  'EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1', 'EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH2']:
        raise ValueError('route 23 boulder reset changed')
    return {'guards': guards,
            'denied_text': '_Route23YouDontHaveTheBadgeYetText',
            'accepted_text': ['_Route23OhThatIsTheBadgeText', '_Route23GoRightAheadText'],
            'sign_text': '_Route23VictoryRoadGateSignText',
            'reset_events': resets,
            'show_toggle': 'TOGGLE_VICTORY_ROAD_3F_BOULDER',
            'hide_toggle': 'TOGGLE_VICTORY_ROAD_2F_BOULDER'}


def victory_road(sources):
    first = sources['scripts/VictoryRoad1F.asm']
    second = sources['scripts/VictoryRoad2F.asm']
    third = sources['scripts/VictoryRoad3F.asm']
    one = coords(first)
    two = coords(second)
    three = coords(third.split('.SwitchOrHoleCoords:', 1)[1].split('db -1', 1)[0])
    if one != [{'x': 17, 'y': 13}] or two != [{'x': 1, 'y': 16}, {'x': 9, 'y': 16}]:
        raise ValueError('victory road switch coordinates changed')
    if three != [{'x': 3, 'y': 5}, {'x': 23, 'y': 15}]:
        raise ValueError('victory road 3F switch or hole changed')
    need(first, r'ld a, \$1d\s+ld \[wNewTileBlockID\], a\s+lb bc, 6, 4', '1F door block')
    need(second, r'ld a, \$15\s+lb bc, 4, 3', '2F first door')
    need(second, r'ld a, \$1d\s+lb bc, 7, 11', '2F second door')
    need(third, r'ld a, \$1d\s+ld \[wNewTileBlockID\], a\s+lb bc, 5, 3', '3F door block')
    return {'switches': [
        {'map': 'VictoryRoad1F', 'map_id': 'pokered:VICTORY_ROAD_1F', 'x': 17, 'y': 13,
         'event': 'EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH', 'block': {'x': 4, 'y': 6}, 'tile': 29},
        {'map': 'VictoryRoad2F', 'map_id': 'pokered:VICTORY_ROAD_2F', 'x': 1, 'y': 16,
         'event': 'EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1', 'block': {'x': 3, 'y': 4}, 'tile': 21},
        {'map': 'VictoryRoad2F', 'map_id': 'pokered:VICTORY_ROAD_2F', 'x': 9, 'y': 16,
         'event': 'EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2', 'block': {'x': 11, 'y': 7}, 'tile': 29},
        {'map': 'VictoryRoad3F', 'map_id': 'pokered:VICTORY_ROAD_3F', 'x': 3, 'y': 5,
         'event': 'EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH1', 'block': {'x': 3, 'y': 5}, 'tile': 29},
    ], 'hole': {'map': 'VictoryRoad3F', 'x': 23, 'y': 15,
                'event': 'EVENT_VICTORY_ROAD_3_BOULDER_ON_SWITCH2',
                'hide_toggle': 'TOGGLE_VICTORY_ROAD_3F_BOULDER',
                'show_toggle': 'TOGGLE_VICTORY_ROAD_2F_BOULDER'}}


def rooms(sources, tables):
    result = []
    for name in ROOMS:
        script = sources[f'scripts/{name}.asm']
        objects = sources[f'data/maps/objects/{name}.asm']
        people = object_trainers(objects)
        if len(people) != 1:
            raise ValueError(name + ' opponent count changed')
        person = people[0]
        header = headers(script)[0]
        team = party_row(tables[person['class_source']], person['roster'])
        constant = {'LoreleisRoom': 'LORELEIS_ROOM', 'BrunosRoom': 'BRUNOS_ROOM',
                    'AgathasRoom': 'AGATHAS_ROOM', 'LancesRoom': 'LANCES_ROOM'}[name]
        row = {'map': name, 'map_id': 'pokered:' + constant, 'id': f'pokered:{constant}:objects:1',
               'x': person['x'], 'y': person['y'], 'sprite_source': person['sprite_source'],
               'name': tables[person['class_source']]['name'],
               'class_source': person['class_source'], 'roster': person['roster'],
               'party': team['party'], 'payout': team['payout'], 'sight': header['sight'],
               'flag': header['flag'],
               'before': [far_label(script, header['before'])],
               'won': [far_label(script, header['won'])],
               'after': [far_label(script, header['after'])]}
        if name != 'LancesRoom':
            label = {'LoreleisRoom': 'LoreleiScriptWalkIntoRoom',
                     'BrunosRoom': 'BrunoScriptWalkIntoRoom',
                     'AgathasRoom': 'AgathaScriptWalkIntoRoom'}[name]
            body = script.split(label + ':', 1)[1].split('\n\n', 1)[0]
            pad = need(body, r'ld a, (PAD_[A-Z]+)', label)
            count = need(body, r'ld a, \$([0-9a-fA-F]+)\s+ld \[wSimulatedJoypadStatesIndex\], a', label)
            row['walk_in'] = [{'direction': PADS[pad[1]], 'count': int(count[1], 16)}]
            row['entrance'] = coords(script)
            row['autowalk_event'] = need(script, r'CheckAndSetEvent (EVENT_AUTOWALKED_INTO_\w+)', name + ' autowalk')[1]
            row['dont_run_text'] = far_label(script, {
                'LoreleisRoom': 'LoreleisRoomLoreleiDontRunAwayText',
                'BrunosRoom': 'BrunosRoomBrunoDontRunAwayText',
                'AgathasRoom': 'AgathasRoomAgathaDontRunAwayText'}[name])
            block = need(script, r'lb bc, (\d+), (\d+)\s+predef_jump ReplaceTileBlock', name + ' exit')
            row['exit_block'] = {'y': int(block[1]), 'x': int(block[2])}
        else:
            row['lock_event'] = 'EVENT_LANCES_ROOM_LOCK_DOOR'
            row['beat_event'] = 'EVENT_BEAT_LANCE'
            row['entrance_blocks'] = [{'y': 6, 'x': 2}, {'y': 6, 'x': 3}]
            row['trigger'] = coords(script)
            row['lock_coords'] = [row['trigger'][2], row['trigger'][3]]
            row['walk_coord'] = row['trigger'][4]
            row['walk'] = rle(script, 'WalkToLance_RLEList')
            need(script, r'lb bc, 6, 2', 'lance first door')
            need(script, r'lb bc, 6, 3', 'lance second door')
        result.append(row)
    return result


def champion(script, objects, tables):
    body = script.split('cp STARTER2', 1)[1].split('.saveTrainerId:', 1)[0]
    if 'ld a, $1' not in body or 'cp STARTER3' not in body or 'ld a, $2' not in body:
        raise ValueError('champion starter switch changed')
    need(script, r'ld a, OPP_RIVAL3', 'champion class')
    need(objects, r'object_event\s+4,\s*2,\s*SPRITE_BLUE,.*TEXT_CHAMPIONSROOM_RIVAL', 'champion sprite')
    need(script, r'SetEvent EVENT_BEAT_CHAMPION_RIVAL', 'champion result')
    # The fall-through after both compares is trainer 3, STARTER1.
    numbers = {'STARTER2': 1, 'STARTER3': 2, 'STARTER1': 3}
    parties = {starter: party_row(tables['OPP_RIVAL3'], roster) for starter, roster in numbers.items()}
    by_player = {player: parties[rival] for player, rival in PLAYER_STARTERS.items()}
    aces = {starter: parties[starter]['party'][-1]['species'].upper() for starter in numbers}
    if aces != {'STARTER2': 'BLASTOISE', 'STARTER3': 'VENUSAUR', 'STARTER1': 'CHARIZARD'}:
        raise ValueError('champion ace changed')
    return {'id': 'pokered:CHAMPIONS_ROOM:objects:1', 'map_id': 'pokered:CHAMPIONS_ROOM',
            'sprite_source': 'SPRITE_BLUE', 'class_source': 'OPP_RIVAL3',
            'selector': 'wRivalStarter', 'by_rival_starter': numbers,
            'parties_by_player_starter': by_player, 'aces': aces,
            'flag': 'EVENT_BEAT_CHAMPION_RIVAL',
            'walk': rle(script, 'RivalEntrance_RLEMovement'),
            'before': [far_label(script, '.IntroText')],
            'won': [far_label(script, 'RivalDefeatedText')],
            'lost': [far_label(script, 'RivalVictoryText')],
            'after': [far_label(script, 'ChampionsRoomRivalAfterBattleText')]}


def champion_labels(script):
    labels = re.findall(r'text_far (_\w+)', script)
    if len(labels) < 2:
        raise ValueError('champion text changed')
    return labels


def credit_timing(movie):
    """Frame counts from engine/movie/credits.asm, in source order."""
    pc = movie.split('HallOfFamePC:', 1)[1].split('FadeInCredits:', 1)[0]
    preamble = [int(value) for value in re.findall(r'ld c, (\d+)\s+call DelayFrames', pc)]
    fade = re.search(r'FadeInCredits:\s+ld hl, HoFGBPalettes\s+ld b, (\d+)', movie)
    fade_hold = re.search(r'\.loop\s+ld a, \[hli\]\s+ldh \[rBGP\], a\s+ld c, (\d+)\s+call DelayFrames', movie)
    scroll = re.search(r'ld bc, (\d+)\s+\.scrollLoop1', movie)
    scroll_window = re.search(r'ld c, (\d+)\s+\.scrollLoop2', movie)
    holds = {}
    label = None
    wanted = {
        'fadeInTextAndShowMon': 'CRED_TEXT_FADE_MON',
        'showTextAndShowMon': 'CRED_TEXT_MON',
        'fadeInText': 'CRED_TEXT_FADE',
        'showText': 'CRED_TEXT',
        'showTheEnd': 'CRED_THE_END',
    }
    for line in movie.split('Credits:', 1)[1].split('TheEndTextString:', 1)[0].splitlines():
        clean = line.split(';', 1)[0].strip()
        named = re.fullmatch(r'\.(\w+)', clean)
        if named:
            label = named[1]
            continue
        delay = re.fullmatch(r'ld c, (\d+)', clean)
        if delay and label in wanted and wanted[label] not in holds:
            holds[wanted[label]] = int(delay[1])
    if (preamble != [100, 128] or not fade or fade[1] != '4' or not fade_hold or fade_hold[1] != '5'
            or not scroll or scroll[1] != '7' or not scroll_window or scroll_window[1] != '20'
            or holds != {'CRED_TEXT_FADE_MON': 90, 'CRED_TEXT_MON': 110, 'CRED_TEXT_FADE': 120,
                         'CRED_TEXT': 140, 'CRED_THE_END': 16}):
        raise ValueError('credits frame timing changed')
    return {
        'preamble_frames': preamble,
        'fade_steps': int(fade[1]),
        'fade_hold': int(fade_hold[1]),
        'scroll_tiles': [int(scroll[1]), int(scroll_window[1])],
        'hold': holds,
    }


def hall(script, objects, credits_text, order_text, monsters, constants, movie):
    need(script, r'predef HallOfFamePC', 'hall of fame credits')
    need(script, r'ld a, PALLET_TOWN\s+ld \[wLastBlackoutMap\], a', 'pallet blackout')
    need(script, r'ld a, TOGGLE_CERULEAN_CAVE_GUY', 'cerulean cave guy')
    pointers = re.findall(r'dw (Cred\w+)', blue_source(credits_text))
    names = re.findall(r'const (CRED_[A-Z0-9_]+)', constants.split('DEF NUM_CRED_STRINGS', 1)[0])
    if len(pointers) != len(names) or names[0] != 'CRED_VERSION':
        raise ValueError('credit pointer table changed')
    strings = {}
    selected = blue_source(credits_text)
    for label, name in zip(pointers, names):
        body = selected.split(label + ':', 1)[1]
        match = re.search(r'db\s+(-?\d+),\s+"([^"]*)@"', body)
        if not match:
            raise ValueError('credit string changed: ' + label)
        strings[name] = {'offset': int(match[1]), 'text': match[2]}
    commands = {'CRED_TEXT_FADE_MON', 'CRED_TEXT_MON', 'CRED_TEXT_FADE', 'CRED_TEXT', 'CRED_THE_END'}
    frames, pending, mon_index = [], [], 0
    copyright_line = False
    timing = credit_timing(movie)
    mons = re.findall(r'^\s*db ([A-Z0-9_]+)\s*$', monsters.split('CreditsMons:', 1)[1], re.M)
    order_body = '\n'.join(line.split(';', 1)[0] for line in order_text.split('CreditsOrder:', 1)[1].splitlines())
    for token in re.findall(r'\b(CRED_[A-Z0-9_]+)\b', order_body):
        if token == 'CRED_COPYRIGHT':
            # LoadCopyrightTiles draws the copyright graphic; it is not a staff string.
            copyright_line = True
            continue
        if token in commands:
            frame = {'command': token, 'lines': [strings[item]['text'] for item in pending]}
            pending = []
            if copyright_line:
                frame['copyright'] = True
                copyright_line = False
            if token in ('CRED_TEXT_FADE_MON', 'CRED_TEXT_MON'):
                frame['mon'] = species(mons[mon_index])
                mon_index += 1
            if token == 'CRED_THE_END':
                frame['end'] = True
                frame['graphic'] = need(movie, r'INCBIN "(gfx/credits/the_end\.2bpp)"', 'the end graphic')[1]
            frames.append(frame)
        else:
            if token not in strings:
                raise ValueError('unknown credit token: ' + token)
            pending.append(token)
    if pending or mon_index != len(mons):
        raise ValueError('credit order did not consume every line and monster')
    if frames[0]['lines'][1] != 'BLUE VERSION STAFF' or frames[0]['mon'] != 'venusaur':
        raise ValueError('blue credits opening changed')
    oaks = [line for line in objects.splitlines()
            if line.split(';', 1)[0].strip().startswith('object_event')]
    if len(oaks) != 1:
        raise ValueError('hall of fame oak object changed')
    return {'oak_id': 'pokered:HALL_OF_FAME:objects:1',
            'oak_text': far_label(script, 'HallOfFameOakText'), 'walk': rle(script, 'HallOfFameEntryMovement'),
            'hides': ['TOGGLE_CERULEAN_CAVE_GUY'], 'blackout_map': 'PALLET_TOWN',
            'return_to': 'title', 'saves': False,
            'timing': timing, 'credits': frames}


def build(reference):
    reference = Path(reference)
    head = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if head != REVISION:
        raise ValueError('exact pinned pokered reference required')
    names = [
        'constants/ram_constants.asm', 'constants/item_constants.asm', 'constants/trainer_constants.asm',
        'constants/credits_constants.asm', 'data/trainers/names.asm', 'data/trainers/pic_pointers_money.asm',
        'data/trainers/parties.asm', 'data/credits/credits_text.asm', 'data/credits/credits_order.asm',
        'data/credits/credits_mons.asm', 'engine/movie/credits.asm',
        'scripts/ViridianCity.asm', 'data/maps/objects/ViridianCity.asm', 'scripts/ViridianGym.asm',
        'scripts/Route22.asm', 'data/maps/objects/Route22.asm', 'scripts/Route22Gate.asm',
        'scripts/Route23.asm', 'scripts/VictoryRoad1F.asm', 'scripts/VictoryRoad2F.asm',
        'scripts/VictoryRoad3F.asm', 'scripts/ChampionsRoom.asm', 'scripts/HallOfFame.asm',
        'data/maps/objects/ViridianGym.asm', 'data/maps/objects/ChampionsRoom.asm',
        'data/maps/objects/HallOfFame.asm',
    ]
    for room in ROOMS:
        names.append(f'scripts/{room}.asm')
        names.append(f'data/maps/objects/{room}.asm')
    for map_name in ('VictoryRoad1F', 'VictoryRoad2F', 'VictoryRoad3F'):
        names.append(f'data/maps/objects/{map_name}.asm')
        names.append(f'scripts/{map_name}.asm')
    text_names = ['ViridianCity', 'ViridianGym', 'Route22', 'Route22Gate', 'Route23', 'VictoryRoad1F', 'VictoryRoad2F',
                  'VictoryRoad3F', 'LoreleisRoom', 'BrunosRoom', 'AgathasRoom', 'LancesRoom',
                  'ChampionsRoom', 'HallOfFame', 'IndigoPlateauLobby']
    for name in text_names:
        for suffix in ('', '_2'):
            relative = f'text/{name}{suffix}.asm'
            if (reference / relative).is_file():
                names.append(relative)
    pins, sources = {}, {}
    for name in dict.fromkeys(names):
        raw = (reference / name).read_bytes()
        pinned = subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{name}'])
        if raw != pinned:
            raise ValueError('modified source: ' + name)
        pins[name] = hashlib.sha256(raw).hexdigest()
        sources[name] = raw.decode()
    ref = Reference(reference, pins)
    tables = trainer_tables(ref)
    items = item_ids(ref)
    flags, mask, earth = badge_bits(sources['constants/ram_constants.asm'])
    gym_script = sources['scripts/ViridianGym.asm']
    leader = giovanni(gym_script, sources['data/maps/objects/ViridianGym.asm'], tables, items)
    gym_trainers = ordinary_trainers('ViridianGym', gym_script, sources['data/maps/objects/ViridianGym.asm'], tables)
    road_trainers = []
    for map_name in ('VictoryRoad1F', 'VictoryRoad2F', 'VictoryRoad3F'):
        road_trainers.extend(ordinary_trainers(
            map_name, sources[f'scripts/{map_name}.asm'], sources[f'data/maps/objects/{map_name}.asm'], tables))
    league = rooms(sources, tables)
    rival = route22(sources['scripts/Route22.asm'], sources['data/maps/objects/Route22.asm'], tables)
    champ_script = sources['scripts/ChampionsRoom.asm']
    champ = champion(champ_script, sources['data/maps/objects/ChampionsRoom.asm'], tables)
    story = {
        'schema': 1, 'source_revision': REVISION,
        'badge_bits': flags, 'viridian_gym': {
            'required_mask': mask, 'earth_bit': earth,
            **viridian_gate(sources['scripts/ViridianCity.asm'], sources['data/maps/objects/ViridianCity.asm']),
            'arrows': arrows(gym_script), 'leader': leader, 'trainers': gym_trainers,
        },
        'route22_rival': rival,
        'route22_gate': route22_gate(sources['scripts/Route22Gate.asm']),
        'route23': route23(sources['scripts/Route23.asm']),
        'victory_road': {**victory_road(sources), 'trainers': road_trainers},
        'elite_four': league,
        'champion': champ,
        'hall_of_fame': hall(sources['scripts/HallOfFame.asm'], sources['data/maps/objects/HallOfFame.asm'],
                             sources['data/credits/credits_text.asm'],
                             sources['data/credits/credits_order.asm'], sources['data/credits/credits_mons.asm'],
                             sources['constants/credits_constants.asm'], sources['engine/movie/credits.asm']),
    }
    labels = set()

    def walk(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key in ('before', 'won', 'after', 'lost', 'reward_before', 'reward_success', 'reward_full',
                           'accepted_text', 'denied_text') and isinstance(child, list):
                    labels.update(child)
                elif key in ('locked_text', 'denied_text', 'sign_text', 'dont_run_text', 'oak_text',
                             'accepted_text') and isinstance(child, str):
                    labels.add(child)
                else:
                    walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
    walk(story)
    story['texts'] = collect_texts(reference, pins, sorted(labels))
    return {'story.json': encoded(story),
            'provenance.json': encoded({'schema': 1, 'source_revision': REVISION, 'files': pins,
                                        'status': 'generated league story; no campaign save and no badge write'})}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, default=REFERENCE_DEFAULT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    if args.check:
        for name, raw in artifacts.items():
            path = OUTPUT / name
            if not path.is_file() or path.read_bytes() != raw:
                raise SystemExit('stale endgame story: ' + name)
        print('endgame story check ok')
        return
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, raw in artifacts.items():
        (OUTPUT / name).write_bytes(raw)
    print('endgame story written')


if __name__ == '__main__':
    main()
