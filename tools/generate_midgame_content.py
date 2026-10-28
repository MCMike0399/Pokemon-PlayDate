#!/usr/bin/env python3
"""Prepare pinned Blue midgame packages; never activate maps or launch Simulator."""
import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_kanto_maps import Reference, REVISION, decode_map, records, integer
from tools.generate_viridian_slice import sprite_data
from tools.generate_cerulean_content import (canonical, digest, species, envelope,
    blue_source, direct_labels, trainer_tables, sprite_sources, item_ids, verify)
from tools.generate_vermilion_preparation import sections, text_recipes
from tools.generate_source_map_cache import build as cache_build

PACKETS = {
    'east': (
        'Route9', 'Route10', 'RockTunnelPokecenter', 'RockTunnel1F', 'RockTunnelB1F',
        'LavenderTown', 'LavenderPokecenter', 'LavenderMart', 'LavenderCuboneHouse',
        'NameRatersHouse', 'MrFujisHouse', 'Route8', 'Route8Gate', 'UndergroundPathRoute8',
        'UndergroundPathWestEast', 'UndergroundPathRoute7', 'Route7', 'Route7Gate',
        'CeladonCity', 'CeladonPokecenter', 'CeladonGym', 'CeladonDiner', 'CeladonHotel',
        'CeladonChiefHouse', 'CeladonMansion1F', 'CeladonMansion2F', 'CeladonMansion3F',
        'CeladonMansionRoof', 'CeladonMansionRoofHouse', 'CeladonMart1F', 'CeladonMart2F',
        'CeladonMart3F', 'CeladonMart4F', 'CeladonMart5F', 'CeladonMartRoof',
        'CeladonMartElevator', 'GameCorner', 'GameCornerPrizeRoom',
        'RocketHideoutB1F', 'RocketHideoutB2F', 'RocketHideoutB3F', 'RocketHideoutB4F',
        'RocketHideoutElevator',
    ),
    'south': tuple('PokemonTower' + str(i) + 'F' for i in range(1, 8)) + (
        'Route12', 'Route12Gate1F', 'Route12Gate2F', 'Route12SuperRodHouse',
        'Route13', 'Route14', 'Route15', 'Route15Gate1F', 'Route15Gate2F',
        'Route16', 'Route16Gate1F', 'Route16Gate2F', 'Route16FlyHouse',
        'Route17', 'Route18', 'Route18Gate1F', 'Route18Gate2F',
        'FuchsiaCity', 'FuchsiaPokecenter', 'FuchsiaMart', 'FuchsiaGym',
        'FuchsiaBillsGrandpasHouse', 'FuchsiaGoodRodHouse', 'FuchsiaMeetingRoom',
        'WardensHouse', 'SafariZoneGate', 'SafariZoneCenter', 'SafariZoneEast',
        'SafariZoneNorth', 'SafariZoneWest', 'SafariZoneSecretHouse',
        'SafariZoneCenterRestHouse', 'SafariZoneEastRestHouse',
        'SafariZoneNorthRestHouse', 'SafariZoneWestRestHouse',
    ),
    'saffron': (
        'SaffronCity', 'SaffronPokecenter', 'SaffronMart', 'SaffronGym', 'FightingDojo',
        'SaffronPidgeyHouse', 'MrPsychicsHouse', 'CopycatsHouse1F', 'CopycatsHouse2F',
    ) + tuple('SilphCo' + str(i) + 'F' for i in range(1, 12)) + ('SilphCoElevator',),
}
# Reserve the complete primary interaction, even if it contains a usable text_far.
RESERVED = {
    'CeladonGym': {1: 'Erika/Rainbow Badge/TM21; story worker'},
    'NameRatersHouse': {1: 'name rater service; service worker'},
    'MrFujisHouse': {5: 'Fuji rescue/Poke Flute; story worker'},
    'Route7Gate': {1: 'SaffronGuards existing package; root activates Route7/8'},
    'Route8Gate': {1: 'SaffronGuards existing package; root activates Route7/8'},
    'Route18Gate2F': {1: 'NPCTrades existing MARC exchange; root activates actor'},
    'CeladonMansionRoofHouse': {2: 'Eevee gift; story worker'},
    'PokemonTower2F': {1: 'starter-dependent rival; story worker'},
    'PokemonTower7F': {4: 'Fuji rescue and return warp; story worker'},
    'Route12': {1: 'Snorlax/Poke Flute/static battle; field worker'},
    'Route16': {1: 'Snorlax/Poke Flute/static battle; field worker'},
    'FuchsiaGym': {1: 'Koga/Soul Badge/TM06; story worker'},
    'SaffronGym': {1: 'Sabrina/Marsh Badge/TM46; story worker'},
    'FightingDojo': {1: 'master and choice unlock; story worker',
        6: 'Hitmonlee choice; story worker', 7: 'Hitmonchan choice; story worker'},
    'SilphCo7F': {1: 'Lapras gift; story worker'},
}
SUPPLEMENTAL = (
    'data/items/marts.asm', 'data/events/hidden_events.asm',
    'data/events/hidden_item_coords.asm', 'data/maps/toggleable_objects.asm',
    'constants/event_constants.asm', 'constants/toggle_constants.asm',
    'engine/events/oaks_aide.asm', 'engine/events/pokecenter.asm',
    'engine/events/in_game_trades.asm', 'data/events/trades.asm',
    'home/overworld_text.asm', 'scripts/PewterCity.asm', 'scripts/ViridianCity.asm',
)


