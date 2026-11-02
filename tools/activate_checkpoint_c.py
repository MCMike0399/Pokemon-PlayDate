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

BASE = '7726ea49'


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
