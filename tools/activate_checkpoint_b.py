#!/usr/bin/env python3
"""Prepare checkpoint B through the existing manifest, map and binary-cell builder."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_source_map_cache import build, canonical

ACCEPTED = '2dd9f3cc'
PARKED = {'Route16FlyHouse'}


def inventories(project=ROOT):
    project = Path(project)
    accepted = json.loads(subprocess.check_output([
        'git', '-C', str(ROOT), 'show', ACCEPTED + ':Source/data/sourceMaps.json']))
    south = json.loads((project / 'Source/data/midgameSouth/manifest-entries.json').read_bytes())['maps']
    if len(accepted['maps']) != 108 or len(south) != 42 or set(accepted['maps']) & set(south) or not PARKED <= south.keys():
        raise ValueError('accepted 108 / pinned South 42 inventory drift')
    return accepted, {name: entry for name, entry in south.items() if name not in PARKED}


def manifest(project=ROOT):
    accepted, south = inventories(project)
    accepted['maps'].update(south)
    return accepted


def prepare(output, project=ROOT):
    output.mkdir(parents=True, exist_ok=False)
    data = manifest(project)
    path = output / 'sourceMaps.json'
    path.write_bytes(canonical(data))
    cells = {}
    cache = build(path, Path(project) / 'Source', cell_artifacts=cells)
    for directory, files in [('sourceMapCache', cache), ('sourceMapCells', cells)]:
        target = output / directory
        target.mkdir()
        for name, raw in files.items():
            (target / name).write_bytes(raw)
    print('Prepared 149 maps: accepted 108 plus 41 South maps; Route16FlyHouse remains parked.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.output)
