#!/usr/bin/env python3
"""Map, battle, jingle, and cue tables cited from the pinned pret/pokered tree.

The Lua file is data only. Source/audio/select.lua is the decision code a
host Lua 5.4 probe can load without Playdate.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.audio.catalog import Catalog
from tools.audio.scores import ASSETS, map_routes
from tools.audio.source import AudioError, Source

ROOT = Path(__file__).resolve().parents[2]

# Classes that battle only as gym leaders. Giovanni also fights in the
# Rocket Hideout and Silph Co, so a missing gymLeaderNo must not infer him.
UNIQUE_GYM = (
    'OPP_BROCK', 'OPP_MISTY', 'OPP_LT_SURGE', 'OPP_ERIKA',
    'OPP_KOGA', 'OPP_BLAINE', 'OPP_SABRINA',
)
GIOVANNI_GYM = 'pokered:VIRIDIAN_GYM'
ALIASES = {
    'pallet_town': 'pokered:PALLET_TOWN',
    'reds_house': 'pokered:REDS_HOUSE_1F',
    'reds_house_2f': 'pokered:REDS_HOUSE_2F',
    'blues_house': 'pokered:BLUES_HOUSE',
    'route_1': 'pokered:ROUTE_1',
    'route1': 'pokered:ROUTE_1',
    'oaks_lab': 'pokered:OAKS_LAB',
}
LEGENDARY = {
    'articuno': ('scripts/SeafoamIslandsB4F.asm', 'ARTICUNO'),
    'zapdos': ('scripts/PowerPlant.asm', 'ZAPDOS'),
    'moltres': ('scripts/VictoryRoad2F.asm', 'MOLTRES'),
    'mewtwo': ('scripts/CeruleanCaveB1F.asm', 'MEWTWO'),
}
# score, kind, file, token. kind is music, jingle, or sfx.
CUES = (
    ('item', 'item', 'jingle', 'home/text.asm', 'SFX_GET_ITEM_1'),
    ('item2', 'item2', 'jingle', 'home/text.asm', 'SFX_GET_ITEM_2'),
    ('key_item', 'key_item', 'jingle', 'home/text.asm', 'SFX_GET_KEY_ITEM'),
    # Badge scripts name this opcode. The audio2 bank alias is not reproduced.
    ('badge', 'key_item', 'jingle', 'home/text.asm', 'SFX_GET_KEY_ITEM'),
    ('level_up', 'level_up', 'jingle', 'engine/pokemon/learn_move.asm', 'SFX_LEVEL_UP'),
    ('caught', 'caught', 'jingle', 'home/text.asm', 'SFX_CAUGHT_MON'),
    ('heal', 'heal', 'jingle', 'engine/overworld/healing_machine.asm', 'MUSIC_PKMN_HEALED'),
    ('healing_machine', 'healing_machine', 'sfx', 'engine/overworld/healing_machine.asm', 'SFX_HEALING_MACHINE'),
    ('evolution', 'safari', 'music', 'engine/movie/evolution.asm', 'MUSIC_SAFARI_ZONE'),
    ('tink', 'tink', 'sfx', 'engine/movie/evolution.asm', 'SFX_TINK'),
    ('title', 'title', 'music', 'engine/movie/title.asm', 'MUSIC_TITLE_SCREEN'),
    ('credits', 'credits', 'music', 'engine/movie/credits.asm', 'MUSIC_CREDITS'),
    ('hall_of_fame', 'hall_of_fame', 'music', 'engine/movie/hall_of_fame.asm', 'MUSIC_HALL_OF_FAME'),
    ('surf', 'surfing', 'music', 'home/audio.asm', 'MUSIC_SURFING'),
    ('bicycle', 'bicycle', 'music', 'home/audio.asm', 'MUSIC_BIKE_RIDING'),
    ('meet_male', 'meet_male', 'jingle', 'home/trainers.asm', 'MUSIC_MEET_MALE_TRAINER'),
    ('meet_female', 'meet_female', 'jingle', 'home/trainers.asm', 'MUSIC_MEET_FEMALE_TRAINER'),
    ('meet_evil', 'meet_evil', 'jingle', 'home/trainers.asm', 'MUSIC_MEET_EVIL_TRAINER'),
    ('meet_rival', 'meet_rival', 'jingle', 'scripts/OaksLab.asm', 'MUSIC_MEET_RIVAL'),
    ('meet_oak', 'meet_oak', 'jingle', 'scripts/PalletTown.asm', 'MUSIC_MEET_PROF_OAK'),
    ('defeated_wild', 'defeated_wild', 'music', 'engine/battle/core.asm', 'MUSIC_DEFEATED_WILD_MON'),
    ('defeated_trainer', 'defeated_trainer', 'music', 'engine/battle/core.asm', 'MUSIC_DEFEATED_TRAINER'),
    ('defeated_gym', 'defeated_gym', 'music', 'engine/battle/core.asm', 'MUSIC_DEFEATED_GYM_LEADER'),
    ('menu', 'menu', 'sfx', 'home/joypad2.asm', 'SFX_PRESS_AB'),
    ('text', 'text', 'sfx', 'home/window.asm', 'SFX_PRESS_AB'),
    ('start_menu', 'start_menu', 'sfx', 'home/start_menu.asm', 'SFX_START_MENU'),
    ('hit', 'hit', 'sfx', 'engine/battle/animations.asm', 'SFX_DAMAGE'),
    ('faint', 'faint', 'sfx', 'engine/battle/core.asm', 'SFX_FAINT_THUD'),
    ('go_inside', 'go_inside', 'sfx', 'home/overworld.asm', 'SFX_GO_INSIDE'),
    ('go_outside', 'go_outside', 'sfx', 'home/overworld.asm', 'SFX_GO_OUTSIDE'),
    ('ledge', 'ledge', 'sfx', 'engine/overworld/ledges.asm', 'SFX_LEDGE'),
    ('cut', 'cut', 'sfx', 'engine/overworld/cut.asm', 'SFX_CUT'),
    ('boulder', 'boulder', 'sfx', 'engine/overworld/push_boulder.asm', 'SFX_PUSH_BOULDER'),
    ('pc_on', 'pc_on', 'sfx', 'engine/menus/pc.asm', 'SFX_TURN_ON_PC'),
    ('pc_off', 'pc_off', 'sfx', 'engine/menus/pc.asm', 'SFX_TURN_OFF_PC'),
    ('pc_enter', 'pc_enter', 'sfx', 'engine/menus/pc.asm', 'SFX_ENTER_PC'),
    ('pc_withdraw', 'pc_withdraw', 'sfx', 'engine/menus/players_pc.asm', 'SFX_WITHDRAW_DEPOSIT'),
    ('arrow_tiles', 'arrow_tiles', 'sfx', 'scripts/ViridianGym.asm', 'SFX_ARROW_TILES'),
    ('denied', 'denied', 'sfx', 'scripts/Route22Gate.asm', 'SFX_DENIED'),
    ('flute', 'flute', 'sfx', 'engine/items/item_effects.asm', 'SFX_POKEFLUTE'),
)


def raw_lines(source, path):
    """Pinned text, including rows the audio grammar's IF filter rejects."""
    for number, raw in enumerate(source.read(path).splitlines(), 1):
        code, _, comment = raw.partition(';')
        yield number, code.strip(), comment.strip()


