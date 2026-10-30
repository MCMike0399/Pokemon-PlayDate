#!/usr/bin/env python3
"""Derive application-owned timer overrides from checksum-pinned SDK 3.1.2.

Only the final removal-queue reset changes. No installed SDK file is written.
Run --write before compiling, or --check to verify the checked-in candidate.
"""
import argparse
import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SDK_VERSION = '3.1.2'
INPUT_SHA256 = {
    'CoreLibs/timer.lua': 'ffc8f98405fb3f8963ccad572fff66cd6de4b9d16efa08003304583297ac0c3d',
    'CoreLibs/frameTimer.lua': '7c03955a9853f3fe9da00d3f016150771db3587f341c49a1e2062094110f07ea',
    'SDK_LICENSE.md': 'b1e5c2c696faaae504e43b19a2f4e850f563f4a04317bd28fd354d2ec3c03905',
}
OLD = b'\ttimersToRemove = {}\n'
NEW = (b'\tfor i = #timersToRemove, 1, -1 do\n'
       b'\t\ttimersToRemove[i] = nil\n'
       b'\tend\n')


def derive(sdk):
    sdk = Path(sdk).expanduser().resolve()
    if (sdk / 'VERSION.txt').read_text().strip() != SDK_VERSION:
        raise ValueError('timer runtime requires SDK ' + SDK_VERSION)
    artifacts = {}
    for name, expected in INPUT_SHA256.items():
        raw = (sdk / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected:
            raise ValueError('pinned SDK checksum differs: ' + name)
        if name.endswith('.lua'):
            if raw.count(OLD) != 1:
                raise ValueError('expected exactly one final queue reset: ' + name)
            artifacts[Path(name).name] = raw.replace(OLD, NEW, 1)
        else:
            artifacts[name] = raw
    return artifacts


def generate(sdk, output, *, check=False):
    output = Path(output).expanduser().resolve()
    sdk = Path(sdk).expanduser().resolve()
    # Never let --output-dir point into the shared SDK, even by a symlink.
    if output == sdk or sdk in output.parents:
        raise ValueError('output must be outside the installed SDK')
    artifacts = derive(sdk)  # Validate every input before writing any output.
    for name, raw in artifacts.items():
        path = output / name
        if path.is_symlink():
            raise ValueError('output must not be a symlink: ' + str(path))
    if check:
        for name, raw in artifacts.items():
            path = output / name
            if not path.is_file() or path.read_bytes() != raw:
                raise ValueError('generated timer runtime differs: ' + str(path))
    else:
        output.mkdir(parents=True, exist_ok=True)
        for name, raw in artifacts.items():
            (output / name).write_bytes(raw)
    return artifacts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, default=Path(os.environ.get(
        'PLAYDATE_SDK_PATH', Path.home() / 'Developer/PlaydateSDK')))
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'Source/CoreLibs')
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--write', action='store_true')
    args = parser.parse_args()
    try:
        artifacts = generate(args.sdk, args.output_dir, check=args.check)
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + '\n')
    for name, raw in artifacts.items():
        print(hashlib.sha256(raw).hexdigest(), name)


if __name__ == '__main__':
    main()
