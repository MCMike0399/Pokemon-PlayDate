#!/usr/bin/env python3
"""Check an explicitly staged 149-map B release. This never starts a runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.activate_checkpoint_b import manifest
from tools.activate_checkpoint_a import production_exclusions
from tools.generate_content_cache import build as content_cache
from tools.generate_source_map_cache import build as map_cache


def check(stage, bundle):
    source = Path(stage) / 'Source'
    bundle = Path(bundle)
    expected = manifest()
    assert len(expected['maps']) == 149
    assert json.loads((source / 'data/sourceMaps.json').read_bytes()) == expected
    assert json.loads((bundle / 'data/sourceMaps.json').read_bytes()) == expected
    cells = {}
    maps = map_cache(cell_artifacts=cells)
    content = content_cache()
    for directory, files in [('sourceMapCache', maps), ('sourceMapCells', cells), ('contentCache', content)]:
        for location in (source, bundle):
            actual = {p.relative_to(location / 'data' / directory).as_posix(): p.read_bytes()
                      for p in (location / 'data' / directory).rglob('*') if p.is_file()}
            assert actual == files, (location, directory, 'generated release drift')
    for excluded in production_exclusions(ROOT):
        for location in (source, bundle):
            path = location / excluded.rstrip('/')
            assert not path.exists(), path
            if path.suffix == '.lua':
                assert not path.with_suffix('.pdz').exists(), path
    for location in (source, bundle):
        assert not (location / 'dev').exists()
        assert not any(p.name.startswith('proposed-') for p in location.rglob('*'))
    for name, entry in expected['maps'].items():
        raw = (ROOT / 'Source' / entry['path']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == entry['source_sha256'], name
        definition = json.loads(raw)
        water = definition.get('encounters', {}).get('water', {})
        assert water.get('rate_byte', 0) == 0, (name, 'Blue active water rate')
    catalog = json.loads(content['catalog.json'])
    assert 'data/midgameSaffron/' not in catalog['packages']
    south = json.loads(content[catalog['packages']['data/midgameSouth/'] + '.json'])
    assert 'pokered:ROUTE_16_FLY_HOUSE:objects:1' not in south['records']['events']['events']
    return dict(kind='compile-only B release inventory; runtime integration remains pending',
                maps=149, accepted_maps=108, added_maps=41, parked=['Route16FlyHouse'],
                map_names=sorted(expected['maps']), binary_cells=len(cells), map_artifacts=len(maps),
                content_artifacts=len(content), blue_water_rates_zero=True,
                exclusions=production_exclusions(ROOT),
                generated_sha256={directory: {name: hashlib.sha256(raw).hexdigest() for name, raw in sorted(files.items())}
                                  for directory, files in [('sourceMapCache', maps), ('sourceMapCells', cells), ('contentCache', content)]})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = check(args.stage, args.bundle)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print('Verified 149 maps, 149 binary cell records and scoped content in staged Source and compiled PDX.')