def cite(source, path, token):
    for number, code, comment in raw_lines(source, path):
        if token in code or token in comment:
            return f'{path}:{number}'
    raise AudioError(f'{token} not in {path}')


def _list_until_end(source, path, label):
    rows = []
    started = False
    for line in source.lines(path):
        if line.text.startswith(label):
            started = True
            continue
        if not started:
            continue
        if line.text.startswith('db -1') or line.text == 'db -1':
            break
        match = re.fullmatch(r'db\s+(OPP_[A-Z0-9_]+)', line.text)
        if not match:
            line.fail(f'unsupported {label} row')
        rows.append(match.group(1))
    if not rows:
        raise AudioError(f'{path}: missing {label}')
    return rows


def _species_ids(source):
    ids = {}
    for line in source.lines('constants/pokemon_constants.asm'):
        match = re.fullmatch(r'const\s+([A-Z0-9_]+)', line.text)
        comment = line.comment.split()[0] if line.comment else ''
        if match and re.fullmatch(r'\$[0-9A-Fa-f]+', comment):
            ids[match.group(1)] = int(comment[1:], 16)
    return ids


def _rival_cps(source):
    rows = []
    inside = False
    for _number, text, _comment in raw_lines(source, 'home/trainers.asm'):
        if text.startswith('PlayTrainerMusic'):
            inside = True
            continue
        if not inside:
            continue
        if text.startswith('ld a, [wGymLeaderNo]'):
            break
        match = re.fullmatch(r'cp\s+(OPP_RIVAL[123])', text)
        if match:
            rows.append(match.group(1))
    if rows != ['OPP_RIVAL1', 'OPP_RIVAL2', 'OPP_RIVAL3']:
        raise AudioError(f'PlayTrainerMusic rival returns changed: {rows}')
    return rows


