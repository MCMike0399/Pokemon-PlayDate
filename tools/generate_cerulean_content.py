#!/usr/bin/env python3
"""Decode the next Blue content batch through the shared source-map pipeline.

Only declarative assembler records are decoded. Source programs are indexed,
never executed or inferred to be campaign-ready. No network or runtime launch.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.generate_kanto_maps import Reference, REVISION, decode_map, records, integer
from tools.generate_viridian_slice import sprite_data, text_recipes
from tools.generate_source_map_cache import canonical

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / 'tools/references/cerulean-content.json'
OUTPUT = ROOT / 'Source/data/sourceSlice'
MAPS = (
    'Route22', 'Route3', 'MtMoon1F', 'MtMoonB1F', 'MtMoonB2F', 'Route4',
    'MtMoonPokecenter', 'CeruleanCity', 'CeruleanGym', 'CeruleanPokecenter',
    'CeruleanMart', 'BikeShop', 'CeruleanTrashedHouse', 'Route24', 'Route25',
    'BillsHouse', 'Museum1F', 'Museum2F',
)
# These source actors are reserved for scene owners, even when a nearby text_far
# happens to look like ordinary dialogue. No partial scene descriptor is emitted.
BESPOKE = {
    'Route22': {1: 'first rival approach/counter-pick/departure', 2: 'late rival; outside milestone'},
    'MtMoonB2F': {1: 'Super Nerd battle and fossil choice', 6: 'Dome Fossil choice', 7: 'Helix Fossil choice'},
    'CeruleanCity': {1: 'rival approach/counter-pick/departure', 2: 'robbery Rocket and TM28 reward'},
    'CeruleanGym': {1: 'Misty battle, Cascade Badge and TM11 reward'},
    'BikeShop': {1: 'voucher/bicycle exchange and price choice'},
    'BillsHouse': {1: 'Bill Pokemon/cell separator', 2: 'Bill human/ticket reward', 3: 'Bill scene visitor'},
    'Museum1F': {1: 'admission payment and entrance gate'},
    'MtMoonPokecenter': {4: 'Magikarp purchase'},
}


SHARED_TEXT = {
    '_FoundItemText', '_NoMoreRoomForItemText', '_MoneyForWinningText',
    '_PokemonCenterWelcomeText', '_ShallWeHealYourPokemonText', '_NeedYourPokemonText',
    '_PokemonFightingFitText', '_PokemonCenterFarewellText', '_MartSignText', '_PokeCenterSignText',
}


def blue_source(text):
    """Select cartridge Blue declarations while retaining original line numbers."""
    output, stack, active = [], [], True
    branches = {'IF DEF(_RED)': False, 'IF DEF(_BLUE)': True,
                'IF DEF(_RED_VC) || DEF(_BLUE_VC)': False}
    for line in text.splitlines():
        clean = line.split(';', 1)[0].strip()
        if clean in branches:
            stack.append((active, branches[clean]))
            active = active and branches[clean]
            output.append('')
        elif clean == 'ELSE':
            parent, branch = stack[-1]
            stack[-1] = parent, not branch
            active = parent and not branch
            output.append('')
        elif clean == 'ENDC':
            active, _ = stack.pop()
            output.append('')
        elif re.match(r'(IF|ELIF)\b', clean):
            raise ValueError('unsupported declaration conditional: ' + clean)
        else:
            output.append(line if active else '')
    if stack:
        raise ValueError('unterminated declaration conditional')
    return '\n'.join(output)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def species(symbol):
    return {'NIDORAN_M': 'nidoranM', 'NIDORAN_F': 'nidoranF',
            'MR_MIME': 'mr', 'FARFETCHD': 'farfetchd'}.get(symbol, symbol.lower())


def envelope(**values):
    return dict(schema=1, source_revision=REVISION, **values)


def sections(text):
    """Global labels and their exact bodies; local labels remain in the body."""
    matches = list(re.finditer(r'^(\w+)::?\s*$', text, re.M))
    return {m[1]: text[m.end():matches[i + 1].start() if i + 1 < len(matches) else len(text)]
            for i, m in enumerate(matches)}


def direct_labels(body):
    # Only text_far/text_end (+ sound cue) bodies are ordinary text. Any choice,
    # jump, RAM mutation or text_asm is deliberately left to an explicit planner.
    labels = []
    for line in body.splitlines():
        clean = line.split(';', 1)[0].strip()
        if not clean:
            continue
        match = re.fullmatch(r'text_far (_\w+)', clean)
        if match:
            labels.append(match[1])
        elif clean not in ('text_end', 'text_promptbutton') and not clean.startswith('sound_'):
            return None
    return labels or None


def dialogue(label):
    return dict(kind='program', steps=[dict(op='dialog', labels=[label])])


def source_byte_dialog(body, pointer):
    """Decode only the pinned single-read, descending carry-test text shape.

    hRandomAdd changes globally over time; these are separate interactions, not
    a paired script sharing a saved byte. Use one session WorldRNG byte at the
    controller operation, never a planner draw. These bodies contain no cry;
    reject added commands rather than silently dropping future sound metadata.
    """
    clean = '\n'.join(line.split(';', 1)[0].strip() for line in body.splitlines()
                      if line.split(';', 1)[0].strip())
    prefix = 'text_asm\nldh a, [hRandomAdd]\n'
    if not clean.startswith(prefix):
        raise ValueError('source byte dialog must read hRandomAdd exactly once')
    control, texts = re.split(r'\.end:?\njp TextScriptEnd\n', clean[len(prefix):])
    branches, remaining, expected_local, upper = [], control, None, 256
    pattern = re.compile(r'(?:\.(\w+):?\n)?cp (\d+)\njr c, \.(\w+)\n'
                         r'ld hl, \.(\w+)\ncall PrintText\njr \.end\n')
    while match := pattern.match(remaining):
        local, threshold, next_local, text = match.groups()
        threshold = int(threshold)
        if local != expected_local or not 0 < threshold < upper:
            raise ValueError('invalid descending source byte partition')
        branches.append(dict(min=threshold, max=upper - 1, local=text))
        expected_local, upper = next_local, threshold
        remaining = remaining[match.end():]
    fallback = re.fullmatch(r'\.(\w+):?\nld hl, \.(\w+)\ncall PrintText\n', remaining)
    if not fallback or fallback[1] != expected_local or not 1 <= len(branches) <= 15:
        raise ValueError('unsupported source byte dialog control flow')
    branches.append(dict(min=0, max=upper - 1, local=fallback[2]))
    text_pattern = re.compile(r'\.(\w+):\ntext_far (_\w+)\ntext_end(?:\n|$)')
    matches = list(text_pattern.finditer(texts))
    if ''.join(m[0] for m in matches) != texts:
        raise ValueError('unsupported source byte text commands (retain sound/cry cues explicitly)')
    labels = {m[1]: m[2] for m in matches}
    if len(labels) != len(branches) or set(labels) != {b['local'] for b in branches}:
        raise ValueError('source byte text targets differ')
    choices = [dict(min=b['min'], max=b['max'], labels=[labels[b['local']]])
               for b in reversed(branches)]
    return dict(kind='program', steps=[dict(op='random-dialog', choices=choices,
        source=dict(path='scripts/CeruleanCity.asm', pointer=pointer, byte='hRandomAdd',
                    sampling='one independent session world byte per controller operation', cry_cues=[]))])


def conditional(flag, yes, no):
    return dict(kind='cases', cases=[{'when': {'flags': {flag: True}}, 'then': dialogue(yes)}],
                otherwise=dialogue(no))


def trainer_tables(ref):
    classes = [r['args'][0] for r in records(ref.text('constants/trainer_constants.asm'), 'trainer_const')][1:]
    names = [r['args'][0].strip('"') for r in records(ref.text('data/trainers/names.asm'), 'li')]
    money = [integer(r['args'][1]) for r in records(ref.text('data/trainers/pic_pointers_money.asm'), 'pic_money')]
    raw = blue_source(ref.text('data/trainers/parties.asm'))
    pointers = re.findall(r'^\s*dw (\w+Data)\s*$', raw, re.M)
    bodies = sections(raw)
    if not len(classes) == len(names) == len(money) == len(pointers):
        raise ValueError('trainer class tables differ')
    result = {}
    for source, name, reward, label in zip(classes, names, money, pointers):
        parties = []
        for row in records(bodies[label], 'db'):
            args = row['args']
            if args[-1] != '0':
                raise ValueError('unterminated trainer roster')
            values = args[1:-1]
            if args[0] == '$FF':
                if len(values) % 2:
                    raise ValueError('invalid variable-level roster')
                party = [{'level': integer(level), 'species_source': mon, 'species': species(mon)}
                         for level, mon in zip(values[::2], values[1::2])]
            else:
                party = [{'level': integer(args[0]), 'species_source': mon, 'species': species(mon)} for mon in values]
            if not 1 <= len(party) <= 6 or any(not 1 <= m['level'] <= 100 for m in party):
                raise ValueError('invalid trainer party')
            parties.append(dict(source_line=row['line'], party=party))
        result['OPP_' + source] = dict(name=name, base_money=reward // 100,
                                       money_source_bcd3=reward, parties=parties)
    return result


def sprite_sources(ref):
    gfx = ref.text('gfx/sprites.asm')
    paths = dict(re.findall(r'^(\w+)::\s*INCBIN "gfx/sprites/([^".]+)\.2bpp"', gfx, re.M))
    result = {}
    for line in ref.text('data/sprites/sprites.asm').splitlines():
        match = re.search(r'overworld_sprite (\w+),\s*\d+\s*;\s*(SPRITE_\w+)', line)
        if match:
            result[match[2]] = paths[match[1]]
    return result


def item_ids(ref):
    from tools.generate_items import camel
    constants = ref.text('constants/item_constants.asm')
    result = {r['args'][0]: camel(r['args'][0])
              for r in records(constants.split('DEF NUM_ITEMS')[0], 'const')}
    for kind in ('tm', 'hm'):
        for index, row in enumerate(records(constants, 'add_' + kind), 1):
            result[kind.upper() + '_' + row['args'][0]] = f'{kind}{index:02}'
    return result


def build(reference_root):
    pin = json.loads(PIN.read_bytes())
    if pin['revision'] != REVISION or tuple(pin['maps']) != MAPS:
        raise ValueError('Cerulean pin revision/inventory differs')
    ref = Reference(reference_root, pin['files'])
    definitions = {name: decode_map(ref, name) for name in MAPS}
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
    supplemental = ['scripts/CeruleanCity_2.asm', 'data/items/marts.asm',
                    'engine/events/pokecenter.asm', 'data/events/hidden_item_coords.asm',
                    'data/maps/toggleable_objects.asm', 'home/overworld_text.asm']
    for path in supplemental:
        scripts[path] = ref.text(path)
    text_paths = [f'text/{name}.asm' for name in MAPS] + ['text/Route24_2.asm']
    text_paths += ['data/text/text_1.asm', 'data/text/text_2.asm', 'data/text/text_3.asm', 'data/text/text_4.asm']
    for path in text_paths:
        for label, recipe in text_recipes(blue_source(ref.text(path))).items():
            if path.startswith('data/text/') and label not in SHARED_TEXT:
                continue
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
            elif pointer in ('CeruleanCityCooltrainerF1Text', 'CeruleanCitySlowbroText'):
                descriptor = source_byte_dialog(body, pointer)
            elif pointer == 'CeruleanMartClerkText':
                descriptor = dict(kind='program', steps=[dict(op='shop', id='ceruleanMartClerkText')])
            elif pointer == 'BikeShopYoungsterText':
                descriptor = conditional('EVENT_GOT_BICYCLE', '_BikeShopYoungsterCoolBikeText', '_BikeShopYoungsterTheseBikesAreExpensiveText')
            elif pointer == 'CeruleanGymGymGuideText':
                descriptor = conditional('EVENT_BEAT_MISTY', '_CeruleanGymGymGuideBeatMistyText', '_CeruleanGymGymGuideChampInMakingText')
            elif pointer == 'CeruleanTrashedHouseFishingGuruText':
                descriptor = dict(kind='cases', cases=[{'when': {'items_min': {'tm28': 1}}, 'then':
                    dialogue('_CeruleanTrashedHouseFishingGuruWhatsLostIsLostText')}],
                    otherwise=dialogue('_CeruleanTrashedHouseFishingGuruTheyStoleATMText'))
            elif pointer == 'Museum1FScientist2Text':
                descriptor = dict(kind='gift', item='oldAmber', flag='EVENT_GOT_OLD_AMBER',
                    prefix=[dict(op='dialog', labels=['_Museum1FScientist2TakeThisToAPokemonLabText'])],
                    success=['_Museum1FScientist2ReceivedOldAmberText'], full=['_Museum1FScientist2YouDontHaveSpaceText'],
                    completed=['_Museum1FScientist2GetTheOldAmberCheckText'])
            elif ordinary and not reason:
                descriptor = dict(kind='program', steps=[dict(op='dialog', labels=ordinary)])
            elif 'script_pokecenter_nurse' in body:
                # Checkpoint must be selected from source outside ingress, not
                # inferred from a floor tile or generic Viridian fallback.
                outer = 'CeruleanCity' if name == 'CeruleanPokecenter' else 'Route4'
                ingress = next(w for w in definitions[outer]['events']['warps']
                               if w['destination'].get('map') == d['source_map_constant'])
                descriptor = dict(kind='program', steps=[dict(op='heal', id=name,
                    nurse_id=event['id'], welcome='_PokemonCenterWelcomeText', prompt='_ShallWeHealYourPokemonText',
                    before='_NeedYourPokemonText', after='_PokemonFightingFitText', farewell='_PokemonCenterFarewellText',
                    checkpoint=dict(zone_id=definitions[outer]['id'], x=ingress['x'], y=ingress['y'] + 1, facing='down'))])
            if descriptor and not reason:
                events[event['id']] = dict(content='cerulean', **descriptor)
            else:
                gaps.append(dict(id=event['id'], map=name, pointer=pointer,
                                 reason=reason or 'source control requires explicit planner'))
        for event in d['events']['background_events']:
            pointer = pointers[event['text_id']]
            labels = direct_labels(all_sections.get(pointer, ''))
            if labels:
                signs[event['id']] = dict(content='cerulean', kind='program', steps=[dict(op='dialog', labels=labels)])
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
        'dialogue.json': canonical(envelope(texts=texts)),
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
            path=f'data/sourceSlice/{name}.json', profile='source', width=max(13, width), height=height,
            padding=padding, source_sha256=digest(output[name + '.json']), spawn=dict(x=x + padding, y=y, facing='up'))
    output['manifest-entries.json'] = canonical(envelope(maps=entries))
    output['provenance.json'] = canonical(envelope(
        maps=list(MAPS), version='English Blue', source_files=ref.consumed,
        generator_sha256=digest(Path(__file__).read_bytes()),
        render_contract=dict(pattern_phase=[0, 0], sprite_converter='generate_viridian_slice.sprite_data',
                             terrain_converter='generate_kanto_maps.decode_map', alpha='existing SpriteFactory border flood-fill'),
        artifacts={name: digest(data) for name, data in output.items()},
        status='decoded content candidate; no Simulator, visual or campaign acceptance'))
    return output


def verify_installed_entries(artifacts):
    """Check this region's entries without owning the common manifest/cache.

    Root owns activation metadata (blockers, arrivals and connection sources).
    The regional generator owns decoded identity, geometry, pins and spawn only.
    """
    manifest = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    for name, expected in json.loads(artifacts['manifest-entries.json'])['maps'].items():
        actual = manifest['maps'].get(name, {})
        for field, value in expected.items():
            if actual.get(field) != value:
                raise ValueError('installed source entry drift: ' + name + ':' + field)


def verify(artifacts, directory):
    directory = Path(directory)
    if directory.is_symlink() or not directory.is_dir() or {p.name for p in directory.iterdir()} != set(artifacts):
        raise ValueError('Cerulean artifact inventory differs')
    for name, expected in artifacts.items():
        path = directory / name
        if path.is_symlink() or not path.is_file() or path.read_bytes() != expected:
            raise ValueError('Cerulean artifact drift: ' + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    artifacts = build(args.reference)
    if args.check:
        verify(artifacts, args.output)
        verify_installed_entries(artifacts)
    else:
        args.output.mkdir(parents=True, exist_ok=False)
        for name, data in artifacts.items():
            (args.output / name).write_bytes(data)
    print(f'Verified {len(MAPS)} source maps and {len(artifacts) - len(MAPS)} content records')


if __name__ == '__main__':
    main()
