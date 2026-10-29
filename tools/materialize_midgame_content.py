#!/usr/bin/env python3
"""Materialize checksum-pinned Blue packet inputs outside Git, without network."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.generate_midgame_content import PACKETS, REVISION, digest, pin_path


def destination(packet):
    return Path(os.environ.get('POKEMON_ENV', Path.home() / 'Developer/Pokemon-PlayDate-env')).expanduser().resolve() / 'references' / ('midgame-' + packet)


def verify_cache(packet, directory):
    directory = Path(directory)
    if directory.resolve().is_relative_to(ROOT) or directory.is_symlink():
        raise ValueError('midgame raw source must remain outside Git')
    pin = json.loads(pin_path(packet).read_bytes())
    if pin['revision'] != REVISION or pin['maps'] != list(PACKETS[packet]):
        raise ValueError('midgame pin revision/inventory drift')
    expected = dict(pin['files'], **{'pins.json': digest(pin_path(packet).read_bytes())})
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file()}
    if actual != set(expected):
        raise ValueError('midgame cache inventory differs')
    for name, checksum in expected.items():
        path = directory / name
        if path.is_symlink() or digest(path.read_bytes()) != checksum:
            raise ValueError('midgame cache checksum differs: ' + name)
    return len(expected)


def materialize(packet, checkout, output):
    if output.resolve().is_relative_to(ROOT) or output.is_symlink():
        raise ValueError('midgame raw source must remain outside Git')
    if output.exists():
        return verify_cache(packet, output)
    pin = json.loads(pin_path(packet).read_bytes())
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.midgame-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'cache'
        stage.mkdir()
        (stage / 'pins.json').write_bytes(pin_path(packet).read_bytes())
        for name, checksum in pin['files'].items():
            raw = subprocess.check_output(['git', '-C', str(checkout), 'show', REVISION + ':' + name])
            if digest(raw) != checksum:
                raise ValueError('pinned Blue source differs: ' + name)
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
        count = verify_cache(packet, stage)
        stage.rename(output)
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet', choices=PACKETS, required=True)
    parser.add_argument('--pokered', type=Path, default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    target = args.output or destination(args.packet)
    if args.check:
        count = verify_cache(args.packet, target)
    else:
        if args.pokered is None:
            parser.error('provide --pokered or POKERED_REFERENCE_DIR')
        count = materialize(args.packet, args.pokered, target)
    print(f'Verified {count} files at {target}')

if __name__ == '__main__':
    main()