def _script_sites(source, token):
    sites = []
    folder = source.root / 'scripts'
    for path in sorted(folder.glob('*.asm')):
        relative = f'scripts/{path.name}'
        if token not in path.read_text(encoding='utf-8', errors='replace'):
            continue
        sites.append(cite(source, relative, token))
    if not sites:
        raise AudioError(f'no script cites {token}')
    return sites


def build(source_path):
    source = Source(source_path)
    catalog = Catalog(source)
    routes = map_routes(catalog)
    song_at = {}
    for line in source.lines('data/maps/songs.asm'):
        if line.comment:
            song_at.setdefault(line.comment.split()[0], line.location)
    maps = {}
    for row in catalog.maps:
        map_id = 'pokered:' + row['map']
        where = song_at.get(row['map'])
        if not where:
            raise AudioError(f'{row["map"]}: songs.asm line missing')
        maps[map_id] = {
            'score': routes[map_id],
            'asset': row['asset'],
            'source': where,
        }
    species = _species_ids(source)
    legendary = {}
    for name, (path, const) in LEGENDARY.items():
        if const not in species:
            raise AudioError(f'missing species id {const}')
        window = source.read(path)
        if 'PlayCry' not in window or const not in window:
            raise AudioError(f'{path}: static cry for {const} missing')
        legendary[name] = {
            'source': cite(source, path, 'PlayCry'),
            'const': const,
            'id': species[const],
        }
    offset_line = cite(source, 'constants/trainer_constants.asm', 'OPP_ID_OFFSET')
    offset = None
    for line in source.lines('constants/trainer_constants.asm'):
        match = re.search(r'OPP_ID_OFFSET\s+EQU\s+(\d+)', line.text)
        if match:
            offset = int(match.group(1))
    if offset != 200:
        raise AudioError(f'OPP_ID_OFFSET {offset}')
    trainer_names = set()
    for line in source.lines('constants/trainer_constants.asm'):
        match = re.search(r'trainer_const\s+([A-Z0-9_]+)', line.text)
        if match:
            trainer_names.add('OPP_' + match.group(1))
    for name in UNIQUE_GYM:
        if name not in trainer_names:
            raise AudioError(f'{name} is not a trainer class')
    if 'OPP_GIOVANNI' not in trainer_names:
        raise AudioError('OPP_GIOVANNI missing')
    evil = _list_until_end(source, 'data/trainers/encounter_types.asm', 'EvilTrainerList::')
    female = _list_until_end(source, 'data/trainers/encounter_types.asm', 'FemaleTrainerList::')
    cues = {}
    for name, score, kind, path, token in CUES:
        if score not in ASSETS:
            raise AudioError(f'cue {name} uses unknown score {score}')
        cues[name] = {
            'score': score,
            'kind': kind,
            'source': cite(source, path, token),
            'token': token,
        }
    return {
        'revision': source.revision,
        'opp_offset': offset,
        'opp_offset_source': offset_line,
        'maps': maps,
        'aliases': dict(ALIASES),
        'evil': evil,
        'female': female,
        'rival_silent': _rival_cps(source),
        'unique_gym': list(UNIQUE_GYM),
        'giovanni_zone': GIOVANNI_GYM,
        'legendary': legendary,
        'cues': cues,
        'battle_source': cite(source, 'audio/play_battle_music.asm', 'PlayBattleMusic'),
        'jingle_source': cite(source, 'home/trainers.asm', 'PlayTrainerMusic'),
        'victory_source': cite(source, 'engine/battle/core.asm', 'PlayBattleVictoryMusic'),
        'hp_source': cite(source, 'engine/gfx/hp_bar.asm', 'GetHPBarLength'),
        'color_source': cite(source, 'home/palettes.asm', 'GetHealthBarColor'),
        'alarm_source': cite(source, 'engine/battle/core.asm', 'wLowHealthAlarm'),
        'door_source': cite(source, 'home/overworld.asm', 'PlayMapChangeSound'),
        'meet_rival_scripts': _script_sites(source, 'MUSIC_MEET_RIVAL'),
        'meet_oak_scripts': _script_sites(source, 'MUSIC_MEET_PROF_OAK'),
    }


