#!/usr/bin/env python3
"""Project declared Cerulean owner inputs; runtime observation verifies registration.

No Lua execution or gameplay emulation. Preserve ordered roster records verbatim.
--check is read-only and works with either the current or final map manifest.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
COUNTER = {'charmander': 'squirtle', 'squirtle': 'bulbasaur', 'bulbasaur': 'charmander'}


def project(source):
    source = Path(source)
    hashes = {}

    def read(path):
        raw = (source / path).read_bytes()
        hashes[path] = hashlib.sha256(raw).hexdigest()
        return raw.decode()

    def record(path):
        value = json.loads(read(path))
        if value.get('schema') != 1 or value.get('source_revision') != REVISION:
            raise ValueError('unverified source record: ' + path)
        return value

    record('data/sourceMaps.json')
    events = record('data/sourceEvents.json')['events']
    ordinary = record('data/sourceSlice/events.json')
    story = record('data/ceruleanStory/events.json')['events']
    trainers = record('data/sourceSlice/trainers.json')
    # This is the same defensive merge as CeruleanStory.registerTrainers().
    definitions = copy.deepcopy(trainers['trainers'])
    for stable, expected in record('data/ceruleanStory/trainers.json')['trainers'].items():
        if stable in definitions:
            actual = definitions[stable]
            for field in ('map_id', 'sprite_source', 'payout'):
                if actual[field] != expected[field]:
                    raise ValueError('conflicting story trainer: ' + stable)
            if [(m['species'], m['level']) for m in actual['party']] != [(m['species'], m['level']) for m in expected['party']]:
                raise ValueError('conflicting story roster: ' + stable)
        else:
            definitions[stable] = expected
    pewter = record('data/pewterSlice/trainers.json')['trainers']
    names = record('data/pewterSlice/trainerNames.json')
    for definition in pewter:
        stable = definition['id']
        definition['name'] = names['names'][definition['class_source']]
        definition['sprite_source'] = names['sprites'][stable]
        if stable in definitions:
            raise ValueError('duplicate trainer: ' + stable)
        definitions[stable] = definition

    routes = record('data/ceruleanRoutes/scenes.json')
    route_owner = read('game/ceruleanRoutes.lua')
    # Refuse a changed counter-selection algorithm; no English team inference.
    counter = re.search(r'local counter = \{([^\n]+)\}', route_owner)
    if not counter or dict(re.findall(r'(\w+)="(\w+)"', counter[1])) != COUNTER:
        raise ValueError('review changed rival selection owner')
    rivals = {}
    for scene in routes['rivals'].values():
        variants = {}
        roster = trainers['rival_classes'][scene['class']]
        for starter, rival in COUNTER.items():
            number = scene['roster_by_rival_starter'][rival]
            party = copy.deepcopy(roster['parties'][number - 1]['party'])
            if party[-1]['species'] != rival:
                raise ValueError('counter team mismatch')
            variants[starter] = dict(id=scene['id'], map_id=scene['id'].rsplit(':', 2)[0],
                                     name='BLUE', sprite_source=scene['sprite_source'],
                                     sight_range_cells=0, talk_only=True,
                                     party=party, payout=roster['base_money'] * party[-1]['level'])
        rivals[scene['id']] = variants
    route_ids = set(re.findall(r'local (?:ROUTE|RIVAL|THIEF|NUGGET) <const> = "([^"]+)"', route_owner))
    unavailable = re.findall(r'events\["([^"]+)"\] =', route_owner)
    if len(route_ids) != 4 or len(unavailable) != 1:
        raise ValueError('review changed route registration')
    merged = {}
    for group in (events, ordinary['events'], ordinary['signs'], story):
        if set(merged) & set(group):
            raise ValueError('duplicate event registration')
        merged.update(group)
    if set(merged) & (route_ids | set(unavailable)):
        raise ValueError('duplicate route registration')
    event_ids = sorted(set(merged) | route_ids | set(unavailable))

    items = read('data/items.lua')
    prices = dict((key, int(price)) for key, price in re.findall(
        r'^        (\w+) = \{ \["id"\] = "\1"[^\n]*?\["price"\] = (\d+)', items, re.M))
    shops = {}
    for stable in ('pokered:PEWTER_MART:objects:1', 'pokered:CERULEAN_MART:objects:1'):
        steps = merged[stable]['steps']
        if len(steps) != 1 or steps[0]['op'] != 'shop':
            raise ValueError('review changed shop plan')
        mart = steps[0]['id']
        match = re.search(r'^        ' + re.escape(mart) + r' = \{([^\n]+)\}', items, re.M)
        if not match:
            raise ValueError('missing actual mart stock')
        stock = re.findall(r'"(\w+)"', match[1])
        shops[stable] = dict(stock=stock, prices={key: prices[key] for key in stock})
    codec = re.search(r'SessionCodec=\{VERSION=(\d+),', read('domain/sessionCodec.lua'))
    if not codec:
        raise ValueError('review changed SessionCodec declaration')
    pc = record('data/ceruleanStory/scenes.json')['pc_player']
    # Hash all runtime registration/planning inputs, including the root wiring.
    for path in ('main.lua', 'data/ceruleanContent.lua', 'game/ceruleanStory.lua',
                 'game/sourceEvents.lua', 'game/sourceEventHandlers.lua', 'game/trainerEvents.lua',
                 'game/eventState.lua', 'game/shopState.lua', 'data/pewterSlice.lua'):
        read(path)
    return dict(schema=1, source_revision=REVISION, sources=dict(sorted(hashes.items())),
                events=event_ids, trainers=definitions, rivals=rivals, shops=shops,
                session_codec=int(codec[1]), bill_pc_player=pc)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'Source')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = args.output or args.source / 'dev/ceruleanJourney.json'
    result = json.dumps(project(args.source), indent=2, sort_keys=True) + '\n'
    if args.check:
        if not output.is_file() or output.read_text() != result:
            parser.exit(1, 'Cerulean journey projection is stale; regenerate after composition\n')
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(result)


if __name__ == '__main__':
    main()
