#!/usr/bin/env python3
"""Materialize pinned field-move inputs outside Git.

Source the project environment first. For a local Showdown checkout, use:
  python tools/materialize_field_moves.py --pokered "$POKERED_REFERENCE_DIR" --showdown /path/to/showdown
Otherwise add --fetch-showdown to fetch checksum-verified official raw files.
Use --check to verify the existing cache without Git access or network requests.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PINS = ROOT / 'tools/references/field-moves/pins.json'


def reference_root():
    environment = Path(os.environ.get('POKEMON_ENV', Path.home() / 'Developer/Pokemon-PlayDate-env'))
    identity = hashlib.sha256(PINS.read_bytes()).hexdigest()
    return environment.expanduser().resolve() / 'references/field-moves-pins' / identity


def verify_cache(directory):
    directory = Path(directory)
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError('Field-move cache is missing. Run tools/materialize_field_moves.py first.')
    pins = json.loads(PINS.read_bytes())
    expected = {'pins.json': hashlib.sha256(PINS.read_bytes()).hexdigest()}
    expected.update({'pokered/' + name: digest for name, digest in pins['pokered'].items()})
    expected.update({'showdown/' + name: digest for name, digest in pins['showdown']['files'].items()})
    actual = {path.relative_to(directory).as_posix() for path in directory.rglob('*') if path.is_file()}
    if actual != set(expected):
        raise ValueError('Field-move cache inventory differs from pins.json.')
    for name, digest in expected.items():
        path = directory / name
        if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('Field-move cache checksum differs: ' + name)
    return len(expected)


def git_bytes(checkout, revision, name):
    return subprocess.check_output(['git', '-C', str(checkout), 'show', revision + ':' + name])


def materialize(pokered, showdown=None, fetch_showdown=False):
    destination = reference_root()
    if destination.resolve().is_relative_to(ROOT):
        raise ValueError('The field-move cache must be outside the repository.')
    if destination.exists():
        return verify_cache(destination)
    pins = json.loads(PINS.read_bytes())
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.field-moves-', dir=destination.parent) as temporary:
        stage = Path(temporary) / 'cache'
        stage.mkdir()
        (stage / 'pins.json').write_bytes(PINS.read_bytes())
        for kind, revision, files in [('pokered', pins['source_revision'], pins['pokered']),
                                      ('showdown', pins['showdown']['revision'], pins['showdown']['files'])]:
            for name, digest in files.items():
                legacy = destination.parent.parent / 'field-moves' / kind / name
                if legacy.is_file() and hashlib.sha256(legacy.read_bytes()).hexdigest() == digest:
                    raw = legacy.read_bytes()
                elif kind == 'pokered':
                    raw = git_bytes(pokered, revision, name)
                elif showdown is not None:
                    raw = git_bytes(showdown, revision, name)
                elif fetch_showdown:
                    url = 'https://raw.githubusercontent.com/smogon/pokemon-showdown/' + revision + '/' + name
                    with urllib.request.urlopen(url, timeout=60) as response:
                        raw = response.read()
                else:
                    raise ValueError('Missing verified input; provide --showdown or --fetch-showdown: ' + name)
                if hashlib.sha256(raw).hexdigest() != digest:
                    raise ValueError('Pinned source checksum differs: ' + kind + '/' + name)
                path = stage / kind / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
        count = verify_cache(stage)
        stage.rename(destination)
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pokered', type=Path, default=os.environ.get('POKERED_REFERENCE_DIR'))
    source = parser.add_mutually_exclusive_group()
    source.add_argument('--showdown', type=Path)
    source.add_argument('--fetch-showdown', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        count = verify_cache(reference_root())
    else:
        if args.pokered is None:
            parser.error('Provide --pokered or set POKERED_REFERENCE_DIR.')
        count = materialize(args.pokered, args.showdown, args.fetch_showdown)
    print(f'Verified {count} files at {reference_root()}')


if __name__ == '__main__':
    main()