def package(packet):
    return 'midgame' + packet.capitalize()


def pin_path(packet):
    return ROOT / 'tools/references' / ('midgame-' + packet + '.json')


def output_path(packet):
    return ROOT / 'Source/data' / package(packet)


def primary_labels(body):
    # Match only a side-effect-free PrintText wrapper; all other ASM is reserved.
    clean = '\n'.join(line.split(';', 1)[0].strip() for line in body.splitlines()
                      if line.split(';', 1)[0].strip())
    wrapper = re.fullmatch(r'text_asm\nld hl, \.Text\ncall PrintText\njp TextScriptEnd\n\.Text:\n(.*)', clean, re.S)
    clean = wrapper[1] if wrapper else clean
    if re.search(r'\bsound_', clean):
        return None
    return direct_labels(clean)


def proposal(artifacts, packet, base=None):
    manifest = json.loads(canonical(base)) if base else json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    additions = json.loads(artifacts['manifest-entries.json'])['maps']
    for name, entry in additions.items():
        if name in manifest['maps']:
            for key, value in entry.items():
                if manifest['maps'][name].get(key) != value:
                    raise ValueError('installed midgame entry drift: ' + name + ':' + key)
        else:
            manifest['maps'][name] = entry
    raw = canonical(manifest)
    with tempfile.TemporaryDirectory(prefix='midgame-cache-') as temp:
        stage = Path(temp)
        manifest_path = stage / 'manifest.json'
        manifest_path.write_bytes(raw)
        source = stage / 'Source'
        for name, entry in manifest['maps'].items():
            target = source / entry['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(artifacts[name + '.json'] if name in additions
                              else (ROOT / 'Source' / entry['path']).read_bytes())
        cache = cache_build(manifest_path, source)
    return {'proposed-source-maps.json': raw,
            **{'proposed-' + name: canonical(json.loads(data)) for name, data in cache.items()}}


