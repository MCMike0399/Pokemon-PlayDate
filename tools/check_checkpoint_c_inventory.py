#!/usr/bin/env python3
"""Audit C data and optional production artifacts without starting a runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.activate_checkpoint_c import BASE, manifest
from tools.activate_checkpoint_a import production_exclusions
from tools.generate_content_cache import build as content_cache
from tools.generate_source_map_cache import build as map_cache, CELL_HEADER


def old(path):
    return subprocess.check_output(['git', '-C', str(ROOT), 'show', BASE + ':' + path])


def check(stage=None, bundle=None):
    expected = manifest()
    assert len(expected['maps']) == 171
    assert json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes()) == expected
    previous = json.loads(old('Source/data/sourceMaps.json'))
    cells = {}
    maps = map_cache(cell_artifacts=cells)
    content = content_cache()
    groups = [('sourceMapCache', maps), ('sourceMapCells', cells), ('contentCache', content)]
    locations = [ROOT / 'Source']
    if stage:
        locations.append(Path(stage) / 'Source')
    if bundle:
        locations.append(Path(bundle))
    for location in locations:
        assert json.loads((location / 'data/sourceMaps.json').read_bytes()) == expected
        for directory, files in groups:
            actual = {p.relative_to(location / 'data' / directory).as_posix(): p.read_bytes()
                      for p in (location / 'data' / directory).rglob('*') if p.is_file()}
            assert actual == files, (location, directory, 'generated release drift')
    for location in locations[1:]:
        for excluded in production_exclusions(ROOT) + ['dev/']:
            path = location / excluded.rstrip('/')
            assert not path.exists(), path
            if path.suffix == '.lua':
                assert not path.with_suffix('.pdz').exists(), path
        assert not any(p.name.startswith('proposed-') for p in location.rglob('*'))
    # All B map descriptors, runtime projections, cells and stable grids survive.
    for name, entry in previous['maps'].items():
        assert expected['maps'][name] == entry, name
        path = 'sourceMapCells/' + name + '.bin'
        before = old('Source/data/' + path)
        after = (ROOT / 'Source/data' / path).read_bytes()
        old_header = CELL_HEADER.unpack_from(before)
        new_header = CELL_HEADER.unpack_from(after)
        # The shared format pins the whole manifest in each header. Only that
        # checksum changes; dimensions, source pin and every cell stay exact.
        assert old_header[:4] == new_header[:4] and old_header[5] == new_header[5], path
        assert before[CELL_HEADER.size:] == after[CELL_HEADER.size:], path
        path = 'sourceMapCache/runtime-' + name + '.json'
        before = json.loads(old('Source/data/' + path))
        after = json.loads((ROOT / 'Source/data' / path).read_bytes())
        before.pop('manifest_sha256')
        after.pop('manifest_sha256')
        assert before == after, path
    old_grids = json.loads(old('Source/data/sourceMapCache/tile-grids.json'))
    new_grids = json.loads(maps['tile-grids.json'])
    assert old_grids.keys() == new_grids.keys()
    for field, values in old_grids.items():
        if isinstance(values, dict):
            assert all(new_grids[field].get(key) == value for key, value in values.items()), field
        elif field != 'manifest_sha256':
            assert new_grids[field] == values, field
    old_compact = json.loads(old('Source/data/sourceMapCache/compact.json'))
    new_compact = json.loads(maps['compact.json'])
    for name, before in old_compact['maps'].items():
        after = new_compact['maps'][name]
        if name == 'Route16':
            # Installing the real Fly house resolves its existing ingress.
            assert before['blocked'] == {'208': 'pokered:ROUTE_16:warps:9'}
            assert after['blocked'] == {}
            before = dict(before, blocked={})
        assert after['non_triggering_warps'] == {}, name
        assert before == {key: value for key, value in after.items() if key != 'non_triggering_warps'}, (name, 'prior compact descriptor drift')
    for key, tile in old_compact['tiles'].items():
        assert new_compact['tiles'][key] == tile, key
    callback_keys = set(json.loads((ROOT / 'Source/data/silphStory/tiles.json').read_bytes())['grids'][i]['stable_id']
                        for i in range(2))
    decoded_keys = set()
    for entry in expected['maps'].values():
        definition = json.loads((ROOT / 'Source' / entry['path']).read_bytes())
        decoded_keys.update(grid['stable_id'] for grid in definition['grids'])
    # Void adapter keys are supplied by the shared generator.
    extra_keys = set(new_grids['tiles']) - decoded_keys - set(old_grids['tiles'])
    assert extra_keys == callback_keys, extra_keys
    # Package numbers may move in the shared sorted catalog. B record digests do not.
    old_catalog = json.loads(old('Source/data/contentCache/catalog.json'))['packages']
    catalog = json.loads(content['catalog.json'])['packages']
    for root, name in old_catalog.items():
        before = json.loads(old('Source/data/contentCache/' + name + '.json'))
        after = json.loads(content[catalog[root] + '.json'])
        for record, fields in before['records'].items():
            for field, values in fields.items():
                assert all(after['records'][record][field].get(key) == value for key, value in values.items()), (root, record, field)
    assert 'data/midgameSaffron/' in catalog
    south = json.loads(content[catalog['data/midgameSouth/'] + '.json'])
    assert 'pokered:ROUTE_16_FLY_HOUSE:objects:1' in south['records']['events']['events']
    for entry in expected['maps'].values():
        definition = json.loads((ROOT / 'Source' / entry['path']).read_bytes())
        assert definition.get('encounters', {}).get('water', {}).get('rate_byte', 0) == 0
    # Compare owned changes after current-main synchronization. Main's newer
    # spinner/device observer changes are inherited, not C packet mutations.
    baseline = 'bbb42aaadc41a0db3904eb83d27d83270cd704d4'
    changed = subprocess.check_output(['git', '-C', str(ROOT), 'diff', '--name-only', baseline, '--', 'Source']).decode().splitlines()
    assert all(path.startswith(('Source/data/sourceMaps.json', 'Source/data/sourceMapCache/',
                               'Source/data/sourceMapCells/', 'Source/data/contentCache/',
                               'Source/data/silphStory/', 'Source/data/copycatService/',
                               'Source/game/copycatService.lua', 'Source/dev/copycatServiceContracts.lua',
                               'Source/world/sourceMaps.lua', 'Source/world/sourceBindings.lua',
                               'Source/dev/sourceMapContracts.lua', 'Source/dev/sourceMapFixture.json',
                               'Source/terrainAtlases/')) for path in changed), changed
    return dict(kind='host/compile-only C inventory; no native acceptance', base=BASE,
                integration_base=baseline, maps=171, prior_maps=149, added_maps=22,
                map_names=sorted(expected['maps']), prior_map_records_and_grids_preserved=True,
                prior_content_record_checksums_preserved=True,
                shared_runtime_changes=['generic private non-triggering warp lookup', 'enumerated inert warp binding'],
                prior_compact_geometry_exception='Route16 warp9 resolves installed Route16FlyHouse; blocked cell208 removed',
                added_callback_cells=sorted(callback_keys),
                schema_4_unchanged=True, blue_water_rates_zero=True,
                exclusions=production_exclusions(ROOT),
                generated_sha256={directory: {name: hashlib.sha256(raw).hexdigest() for name, raw in sorted(files.items())}
                                  for directory, files in groups})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path)
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(check(args.stage, args.bundle), indent=2) + '\n')
    print('Verified 171 candidate maps and preserved B records; no runtime executed.')
