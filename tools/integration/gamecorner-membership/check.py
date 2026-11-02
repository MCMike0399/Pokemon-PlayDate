#!/usr/bin/env python3
"""Private SDK membership differential. Compile-only unless Root passes --execute."""
import argparse
from pathlib import Path
import shutil
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.harness import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    original = run.overlay_imports
    packet = Path(__file__).parent
    frozen = subprocess.check_output([
        'git', 'show', '952db34f:Source/game/rocketHideoutStoryWorld.lua'], cwd=ROOT, text=True)
    frozen = frozen[:frozen.index('function RocketHideoutStoryWorld.commit(')]
    current = (ROOT / 'Source/game/rocketHideoutStoryWorld.lua').read_text()
    original_world = subprocess.check_output([
        'git', 'show', '952db34f:Source/game/rocketHideoutStoryWorld.lua'], cwd=ROOT, text=True)
    if current != original_world.replace('SourceMaps.compact().tiles[key]', 'SourceMaps.hasTile(key)'):
        raise ValueError('Hideout production diff exceeds membership read')
    expected = ('-- Frozen exact 952db34f projection; only owner identifier renamed.\n'
                + frozen.replace('RocketHideoutStoryWorld', 'GameCornerMembershipBaseline'))
    if (packet / 'baseline.lua').read_text() != expected:
        raise ValueError('frozen projection oracle changed')

    def overlay(source, *values, **options):
        original(source, *values, **options)
        shutil.copyfile(packet / 'baseline.lua', source / 'dev/gamecorner_membership_baseline.lua')
        shutil.copyfile(packet / 'contracts.lua', source / 'dev/gamecorner_membership_contracts.lua')
        with (source / 'main.lua').open('a') as stream:
            stream.write('\nimport "dev/gamecorner_membership_baseline"\n'
                         'import "dev/gamecorner_membership_contracts"\n'
                         'Contracts.register("gamecorner-membership", GameCornerMembershipContracts.run)\n')

    run.overlay_imports = overlay
    return run.run(argparse.Namespace(sdk=None, output=str(args.output), scenario=None,
        commands=['contracts gamecorner-membership'], timeout=180, ready_timeout=120,
        max_frames=1800, recent_interval=1, build_only=not args.execute, qualification=False))


if __name__ == '__main__':
    sys.exit(main())
