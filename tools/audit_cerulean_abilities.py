#!/usr/bin/env python3
"""Read-only ordinary ability exposure inventory, never mechanics acceptance."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def inventory(root=ROOT, level_cap=22):
    data = root / 'Source/data'
    pokemon = (data / 'pokemon.lua').read_text()
    dex = dict((species, int(number)) for species, number in re.findall(
        r'^    (\w+) = \{\n        name = "[^\"]+", dex = (\d+)', pokemon, re.M))
    text = (data / 'specimenData.lua').read_text()
    slots = {int(number): [int(a), int(b)] for number, a, b in re.findall(
        r'\[(\d+)\] = \{first=(\d+),second=(\d+)', text)}
    names = {int(number): name for number, name in re.findall(r'\[(\d+)\] = "([^\"]+)"', text)}
    # Independently verify the generated ordinary slots against vendored B2W2
    # personal bytes. No new data generation, fixture ability override or hidden slot.
    personal = (root / 'tools/references/traits/personal_b2w2').read_bytes()
    assert hashlib.sha256(personal).hexdigest() == '6df24e7f00dab32322d9d8f8b3209d30de1c89b0de88277081fe53434211830f'
    for number, ordinary in slots.items():
        assert ordinary == list(personal[number*76+24:number*76+26]), number
    rows = {}
    capturable = set()

    def add(species, level, source, kind):
        row = rows.setdefault(species, {'species': species, 'dex': dex[species],
            'ordinary_ids': slots[dex[species]],
            'ordinary_names': [names[n] for n in slots[dex[species]]], 'exposure': []})
        exposure = dict(source=source, kind=kind, level=level)
        if exposure not in row['exposure']:
            row['exposure'].append(exposure)

    manifest = json.loads((data / 'sourceMaps.json').read_text())
    for entry in manifest['maps'].values():
        if entry['profile'] != 'source' or not entry['path'].startswith('data/sourceSlice/'):
            continue
        definition = json.loads((root / 'Source' / entry['path']).read_text())
        for medium in ('grass', 'water'):
            table = definition.get('encounters', {}).get(medium, {})
            if not table.get('rate_byte', 0):
                continue
            for slot in table['slots']:
                add(slot['species'], slot['level'],
                    f"{entry['id']}:{medium}:{slot['index']}", 'wild')
                capturable.add(slot['species'])
    trainers = json.loads((data / 'sourceSlice/trainers.json').read_text())
    for source, trainer in trainers['trainers'].items():
        for member in trainer['party']:
            add(member['species'], member['level'], source, 'trainer')
    scenes = json.loads((data / 'ceruleanRoutes/scenes.json').read_text())
    for scene in scenes['rivals'].values():
        for roster in scene['roster_by_rival_starter'].values():
            for member in trainers['rival_classes'][scene['class']]['parties'][roster-1]['party']:
                add(member['species'], member['level'], scene['id'], 'rival')
    gifts = json.loads((data / 'kantoServices/policy.json').read_text())['magikarp']
    gift_events = json.loads((data / 'kantoServices/events.json').read_text())
    # Keep the real event ID in the report, rather than inventing an interaction.
    for source, event in gift_events['events'].items():
        if event.get('service') == 'magikarp':
            add(gifts['species'], gifts['level'], source, 'gift')
    capturable.add(gifts['species'])
    for species in ('bulbasaur', 'charmander', 'squirtle'):
        add(species, 5, 'authored:starter-choice', 'starter')
        capturable.add(species)
    evolution = (data / 'evolutionData.lua').read_text()
    # Only normal progression through level22 and actually obtained Moon Stones;
    # no trade, unavailable stone, friendship-only Crobat, or unlimited grind tail.
    queue = sorted(capturable)
    while queue:
        source = queue.pop()
        line = re.search(r'^    ' + source + r' = (.*)',
                         evolution, re.M)
        if not line:
            continue
        for body in re.findall(r'\{to = "(\w+)"([^}]+)\}', line[1]):
            target, rule = body
            level = re.search(r'minimum = (\d+)', rule)
            allowed = ('trigger = "level"' in rule and level and int(level[1]) <= level_cap
                       or 'item = "moonStone"' in rule)
            if allowed:
                add(target, int(level[1]) if level else None,
                    'evolution:' + source, 'player-evolution')
                if target not in capturable:
                    capturable.add(target)
                    queue.append(target)
    return dict(scope='source-profile wild, ordinary trainers, bound rival rosters, gift, starters; player evolutions through22/Moon Stone',
                acceptance=False, species=sorted(rows.values(), key=lambda row: row['dex']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = json.dumps(inventory(), indent=2) + '\n'
    if args.output:
        args.output.write_text(output)
    else:
        print(output, end='')
