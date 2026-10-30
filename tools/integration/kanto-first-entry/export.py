#!/usr/bin/env python3
"""Private Kanto SDK export. Default compiles only; --execute is Root-only."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.harness import run
from tools.generate_region_registrations import KANTO_DEPENDENCIES, KANTO_OWNERS


def collect(output):
    metadata = json.loads((output / 'build.json').read_bytes())
    if metadata['sdk_version'] != '3.1.2':
        raise ValueError('Kanto export requires SDK 3.1.2')
    if run.fingerprint(output, exclude_generated=False) != metadata['compiled_source_sha256']:
        raise ValueError('compiled export Source changed')
    data = output / 'runtime-data/kanto-first-entry.json'
    raw = data.read_bytes()
    packet = json.loads(raw)
    if packet['build_id'] != metadata['build_id'] or packet['simulator'] is not True:
        raise ValueError('SDK export identity mismatch')
    report = json.loads((output / 'outcome.json').read_bytes())
    if report.get('ok') is not True or report.get('session_id') != metadata['session_id']:
        raise ValueError('identified export harness did not complete')
    manifest = json.loads((output / 'source-manifest.json').read_bytes())
    dependencies = {}
    for name in KANTO_DEPENDENCIES:
        digest = hashlib.sha256((output / 'Source' / name).read_bytes()).hexdigest()
        if digest != manifest[name]:
            raise ValueError('copied export dependency changed: ' + name)
        dependencies[name] = digest
    cache = {}
    for name, digest in manifest.items():
        if name.startswith('data/contentCache/'):
            if hashlib.sha256((output / 'Source' / name).read_bytes()).hexdigest() != digest:
                raise ValueError('copied export cache changed: ' + name)
            cache[name.removeprefix('data/contentCache/')] = digest
    provenance = dict(schema=1, sdk_version=metadata['sdk_version'], content_cache=cache,
                      producer=str(output), build_id=packet['build_id'],
                      producer_build_sha256=hashlib.sha256((output / 'build.json').read_bytes()).hexdigest(),
                      producer_result_sha256=hashlib.sha256((output / 'outcome.json').read_bytes()).hexdigest(),
                      dependencies=dependencies, export_sha256=hashlib.sha256(raw).hexdigest(),
                      content_pins_sha256=hashlib.sha256((ROOT / 'tools/references/content-cache.json').read_bytes()).hexdigest(),
                      owner_imports=[name for name in re.findall(r'import "([^"]+)"',
                          (output / 'original-main.lua').read_text()) if name in KANTO_OWNERS])
    destination = Path(__file__).with_name('qualified')
    destination.mkdir(exist_ok=False)
    (destination / 'export.json').write_bytes(raw)
    (destination / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--collect', action='store_true')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if args.collect:
        if args.execute:
            parser.error('--collect does not execute a runtime')
        collect(output)
        return 0
    original_overlay = run.overlay_imports
    hook = Path(__file__).with_name('export.lua')
    def overlay(source, *values, **options):
        original_overlay(source, *values, **options)
        shutil.copyfile(hook, source / 'dev/kanto_first_entry_export.lua')
        with (source / 'main.lua').open('a') as stream:
            stream.write('\nimport "dev/kanto_first_entry_export"\n')
    run.overlay_imports = overlay
    return run.run(argparse.Namespace(sdk=None, output=str(output), scenario=None,
        commands=['gamestate'], timeout=180, ready_timeout=120, max_frames=1800,
        recent_interval=1, build_only=not args.execute, qualification=False))


if __name__ == '__main__':
    sys.exit(main())
