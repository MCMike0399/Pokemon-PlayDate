#!/usr/bin/env python3
"""Prepare immutable Blue Vermilion data using the existing shared pipeline.

No active inventory writes, new provider, ASM execution, network or Simulator.
"""
import argparse
import json
import re
import sys
import tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.generate_kanto_maps import Reference, REVISION, decode_map, records, integer
from tools.generate_viridian_slice import sprite_data
from tools.generate_source_map_cache import build as cache_build
from tools.generate_cerulean_content import (canonical, digest, species, envelope,
    blue_source, direct_labels, conditional,
    trainer_tables, sprite_sources, item_ids, verify)
ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / 'tools/references/vermilion-preparation.json'
OUTPUT = ROOT / 'Source/data/vermilionPreparation'
MAPS = (
    'Route5', 'Route5Gate', 'UndergroundPathRoute5', 'UndergroundPathNorthSouth',
    'UndergroundPathRoute6', 'Route6', 'Route6Gate', 'Daycare',
    'VermilionCity', 'VermilionPokecenter', 'VermilionMart', 'PokemonFanClub',
    'VermilionOldRodHouse', 'VermilionPidgeyHouse', 'VermilionTradeHouse',
    'VermilionDock', 'VermilionGym', 'SSAnne1F', 'SSAnne2F', 'SSAnne3F',
    'SSAnneB1F', 'SSAnneBow', 'SSAnneKitchen', 'SSAnneCaptainsRoom',
    'SSAnne1FRooms', 'SSAnne2FRooms', 'SSAnneB1FRooms', 'DiglettsCave',
    'DiglettsCaveRoute2', 'DiglettsCaveRoute11', 'Route2Gate', 'Route2TradeHouse',
    'Route11', 'Route11Gate1F', 'Route11Gate2F',
)
NO_LOCAL_TEXT = ('Route5Gate', 'UndergroundPathRoute5', 'UndergroundPathNorthSouth', 'Route6Gate', 'VermilionTradeHouse', 'SSAnneB1F', 'DiglettsCave')
BESPOKE = {
    'SSAnne2F': {2: 'rival approach, starter-dependent roster and departure; scene worker'},
    'SSAnneCaptainsRoom': {1: 'Captain/HM01 and ship departure; scene worker'},
    'VermilionCity': {3: 'boarding/Ticket/ship departure guard; scene worker'},
    'VermilionGym': {1: 'Surge/Thunder Badge/TM24 and trash switches; scene worker'},
    'PokemonFanClub': {5: 'Bike Voucher choice, bag retry and EVENT_GOT_BIKE_VOUCHER; next ordinary quest packet'},
    'VermilionOldRodHouse': {1: 'Old Rod choice, bag retry and wStatusFlags1.BIT_GOT_OLD_ROD; next ordinary quest packet'},
    'Route2Gate': {1: 'HM05 aide, 10 owned species and bag retry; next ordinary quest packet'},
    'Route11Gate2F': {2: 'Itemfinder aide, 30 owned species and bag retry; next ordinary quest packet'},
    'Daycare': {1: 'deposit/withdraw, party ownership, growth and payment; next service packet'},
}

def sections(text):
    """Every column-zero global label (private/exported) ends the prior body.

    Inline comments do not turn labels into unbounded continuations. Local
    labels remain within their owner and are never independent source programs.
    """
    matches = list(re.finditer(r'^(\w+)::?[ \t]*(?:;[^\n]*)?$', text, re.M))
    return {m[1]: text[m.end():matches[i + 1].start() if i + 1 < len(matches) else len(text)]
            for i, m in enumerate(matches)}


def text_recipes(text):
    # Non-underscore text globals (the chef's courses) are real resources too.
    result, label = {}, None
    for number, line in enumerate(text.splitlines(), 1):
        clean = line.split(';', 1)[0].strip()
        found = re.fullmatch(r'(\w+)::?[ \t]*', line.split(';', 1)[0].rstrip())
        if found:
            label = found[1]
            result[label] = []
            continue
        if not label or not clean:
            continue
        match = re.fullmatch(r'(text|line|cont|para|next)\s+"(.*)"', clean)
        if match:
            row = dict(op=match[1], text=match[2], source_line=number)
        elif clean.startswith('text_ram '):
            row = dict(op='text_ram', symbol=clean.split()[1], source_line=number)
        else:
            row = dict(op='control', source=clean, source_line=number)
        result[label].append(row)
    return result


