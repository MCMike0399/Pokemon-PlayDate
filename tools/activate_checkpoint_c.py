#!/usr/bin/env python3
"""Prepare checkpoint C with the shared manifest, map and binary-cell builder."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_source_map_cache import build, canonical

BASE = '24ea539cd68142af6b50ca57841cdb8ae350f519'


def pinned(path, project=ROOT):
    expected = subprocess.check_output(['git', '-C', str(ROOT), 'show', BASE + ':' + path])
    if (Path(project) / path).read_bytes() != expected:
        raise ValueError('accepted B pinned input changed: ' + path)
    return json.loads(expected)


def inventories(project=ROOT):
    previous = json.loads(subprocess.check_output([
        'git', '-C', str(ROOT), 'show', BASE + ':Source/data/sourceMaps.json']))
    saffron = pinned('Source/data/midgameSaffron/manifest-entries.json', project)['maps']
    for record in ('events', 'dialogue', 'sprites', 'trainers'):
        pinned('Source/data/midgameSaffron/' + record + '.json', project)
    fly = pinned('Source/data/midgameSouth/manifest-entries.json', project)['maps']['Route16FlyHouse']
    additions = dict(saffron, Route16FlyHouse=fly)
    if len(previous['maps']) != 149 or len(saffron) != 21 or set(previous['maps']) & set(additions):
        raise ValueError('accepted B 149 / Saffron 21 / Fly 1 inventory drift')
    for name, entry in dict(previous['maps'], **additions).items():
        raw = (Path(project) / 'Source' / entry['path']).read_bytes()
        original = subprocess.check_output(['git', '-C', str(ROOT), 'show', BASE + ':Source/' + entry['path']])
        if raw != original or hashlib.sha256(raw).hexdigest() != entry['source_sha256']:
            raise ValueError('pinned decoded map changed: ' + name)
    return previous, additions


def manifest(project=ROOT):
    previous, additions = inventories(project)
    previous['maps'].update(additions)
    # Reviewed manifest correction only: keep the inaccessible source declaration,
    # but do not author a barrier over its ordinary floor.
    blocked = previous['maps']['SilphCo11F']['blocked_events']
    blocked.remove('pokered:SILPH_CO_11F:warps:3')
    # Reuse the source-derived owner enumeration, including zero-based bytes.
    # Pin only the elevator projection this builder consumes: doors, story
    # toggles and guard transitions have their own source generator and pinned
    # transform provenance, and never change an installed map record.
    raw = (Path(project) / 'Source/data/silphStory/scenes.json').read_bytes()
    elevator = json.loads(raw)['scenes']['elevator']
    if hashlib.sha256(canonical({'elevator': elevator})).hexdigest() != 'a242e5f190ad667ad470a5147dff1d458a86cabd08179cb488a30cf9f410e0a7':
        raise ValueError('pinned Silph elevator data changed')
    names = {entry['id']: name for name, entry in previous['maps'].items()}
    for row in elevator:
        entry = previous['maps'][names[row['map_id']]]
        definition = json.loads((Path(project) / 'Source' / entry['path']).read_bytes())
        event = definition['events']['warps'][row['source_warp_byte']]
        if (dict(x=event['x'], y=event['y']) != row['destination']
                or event['destination']['map'] != 'SILPH_CO_ELEVATOR'):
            raise ValueError('Silph elevator source warp differs')
        entry.setdefault('scripted_warps', []).append(event['id'])
    cabin = previous['maps']['SilphCoElevator']
    definition = json.loads((Path(project) / 'Source' / cabin['path']).read_bytes())
    cabin['scripted_warps'] = [event['id'] for event in definition['events']['warps']]
    if len(elevator) != 11 or len(cabin['scripted_warps']) != 2:
        raise ValueError('Silph elevator enumeration differs')
    return previous


def prepare(output, project=ROOT):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    path = output / 'sourceMaps.json'
    path.write_bytes(canonical(manifest(project)))
    cells = {}
    cache = build(path, Path(project) / 'Source', cell_artifacts=cells)
    for directory, files in [('sourceMapCache', cache), ('sourceMapCells', cells)]:
        target = output / directory
        target.mkdir()
        for name, raw in files.items():
            (target / name).write_bytes(raw)
    print('Prepared 171 candidate maps: accepted B 149 plus Saffron 21 and Route16FlyHouse.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.output)