def _lua_string(value):
    return json.dumps(value, ensure_ascii=True)


def emit(data):
    lines = [
        '-- Generated by tools/audio/events.py; do not hand edit.',
        f'-- pret/pokered {data["revision"]}',
        'KantoEvents = {',
        f'  revision = {_lua_string(data["revision"])},',
        f'  oppOffset = {data["opp_offset"]},',
        f'  oppOffsetSource = {_lua_string(data["opp_offset_source"])},',
        f'  battleSource = {_lua_string(data["battle_source"])},',
        f'  jingleSource = {_lua_string(data["jingle_source"])},',
        f'  victorySource = {_lua_string(data["victory_source"])},',
        f'  hpSource = {_lua_string(data["hp_source"])},',
        f'  colorSource = {_lua_string(data["color_source"])},',
        f'  alarmSource = {_lua_string(data["alarm_source"])},',
        f'  doorSource = {_lua_string(data["door_source"])},',
        f'  giovanniZone = {_lua_string(data["giovanni_zone"])},',
        '  maps = {',
    ]
    for map_id, row in sorted(data['maps'].items()):
        lines.append(
            f'    [{_lua_string(map_id)}] = {_lua_string(row["score"])},'
            f' -- {row["source"]} {row["asset"]}'
        )
    lines.append('  },')
    lines.append('  aliases = {')
    for key, value in sorted(data['aliases'].items()):
        lines.append(f'    [{_lua_string(key)}] = {_lua_string(value)},')
    lines.append('  },')
    for field, values in (
        ('evil', data['evil']),
        ('female', data['female']),
        ('rivalSilent', data['rival_silent']),
        ('uniqueGym', data['unique_gym']),
    ):
        lines.append(f'  {field} = {{')
        for name in values:
            lines.append(f'    [{_lua_string(name)}] = true,')
        lines.append('  },')
    lines.append('  legendary = {')
    for name, row in sorted(data['legendary'].items()):
        lines.append(
            f'    [{_lua_string(name)}] = {{id={row["id"]}, const={_lua_string(row["const"])},'
            f' source={_lua_string(row["source"])}}},'
        )
    lines.append('  },')
    lines.append('  cues = {')
    for name, row in sorted(data['cues'].items()):
        lines.append(
            f'    [{_lua_string(name)}] = {{score={_lua_string(row["score"])},'
            f' kind={_lua_string(row["kind"])}, source={_lua_string(row["source"])},'
            f' token={_lua_string(row["token"])}}},'
        )
    lines.append('  },')
    lines.append('  meetRivalScripts = {')
    for site in data['meet_rival_scripts']:
        lines.append(f'    {_lua_string(site)},')
    lines.append('  },')
    lines.append('  meetOakScripts = {')
    for site in data['meet_oak_scripts']:
        lines.append(f'    {_lua_string(site)},')
    lines.append('  },')
    lines.append('}')
    lines.append('')
    return '\n'.join(lines).encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.source:
        parser.error('--source or POKERED_REFERENCE_DIR required')
    payload = emit(build(args.source))
    target = ROOT / 'Source/audio/events.lua'
    if args.check:
        if not target.exists() or target.read_bytes() != payload:
            raise AudioError('Source/audio/events.lua differs; regenerate')
        print('audio events: reproducible')
    else:
        target.write_bytes(payload)
        print('audio events: generated')


if __name__ == '__main__':
    main()
