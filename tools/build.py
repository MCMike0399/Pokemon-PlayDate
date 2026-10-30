#!/usr/bin/env python3
"""Compile a production bundle from a private source tree without dev modules."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.harness.run import sdk_path, fingerprint
from tools.activate_checkpoint_a import production_exclusions, ignored_source_names

PROJECT = Path(__file__).resolve().parents[1]


def qualify_shipped_maps(source, stage):
    """Check the copied immutable inputs before allowing the device fast path."""
    from tools.generate_source_map_cache import build as generate_maps, check
    policy = source / 'game/shippedDataPolicy.lua'
    if not policy.is_file():
        return None  # Older/minimal projects retain their original deep path.
    text = policy.read_text()
    marker = 'local mapsQualified <const> = false'
    if text.count(marker) != 1:
        raise ValueError('shipped map policy must start unqualified')
    cells = {}
    manifest = source / 'data/sourceMaps.json'
    artifacts = generate_maps(manifest, source, cell_artifacts=cells)
    check(artifacts, source / 'data/sourceMapCache')
    check(cells, source / 'data/sourceMapCells')
    record = dict(schema=1, maps=len(json.loads(manifest.read_bytes())['maps']),
                  manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest(),
                  artifacts={name: hashlib.sha256(raw).hexdigest()
                             for name, raw in sorted(artifacts.items())},
                  binary_cells={name: hashlib.sha256(raw).hexdigest()
                                for name, raw in sorted(cells.items())})
    (stage / 'shipped-map-qualification.json').write_text(json.dumps(record, indent=2) + '\n')
    policy.write_text(text.replace(marker, 'local mapsQualified <const> = true'))
    return record


def qualify_shipped_content(project, source, stage):
    """Qualify immutable package agreement from pinned, copied content bytes."""
    from tools.generate_content_cache import build as generate_content
    pins = Path(project) / 'tools/references/content-cache.json'
    policy = source / 'game/shippedDataPolicy.lua'
    if not pins.is_file() or not policy.is_file():
        return None
    text = policy.read_text()
    marker = 'local immutableContentQualified <const> = false'
    if text.count(marker) != 1:
        raise ValueError('shipped immutable-content policy must start unqualified')
    artifacts = generate_content(source, pins)
    cache = source / 'data/contentCache'
    actual = {path.relative_to(cache).as_posix(): path.read_bytes()
              for path in cache.rglob('*.json')}
    if actual != artifacts:
        raise ValueError('generated immutable content cache drift')
    record = dict(schema=1, pins_sha256=hashlib.sha256(pins.read_bytes()).hexdigest(),
                  artifacts={name: hashlib.sha256(raw).hexdigest()
                             for name, raw in sorted(artifacts.items())})
    (stage / 'shipped-content-qualification.json').write_text(json.dumps(record, indent=2) + '\n')
    policy.write_text(text.replace(marker, 'local immutableContentQualified <const> = true'))
    return record


def qualify_region_declarations(project, source, stage):
    from tools.generate_region_registrations import build as generate_declarations
    reference = Path(project) / 'tools/references/content-transforms-108/provenance.json'
    if not reference.is_file():
        return None
    files = generate_declarations(project)
    for name, raw in files.items():
        path = source / 'data/regionDeclarations' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    policy = source / 'game/shippedDataPolicy.lua'
    text = policy.read_text()
    marker = 'local regionDeclarationsQualified <const> = false'
    if text.count(marker) != 1:
        raise ValueError('region declarations must start unqualified')
    policy.write_text(text.replace(marker, 'local regionDeclarationsQualified <const> = true'))
    record = {name: hashlib.sha256(raw).hexdigest() for name, raw in files.items()}
    (stage / 'region-declarations-qualification.json').write_text(json.dumps(record, indent=2) + '\n')
    return record


def stage_production(project, stage):
    source = stage / 'Source'
    original = project / 'Source'
    excluded = production_exclusions(project)
    shutil.copytree(original, source, ignore=lambda directory, names:
                    ignored_source_names(original, directory, names, excluded))
    qualify_shipped_maps(source, stage)
    qualify_shipped_content(project, source, stage)
    qualify_region_declarations(project, source, stage)
    return source


def compile_production(project, sdk, output, stage):
    if output.suffix != '.pdx':
        raise ValueError('production output must have .pdx suffix')
    source = stage_production(project, stage)
    bundle = stage / 'Production.pdx'
    with (stage / 'build.log').open('w') as log:
        subprocess.run([str(sdk / 'bin/pdc'), str(source), str(bundle)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    if (bundle / 'dev').exists():
        raise ValueError('production bundle contains dev modules')
    # Publish a fresh bundle: pdc does not remove files from previous builds.
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(bundle, output)
    (stage / 'build.json').write_text(json.dumps({
        'mode': 'production', 'source_sha256': fingerprint(stage, exclude_generated=False),
        'sdk_version': (sdk / 'VERSION.txt').read_text().strip(),
        'bundle': str(output), 'excluded': ['Source/dev'],
    }, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk')
    parser.add_argument('--output', default='PokemonPoC.pdx')
    parser.add_argument('--stage', help='retain source and build log in this new directory')
    args = parser.parse_args()
    sdk = sdk_path(args.sdk)
    output = Path(args.output).expanduser().resolve()
    if args.stage:
        stage = Path(args.stage).expanduser().resolve()
        stage.mkdir(parents=True, exist_ok=False)
        compile_production(PROJECT, sdk, output, stage)
    else:
        with tempfile.TemporaryDirectory(prefix='pokemon-production-') as temporary:
            compile_production(PROJECT, sdk, output, Path(temporary))


if __name__ == '__main__':
    main()