def build(reference_root, packet, pins=None):
    names = PACKETS[packet]
    if pins is None:
        pin = json.loads(pin_path(packet).read_bytes())
        if pin['revision'] != REVISION or pin['maps'] != list(names):
            raise ValueError('midgame source pin revision/inventory drift')
        pins = pin['files']
    ref = Reference(reference_root, pins)
    definitions = {name: decode_map(ref, name) for name in names}
    songs = records(ref.text('data/maps/songs.asm'), 'db')
    for d in definitions.values():
        symbol, bank = songs[d['source_map_id']]['args']
        if not re.fullmatch(r'MUSIC_\w+', symbol) or not re.fullmatch(r'BANK\(Music_\w+\)', bank):
            raise ValueError('unresolved source music')
        d['music'] = dict(symbol=symbol, audio_bank=bank,
            source='data/maps/songs.asm', source_line=songs[d['source_map_id']]['line'])
    tables, sprite_names, item_map = trainer_tables(ref), sprite_sources(ref), item_ids(ref)
    scripts = {path: ref.text(path) for path in SUPPLEMENTAL}
    texts = {}
    # Manifest explicitly fixes the actual text inventory, including *_2 continuations.
    for path in sorted(pins):
        if (path.startswith('text/') and any(Path(path).stem == name or
                Path(path).stem.startswith(name + '_') for name in names)) or re.fullmatch(r'data/text/text_[1-4]\.asm', path):
            for label, recipe in text_recipes(blue_source(ref.text(path))).items():
                if label in texts:
                    raise ValueError('duplicate source text: ' + label)
                texts[label] = dict(source=path, recipe=recipe)
    for name in names:
        path = 'scripts/' + name + '.asm'
        scripts[path] = blue_source(ref.text(path))
    all_sections = {}
    for script in scripts.values():
        all_sections.update(sections(script))
    marts = sections(scripts['data/items/marts.asm'])
    trainers, sprites, events, signs, gaps, pointer_index = {}, {}, {}, {}, [], {}
    for name, d in definitions.items():
        script = scripts['scripts/' + name + '.asm']
        pointers = {r['args'][1]: r['args'][0] for r in records(script, 'dw_const')
                    if len(r['args']) == 2 and r['args'][1].startswith('TEXT_')}
        pointer_index[name] = pointers
        bodies = sections(script)
        headers = {label: records(body, 'trainer')[0]['args'] for label, body in bodies.items()
                   if records(body, 'trainer')}
        for section in ('grass', 'water'):
            for slot in d['encounters'][section]['slots']:
                slot['species'] = species(slot['species_source'])
        for event in d['events']['objects']:
            source = event['sprite']
            if source not in sprites:
                sprites[source] = sprite_data(ref, sprite_names[source])
            pointer = pointers[event['text_id']]
            body = bodies.get(pointer, '')
            ordinary = primary_labels(body)
            reason = RESERVED.get(name, {}).get(event['source_index'])
            descriptor = None
            if event['kind'] == 'trainer_or_static_pokemon':
                cls, roster = event['extra']
                if cls not in tables:
                    reason = reason or 'static Pokemon encounter; field/story worker'
                else:
                    roster = integer(roster)
                    table = tables[cls]
                    row = table['parties'][roster - 1]
                    match = re.search(r'ld hl, (\w+TrainerHeader\d+)', body)
                    header = headers.get(match[1]) if match else None
                    trainers[event['id']] = dict(id=event['id'], map_id=d['id'], name=table['name'],
                        class_source=cls, roster_id=roster, party=row['party'],
                        base_money=table['base_money'], payout=table['base_money'] * row['party'][-1]['level'],
                        money_source_bcd3=table['money_source_bcd3'], sprite_source=source,
                        sight_range_cells=integer(header[1]) if header else 0,
                        source_flag=header[0] if header else None,
                        source_object_index=event['source_index'], x=event['x'], y=event['y'],
                        facing_source=event['range_or_facing'], talk_only=not bool(header),
                        source={'objects': 'data/maps/objects/' + name + '.asm',
                                'script': 'scripts/' + name + '.asm', 'parties': 'data/trainers/parties.asm'})
                    if header and not reason:
                        labels = [primary_labels(bodies[label]) for label in header[2:]]
                        if any(not group for group in labels):
                            reason = 'trainer text contains source controls; story worker'
                        else:
                            descriptor = dict(kind='trainer', before=labels[0], won=labels[1], after=labels[2])
                    else:
                        reason = reason or 'scripted trainer/reward; story worker'
            elif event['kind'] == 'item':
                descriptor = dict(kind='pickup', item=item_map[event['extra'][0]],
                    flag='PICKUP:' + event['id'], success=['_FoundItemText'], full=['_NoMoreRoomForItemText'])
            elif pointer in marts and records(marts[pointer], 'script_mart'):
                descriptor = dict(kind='program', steps=[dict(op='shop', id=pointer[0].lower() + pointer[1:])])
            elif 'script_pokecenter_nurse' in body:
                ingress = [(outer, w) for outer, outside in definitions.items()
                           for w in outside['events']['warps']
                           if w['destination'].get('map') == d['source_map_constant']]
                if len(ingress) != 1:
                    raise ValueError('ambiguous source Center ingress: ' + name)
                outer, warp = ingress[0]
                descriptor = dict(kind='program', steps=[dict(op='heal', id=name,
                    nurse_id=event['id'], welcome='_PokemonCenterWelcomeText', prompt='_ShallWeHealYourPokemonText',
                    before='_NeedYourPokemonText', after='_PokemonFightingFitText', farewell='_PokemonCenterFarewellText',
                    checkpoint=dict(zone_id=definitions[outer]['id'], x=warp['x'], y=warp['y'] + 1, facing='down'))])
            elif ordinary and not reason:
                descriptor = dict(kind='program', steps=[dict(op='dialog', labels=ordinary)])
            if descriptor and not reason:
                events[event['id']] = dict(content=package(packet), **descriptor)
            else:
                gaps.append(dict(id=event['id'], map=name, pointer=pointer,
                    reason=reason or 'source control/service requires explicit descriptor or bespoke owner'))
        for event in d['events']['background_events']:
            pointer = pointers[event['text_id']]
            labels = primary_labels(all_sections.get(pointer, ''))
            if labels:
                signs[event['id']] = dict(content=package(packet), kind='program', steps=[dict(op='dialog', labels=labels)])
            else:
                gaps.append(dict(id=event['id'], map=name, pointer=pointer, reason='conditional sign/service; story/service worker'))
    # Never ship the raw ASM. Workers materialize exact pinned files outside Git.
    hidden, current = [], None
    for line in scripts['data/events/hidden_events.asm'].splitlines():
        rows = records(line, 'hidden_events_for')
        if rows:
            current = rows[0]['args'][0]
        rows = records(line, 'hidden_event')
        if rows and current in {d['source_map_constant'] for d in definitions.values()}:
            x, y, function, argument = rows[0]['args']
            hidden.append(dict(map_id='pokered:' + current, x=integer(x), y=integer(y), function=function, argument=argument))
    reservations = []
    for gap in gaps:
        body = sections(scripts['scripts/' + gap['map'] + '.asm']).get(gap['pointer'], '')
        reservations.append(dict(gap, source='scripts/' + gap['map'] + '.asm',
            text_labels=re.findall(r'text_far (\w+)', body),
            source_flags=sorted(set(re.findall(r'\b(?:EVENT_|BIT_)\w+', body))),
            roster=gap['id'] if gap['id'] in trainers else None))
    output = {name + '.json': canonical(d) for name, d in definitions.items()}
    output.update({
        'dialogue.json': canonical(envelope(texts=texts)),
        'sprites.json': canonical(envelope(sprites=sprites)),
        'trainers.json': canonical(envelope(trainers=trainers, rival_classes={
            name: tables[name] for name in ('OPP_RIVAL1', 'OPP_RIVAL2', 'OPP_GIOVANNI')})),
        'events.json': canonical(envelope(events=events, signs=signs)),
        'scripts.json': canonical(envelope(text_pointers=pointer_index, hidden_events=hidden,
            sources={path: digest(ref.bytes(path)) for path in scripts}, gaps=gaps)),
        'reservations.json': canonical(envelope(reservations=reservations,
            policy='Reserved IDs are not registered. Source programs remain outside Git; materialize pinned inputs.')),
    })
    entries = {}
    for name, d in definitions.items():
        width, height = d['dimensions']['cells']
        padding = max(0, (13 - width) // 2)
        occupied = {(e['x'], e['y']) for group in d['events'].values() for e in group}
        candidates = [(x, y) for y, row in enumerate(d['collision']) for x, solid in enumerate(row)
                      if not solid and (x, y) not in occupied]
        x, y = min(candidates, key=lambda p: (height - 1 - p[1], abs(width // 2 - p[0])))
        entries[name] = dict(id=d['id'], key='kanto_' + d['source_map_constant'].lower(),
            path='data/' + package(packet) + '/' + name + '.json', profile='source',
            width=max(13, width), height=height, padding=padding,
            source_sha256=digest(output[name + '.json']), spawn=dict(x=x + padding, y=y, facing='up'))
    output['manifest-entries.json'] = canonical(envelope(maps=entries))
    output['contexts.json'] = canonical(envelope(maps={name: dict(
        id=d['id'], runtime_key=entries[name]['key'], padding=entries[name]['padding'],
        connections=d['connections'], warps=d['events']['warps'],
        actors=[dict(id=e['id'], pointer=pointer_index[name][e['text_id']],
                     source_x=e['x'], source_y=e['y'],
                     runtime_x=e['x'] + entries[name]['padding'], runtime_y=e['y'],
                     reserved=next((r['reason'] for r in reservations if r['id'] == e['id']), None))
                for e in d['events']['objects']]) for name, d in definitions.items()}))
    output.update(proposal(output, packet))
    # Verify every descriptor text reference exists before publishing a package.
    def labels(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key in ('labels', 'before', 'won', 'after', 'success', 'full') and isinstance(child, list):
                    yield from child
                elif key in ('welcome', 'prompt', 'before', 'after', 'farewell') and isinstance(child, str) and child.startswith('_'):
                    yield child
                else:
                    yield from labels(child)
        elif isinstance(value, list):
            for child in value:
                yield from labels(child)
    missing = set(labels([events, signs])) - set(texts)
    if missing:
        raise ValueError('missing descriptor text: ' + repr(sorted(missing)))
    output['provenance.json'] = canonical(envelope(maps=list(names), version='English Blue',
        source_files=ref.consumed, generator_sha256=digest(Path(__file__).read_bytes()),
        shared_generators={path: digest((ROOT / path).read_bytes()) for path in (
            'tools/generate_kanto_maps.py', 'tools/generate_cerulean_content.py',
            'tools/generate_vermilion_preparation.py', 'tools/generate_viridian_slice.py',
            'tools/generate_source_map_cache.py')},
        render_contract=dict(terrain='approved global imported tone mapping, fixed phase (0,0)',
            sprites='existing immutable source strip resolver; protected standing BLUE unchanged'),
        artifacts={name: digest(data) for name, data in output.items()},
        status='candidate only; root activation and native acceptance pending'))
    return output, ref.consumed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--packet', choices=PACKETS, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts, consumed = build(args.reference, args.packet)
    output = args.output or output_path(args.packet)
    if args.check:
        verify(artifacts, output)
    else:
        output.mkdir(parents=True, exist_ok=False)
        for name, data in artifacts.items():
            (output / name).write_bytes(data)
    print(f'Verified {len(PACKETS[args.packet])} {args.packet} maps, {len(consumed)} pinned inputs; inactive candidate')

if __name__ == '__main__':
    main()