def proposed_pipeline(artifacts):
    """Existing manifest + new entries through the existing cache generator."""
    active = ROOT / 'Source/data/sourceMaps.json'
    manifest = json.loads(active.read_bytes())
    additions = json.loads(artifacts['manifest-entries.json'])['maps']
    if set(manifest['maps']) & set(additions):
        raise ValueError('preparation overlaps active maps')
    manifest['maps'].update(additions)
    raw = canonical(manifest)
    with tempfile.TemporaryDirectory(prefix='vermilion-cache-') as temporary:
        stage = Path(temporary)
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


def build(reference_root):
    pin = json.loads(PIN.read_bytes())
    if pin['revision'] != REVISION or tuple(pin['maps']) != MAPS:
        raise ValueError('Vermilion preparation pin revision/inventory differs')
    ref = Reference(reference_root, pin['files'])
    definitions = {name: decode_map(ref, name, **({'linked_layout_tail': ('maps/UndergroundPathWestEast.blk', 4)} if name == 'UndergroundPathNorthSouth' else {})) for name in MAPS}
    songs = records(ref.text('data/maps/songs.asm'), 'db')
    for definition in definitions.values():
        song = songs[definition['source_map_id']]
        symbol, bank = song['args']
        if not re.fullmatch(r'MUSIC_\w+', symbol) or not re.fullmatch(r'BANK\(Music_\w+\)', bank):
            raise ValueError('unresolved source map music')
        definition['music'] = dict(symbol=symbol, audio_bank=bank,
                                   source='data/maps/songs.asm', source_line=song['line'])
    tables = trainer_tables(ref)
    sprite_names = sprite_sources(ref)
    item_map = item_ids(ref)
    scripts, texts, trainers, events, signs, gaps = {}, {}, {}, {}, {}, []
    supplemental = ['data/items/marts.asm', 'engine/events/oaks_aide.asm', 'data/events/trades.asm', 'engine/events/in_game_trades.asm',
                    'engine/events/pokecenter.asm', 'data/events/hidden_item_coords.asm',
                    'data/maps/toggleable_objects.asm', 'home/overworld_text.asm']
    for path in supplemental:
        scripts[path] = ref.text(path)
    text_paths = [f'text/{name}.asm' for name in MAPS if name not in NO_LOCAL_TEXT]
    text_paths += ['text/Daycare_2.asm', 'text/Route11_2.asm', 'text/VermilionGym_2.asm']
    text_paths += ['data/text/text_1.asm', 'data/text/text_2.asm', 'data/text/text_3.asm', 'data/text/text_4.asm']
    for path in text_paths:
        for label, recipe in text_recipes(blue_source(ref.text(path))).items():
            if label in texts:
                raise ValueError('duplicate text label: ' + label)
            texts[label] = dict(source=path, recipe=recipe)
    # These shared source bodies own sign pointers not present in map scripts.
    for path in ['scripts/PewterCity.asm', 'scripts/ViridianCity.asm']:
        scripts[path] = ref.text(path)
    all_sections = {}
    for name in MAPS:
        path = f'scripts/{name}.asm'
        scripts[path] = ref.text(path)
        all_sections.update(sections(scripts[path]))
    for path in ['scripts/PewterCity.asm', 'scripts/ViridianCity.asm', 'home/overworld_text.asm']:
        all_sections.update(sections(scripts[path]))
    sprites = {}
    pointer_index = {}
    for name, d in definitions.items():
        script = scripts[f'scripts/{name}.asm']
        pointers = {r['args'][1]: r['args'][0] for r in records(script, 'dw_const')
                    if len(r['args']) == 2 and r['args'][1].startswith('TEXT_')}
        pointer_index[name] = pointers
        bodies = sections(script)
        headers = {}
        for label, body in bodies.items():
            rows = records(body, 'trainer')
            if rows:
                if len(rows) != 1 or len(rows[0]['args']) != 5:
                    raise ValueError('invalid trainer header')
                headers[label] = rows[0]['args']
        for section in ('grass', 'water'):
            for slot in d['encounters'][section]['slots']:
                slot['species'] = species(slot['species_source'])
        for event in d['events']['objects']:
            source = event['sprite']
            if source not in sprites:
                sprites[source] = sprite_data(ref, sprite_names[source])
            pointer = pointers[event['text_id']]
            body = bodies.get(pointer, '')
            ordinary = direct_labels(body)
            # This exact wrapper only prints one local text body. It has no
            # conditions or side effects; reject any broader assembly shape.
            clean = '\n'.join(line.split(';', 1)[0].strip() for line in body.splitlines() if line.split(';', 1)[0].strip())
            wrapper = re.fullmatch(r'text_asm\nld hl, \.Text\ncall PrintText\njp TextScriptEnd\n\.Text:\n(.*)', clean, re.S)
            if wrapper:
                ordinary = direct_labels(wrapper[1])
            reason = BESPOKE.get(name, {}).get(event['source_index'])
            descriptor = None
            if event['kind'] == 'trainer_or_static_pokemon':
                cls, roster = event['extra']
                roster = integer(roster)
                table = tables[cls]
                row = table['parties'][roster - 1]
                header_match = re.search(r'ld hl, (\w+TrainerHeader\d+)', body)
                header = headers.get(header_match[1]) if header_match else None
                trainer = dict(id=event['id'], map_id=d['id'], name=table['name'],
                               class_source=cls, roster_id=roster, party=row['party'],
                               base_money=table['base_money'], payout=table['base_money'] * row['party'][-1]['level'],
                               money_source_bcd3=table['money_source_bcd3'], sprite_source=source,
                               sight_range_cells=integer(header[1]) if header else 0,
                               source_flag=header[0] if header else None,
                               source_object_index=event['source_index'], x=event['x'], y=event['y'],
                               facing_source=event['range_or_facing'], talk_only=not bool(header),
                               source={'objects': f'data/maps/objects/{name}.asm',
                                       'script': f'scripts/{name}.asm', 'parties': 'data/trainers/parties.asm'})
                trainers[event['id']] = trainer
                if header and not reason:
                    labels = [direct_labels(bodies[label]) for label in header[2:]]
                    if any(not labels for labels in labels):
                        raise ValueError('trainer text requires bespoke handling')
                    descriptor = dict(kind='trainer', before=labels[0], won=labels[1], after=labels[2])
                elif not reason:
                    reason = 'scripted trainer battle/reward requires explicit planner'
            elif event['kind'] == 'item':
                descriptor = dict(kind='pickup', item=item_map[event['extra'][0]],
                                  flag='PICKUP:' + event['id'], success=['_FoundItemText'], full=['_NoMoreRoomForItemText'])
            elif pointer == 'VermilionMartClerkText':
                descriptor = dict(kind='program', steps=[dict(op='shop', id='vermilionMartClerkText')])
            elif pointer == 'VermilionGymGymGuideText':
                descriptor = conditional('EVENT_BEAT_LT_SURGE', '_VermilionGymGymGuideBeatLTSurgeText', '_VermilionGymGymGuideChampInMakingText')
            elif ordinary and not reason:
                descriptor = dict(kind='program', steps=[dict(op='dialog', labels=ordinary)])
            elif 'script_pokecenter_nurse' in body:
                # Checkpoint must be selected from source outside ingress, not
                # inferred from a floor tile or generic Viridian fallback.
                outer = 'VermilionCity'
                ingress = next(w for w in definitions[outer]['events']['warps']
                               if w['destination'].get('map') == d['source_map_constant'])
                descriptor = dict(kind='program', steps=[dict(op='heal', id=name,
                    nurse_id=event['id'], welcome='_PokemonCenterWelcomeText', prompt='_ShallWeHealYourPokemonText',
                    before='_NeedYourPokemonText', after='_PokemonFightingFitText', farewell='_PokemonCenterFarewellText',
                    checkpoint=dict(zone_id=definitions[outer]['id'], x=ingress['x'], y=ingress['y'] + 1, facing='down'))])
            if descriptor and not reason:
                events[event['id']] = dict(content='vermilion', **descriptor)
            else:
                gaps.append(dict(id=event['id'], map=name, pointer=pointer,
                                 reason=reason or 'source control requires explicit planner'))
        for event in d['events']['background_events']:
            pointer = pointers[event['text_id']]
            labels = direct_labels(all_sections.get(pointer, ''))
            if labels:
                signs[event['id']] = dict(content='vermilion', kind='program', steps=[dict(op='dialog', labels=labels)])
            else:
                gaps.append(dict(id=event['id'], map=name, pointer=pointer, reason='conditional sign text'))
    hidden = []
    current = None
    for line in ref.text('data/events/hidden_events.asm').splitlines():
        rows = records(line, 'hidden_events_for')
        if rows:
            current = rows[0]['args'][0]
        rows = records(line, 'hidden_event')
        if rows and current in {d['source_map_constant'] for d in definitions.values()}:
            x, y, function, argument = rows[0]['args']
            hidden.append(dict(map_id='pokered:' + current, x=integer(x), y=integer(y), function=function, argument=argument))
    # Keep dynamic rival rosters intact for the scene worker, without choosing a
    # starter branch here or registering two overlapping actors as ordinary NPCs.
    rival_parties = {name: tables[name] for name in ('OPP_RIVAL1', 'OPP_RIVAL2')}
    output = {name + '.json': canonical(d) for name, d in definitions.items()}
    output.update({
        # SDK JSON decodes \u00xx escapes as single bytes. Dialogue must be
        # literal UTF-8, including the shared payout's yen and source accents.
        'dialogue.json': (json.dumps(envelope(texts=texts), ensure_ascii=False,
                                    sort_keys=True, separators=(',', ':')) + '\n').encode(),
        'sprites.json': canonical(envelope(sprites=sprites)),
        'trainers.json': canonical(envelope(trainers=trainers, rival_classes=rival_parties)),
        'events.json': canonical(envelope(events=events, signs=signs)),
        'scripts.json': canonical(envelope(scripts=scripts, text_pointers=pointer_index, hidden_events=hidden, gaps=gaps)),
    })
    entries = {}
    for name, definition in definitions.items():
        width, height = definition['dimensions']['cells']
        padding = max(0, (13 - width) // 2)
        occupied = {(e['x'], e['y']) for group in definition['events'].values() for e in group}
        candidates = [(x, y) for y, row in enumerate(definition['collision']) for x, solid in enumerate(row)
                      if not solid and (x, y) not in occupied]
        x, y = min(candidates, key=lambda p: (height - 1 - p[1], abs(width // 2 - p[0])))
        entries[name] = dict(id=definition['id'], key='kanto_' + definition['source_map_constant'].lower(),
            path=f'data/vermilionPreparation/{name}.json', profile='source', width=max(13, width), height=height,
            padding=padding, source_sha256=digest(output[name + '.json']), spawn=dict(x=x + padding, y=y, facing='up'))
    output['manifest-entries.json'] = canonical(envelope(maps=entries))
    reservations = []
    for gap in gaps:
        body = sections(scripts['scripts/' + gap['map'] + '.asm']).get(gap['pointer'], '')
        reservations.append(dict(gap, text_labels=re.findall(r'text_far (\w+)', body),
            source_flags=sorted(set(re.findall(r'\b(?:EVENT_|BIT_)\w+', body))),
            roster=gap['id'] if gap['id'] in trainers else None))
    output['reservations.json'] = canonical(envelope(reservations=reservations,
        shared_aide_text=[key for key in texts if 'Aide' in key],
        rival_scene=dict(id='pokered:SS_ANNE_2F:objects:2', class_source='OPP_RIVAL2',
            roster_ids=[1, 2, 3], object_roster_is_placeholder=True,
            selector_source='scripts/SSAnne2F.asm:SSAnne2FRivalStartBattleScript'),
        policy='Reserved IDs are not registered or completed; exact source programs/text/rosters retained for root/next packet.'))
    output['packages.json'] = canonical(envelope(packages=[
        dict(id='cerulean', root='data/sourceSlice/'),
        dict(id='vermilion', root='data/vermilionPreparation/')],
        actor_profile='source', actor_owner='CeruleanContent',
        policy='One source resolver; extend immutable package lookup, never register an overlapping profile.'))
    output.update(proposed_pipeline(output))
    output['provenance.json'] = canonical(envelope(
        maps=list(MAPS), version='English Blue', source_files=ref.consumed,
        generator_sha256=digest(Path(__file__).read_bytes()),
        shared_generators={path: digest((ROOT / path).read_bytes()) for path in ('tools/generate_kanto_maps.py', 'tools/generate_cerulean_content.py', 'tools/generate_viridian_slice.py', 'tools/generate_source_map_cache.py')},
        render_contract=dict(pattern_phase=[0, 0], sprite_converter='generate_viridian_slice.sprite_data',
                             terrain_converter='generate_kanto_maps.decode_map', alpha='existing SpriteFactory border flood-fill'),
        artifacts={name: digest(data) for name, data in output.items()},
        status='decoded content candidate; no Simulator, visual or campaign acceptance'))
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    if args.check:
        verify(artifacts, args.output)
    else:
        args.output.mkdir(parents=True, exist_ok=False)
        for name, data in artifacts.items():
            (args.output / name).write_bytes(data)
    print(f'Verified {len(MAPS)} preparation maps; no active manifest changed')

if __name__ == '__main__':
    main()
