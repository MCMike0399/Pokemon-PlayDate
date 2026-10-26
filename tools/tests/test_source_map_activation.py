"""Activation witness inputs; behavioral checks execute only in the real SDK."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.generate_source_map_cache import build, canonical
from tools.source_map_fixture import records

ROOT = Path(__file__).resolve().parents[2]


class SourceMapActivationInputs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reference = os.environ.get('POKERED_REFERENCE_DIR')
        if not reference:
            raise RuntimeError('source the project environment before host checks')
        cls.fixture = records(reference)

    def test_sdk_witness_uses_the_exact_existing_pinned_extension_fixture(self):
        self.assertEqual((ROOT / 'Source/dev/sourceMapFixture.json').read_bytes(), canonical(self.fixture))
        maps = self.fixture['data/sourceMaps.json']['maps']
        self.assertEqual(len(maps), 31)
        self.assertEqual(maps['ViridianSchoolHouse']['profile'], 'source')
        self.assertEqual(maps['Route22']['profile'], 'source')
        active = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
        self.assertEqual(set(maps) - set(active), {'ViridianSchoolHouse'})
        self.assertEqual(len(active), 30)
        self.assertNotEqual(maps['Route22']['path'], active['Route22']['path'])
        self.assertEqual(active['Route22']['key'], 'kanto_route_22')

    def test_extension_reads_definitions_and_shared_manifest_without_regional_inventories(self):
        read = Path.read_bytes
        forbidden = {'descriptors.json', 'compact.json', 'tile-grids.json', 'doors.json', 'manifest.json'}
        def checked(path):
            if path.parent.name in {'pewterSlice', 'viridianSlice'}:
                self.assertNotIn(path.name, forbidden, str(path))
            return read(path)
        with patch.object(Path, 'read_bytes', checked):
            fixture = records(os.environ['POKERED_REFERENCE_DIR'])
        self.assertEqual(fixture, self.fixture)
        installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
        private = fixture['data/sourceMaps.json']['maps']
        self.assertEqual(set(private) - set(installed), {'ViridianSchoolHouse'})
        self.assertEqual(private['Route22']['key'], 'fixture_Route22')
        self.assertEqual(installed['ViridianCity']['blocked_connections'], ['west:ROUTE_22'])
        self.assertEqual(private['ViridianCity']['blocked_connections'], [])

    def test_warp_witness_coordinates_and_reciprocal_source_index_are_exact(self):
        compact = self.fixture['data/sourceMapCache/compact.json']['maps']
        school = compact['ViridianSchoolHouse']
        self.assertEqual([(w['x'], w['y'], w['destination']['warp_index']) for w in school['warps']],
                         [(4, 7, 3), (5, 7, 3)])
        self.assertEqual(school['last_outdoor'], 'ViridianCity')
        city = compact['ViridianCity']
        self.assertEqual(city['warps'][2]['destination']['map'], 'VIRIDIAN_SCHOOL_HOUSE')
        self.assertEqual((city['warps'][2]['x'], city['warps'][2]['y']), (21, 15))
        self.assertNotIn('pokered:VIRIDIAN_CITY:warps:3', city['blocked'].values())

    def test_connection_witnesses_have_real_available_targets_and_source_offsets(self):
        compact = self.fixture['data/sourceMapCache/compact.json']['maps']
        city = compact['ViridianCity']
        self.assertNotIn('north:ROUTE_2', city['blocked_connections'])
        self.assertEqual(next(c for c in city['connections'] if c['direction'] == 'west')['entry_lateral_adjustment_cells'], -8)
        route = compact['Route22']
        self.assertEqual(next(c for c in route['connections'] if c['direction'] == 'east')['entry_lateral_adjustment_cells'], 8)
        self.assertEqual(next(c for c in compact['Route2']['connections'] if c['direction'] == 'south')['entry_lateral_adjustment_cells'], 10)

    def test_shared_cache_encodes_blocked_available_warp_and_both_connection_directions(self):
        # Verify the fixture's controlled blocker variant through the actual
        # host cache generator. This checks inputs, not Lua runtime behavior.
        fixture = json.loads(canonical(self.fixture))
        manifest = fixture['data/sourceMaps.json']
        manifest['maps']['ViridianCity']['blocked_events'] = ['pokered:VIRIDIAN_CITY:warps:3']
        manifest['maps']['ViridianCity']['blocked_connections'].append('west:ROUTE_22')
        manifest['maps']['Route22']['blocked_connections'] = ['east:VIRIDIAN_CITY']
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            for entry in manifest['maps'].values():
                path = source / entry['path']
                path.parent.mkdir(parents=True, exist_ok=True)
                raw = canonical(fixture[entry['path']]) if entry['path'] in fixture else (ROOT / 'Source' / entry['path']).read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), entry['source_sha256'])
                path.write_bytes(raw)
            path = source / 'manifest.json'
            path.write_bytes(canonical(manifest))
            compact = json.loads(build(path, source)['compact.json'])['maps']
        city = compact['ViridianCity']
        self.assertEqual(city['blocked'][str(15 * city['width'] + 21 + 1)], 'pokered:VIRIDIAN_CITY:warps:3')
        self.assertIn('west:ROUTE_22', city['blocked_connections'])
        self.assertIn('east:VIRIDIAN_CITY', compact['Route22']['blocked_connections'])

if __name__ == '__main__':
    unittest.main()
