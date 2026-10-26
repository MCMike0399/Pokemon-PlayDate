#!/usr/bin/env python3
"""Deterministic declared-owner projection for the private 5.4 input candidate.

This inventories prepared data, not runtime registration. Runtime preflight must
verify every declaration against actual registered owners before New Game.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
RIVAL = 'pokered:SS_ANNE_2F:objects:2'


def project(source):
    source = Path(source)
    hashes = {}

    def read(relative):
        raw = (source / relative).read_bytes()
        hashes[relative] = hashlib.sha256(raw).hexdigest()
        return raw.decode()

    def record(relative):
        value = json.loads(read(relative))
        if value.get('schema') != 1 or value.get('source_revision') != REVISION:
            raise ValueError('unverified projection input: ' + relative)
        return value

    maps = record('data/vermilionPreparation/manifest-entries.json')['maps']
    if len(maps) != 35:
        raise ValueError('review changed 35-map preparation scope')
    for name, entry in maps.items():
        raw = record(entry['path'])
        if hashes[entry['path']] != entry['source_sha256'] or raw['id'] != entry['id'] or raw['name'] != name:
            raise ValueError('prepared map pin differs: ' + name)
    ordinary = record('data/vermilionPreparation/events.json')
    events = {}
    for group in (ordinary['events'], ordinary['signs'],
                  record('data/vermilionGifts/events.json')['events'],
                  record('data/vermilionStory/events.json')['events']):
        if set(events) & set(group):
            raise ValueError('conflicting event owners')
        events.update(group)
    trainers = copy.deepcopy(record('data/vermilionPreparation/trainers.json')['trainers'])
    scenes = record('data/vermilionStory/scenes.json')['scenes']
    for stable, trainer in record('data/vermilionStory/trainers.json')['trainers'].items():
        if stable in trainers:
            ordinary_trainer = trainers[stable]
            for field in ('map_id', 'sprite_source'):
                if ordinary_trainer[field] != trainer[field]:
                    raise ValueError('conflicting trainer identity: ' + stable)
            if stable != RIVAL and [(m['species'], m['level']) for m in ordinary_trainer['party']] != [(m['species'], m['level']) for m in trainer['party']]:
                raise ValueError('conflicting trainer roster: ' + stable)
        trainers[stable] = trainer
    rivals = trainers[RIVAL]['rival_parties']
    counters = {'bulbasaur': 'charmeleon', 'charmander': 'wartortle', 'squirtle': 'ivysaur'}
    if set(rivals) != set(counters):
        raise ValueError('missing starter counter teams')
    for starter, final in counters.items():
        if [(m['species'], m['level']) for m in rivals[starter]['party']] != [
                ('pidgeotto', 19), ('raticate', 16), ('kadabra', 18), (final, 20)]:
            raise ValueError('review changed pinned Anne counter team')
        if rivals[starter]['payout'] != 1300:
            raise ValueError('review changed rival payout')
    field = record('data/fieldMoves.json')
    codec = re.search(r'SessionCodec=\{VERSION=(\d+),', read('domain/sessionCodec.lua'))
    if not codec:
        raise ValueError('review changed codec declaration')
    machine = read('data/machineData.lua')
    cut_species = []
    for species, body in re.findall(r'^        (\w+)=\{([^\n]*)\}', machine, re.M):
        if re.search(r'\bhm01=true\b', body):
            cut_species.append(species)
    if not cut_species:
        raise ValueError('review changed machine compatibility declaration')
    for relative in ('main.lua', 'data/ceruleanJourney.json', 'data/sourceMaps.json',
                     'data/sourceMapCache/compact.json', 'data/sourceMapCache/tile-grids.json',
                     'data/vermilionPreparation/reservations.json', 'data/vermilionPreparation/packages.json',
                     'data/vermilionStory/terrain.json', 'data/items.lua',
                     'game/vermilionGifts.lua', 'game/vermilionStory.lua',
                     'game/vermilionStoryHooks.lua', 'game/vermilionStoryIntent.lua',
                     'game/vermilionStoryState.lua', 'game/vermilionStoryTerrain.lua',
                     'game/fieldMoveState.lua', 'game/partyState.lua', 'game/bagState.lua',
                     'game/sourceEvents.lua', 'game/trainerEvents.lua', 'game/saves.lua',
                     'domain/fieldMoves.lua', 'domain/fieldWorld.lua', 'domain/teaching.lua',
                     'data/ceruleanContent.lua'):
        read(relative)
    # Existing worker modules are optional inputs until integrated. Their absence
    # is declared, never interpreted as an implemented service.
    daycare = [p.relative_to(source).as_posix() for p in sorted(source.rglob('*daycare*.lua'))]
    for relative in daycare:
        read(relative)
    if daycare:
        if not {'game/daycare.lua', 'game/daycareState.lua'} <= set(daycare):
            raise ValueError('partial Day Care owner inputs')
        policy = record('data/daycare/policy.json')
        if set(events) & set(policy['events']):
            raise ValueError('duplicate Day Care registration')
        events.update(policy['events'])
    return dict(schema=1, source_revision=REVISION, sources=dict(sorted(hashes.items())),
                maps=maps, events=events, trainers=trainers, scenes=scenes,
                cut_sites=field['maps']['pokered:VERMILION_CITY']['sites'],
                cut_species=sorted(cut_species), session_codec=int(codec[1]),
                daycare_inputs=daycare, registration='declarations-only; runtime must qualify')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'Source')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = args.output or args.source / 'data/vermilionJourney.json'
    encoded = json.dumps(project(args.source), indent=2, sort_keys=True) + '\n'
    if args.check:
        if not output.is_file() or output.read_text() != encoded:
            parser.exit(1, 'Vermilion projection is stale; regenerate after root composition\n')
    else:
        output.write_text(encoded)


if __name__ == '__main__':
    main()
