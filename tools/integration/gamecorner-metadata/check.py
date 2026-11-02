#!/usr/bin/env python3
"""Private SDK metadata differential. Compile-only unless Root passes --execute."""
import argparse
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.harness import run


def source_ids(source):
    ids = set()
    manifest = json.loads((source / 'data/sourceMaps.json').read_bytes())
    for entry in manifest['maps'].values():
        record = json.loads((source / entry['path']).read_bytes())
        for events in record['events'].values():
            for event in events:
                ids.add(event['id'])
    return sorted(ids)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    original = run.overlay_imports
    packet = Path(__file__).parent

    def overlay(source, *values, **options):
        original(source, *values, **options)
        shutil.copyfile(packet / 'baseline.lua', source / 'dev/gamecorner_metadata_baseline.lua')
        shutil.copyfile(packet / 'contracts.lua', source / 'dev/gamecorner_metadata_contracts.lua')
        (source / 'dev/gamecorner_metadata_ids.json').write_text(json.dumps(source_ids(source)) + '\n')
        with (source / 'main.lua').open('a') as stream:
            stream.write('\nimport "dev/gamecorner_metadata_baseline"\n'
                         'import "dev/gamecorner_metadata_contracts"\n'
                         'Contracts.register("gamecorner-metadata", GameCornerMetadataContracts.run)\n')

    run.overlay_imports = overlay
    return run.run(argparse.Namespace(sdk=None, output=str(args.output), scenario=None,
        commands=['contracts gamecorner-metadata'], timeout=180, ready_timeout=120,
        max_frames=1800, recent_interval=1, build_only=not args.execute, qualification=False))


if __name__ == '__main__':
    sys.exit(main())
