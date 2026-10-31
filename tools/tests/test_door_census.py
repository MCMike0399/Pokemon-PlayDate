"""Host-only inventory and evidence-rejection checks. No SDK/runtime substitute."""
from collections import Counter
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('door_census', Path(__file__).parents[1] / 'device/door_census.py')
census = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(census)
PROJECT = Path(os.environ.get('DOOR_CENSUS_PROJECT', Path(__file__).resolve().parents[2]))


class InventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inventory = census.build_inventory(PROJECT)
        cls.source = PROJECT / 'Source'
        cls.manifest = json.loads((cls.source / 'data/sourceMaps.json').read_text())['maps']
        cls.expected = {
            108: dict(warps=376, connections=43, boundary_cells=1274, last_map=128),
            149: dict(warps=510, connections=61, boundary_cells=1922, last_map=169),
        }[len(cls.manifest)]

    def test_every_pinned_map_and_warp_exactly_once(self):
        self.assertIn(len(self.manifest), (108, 149))
        expected = {}
        for name, entry in self.manifest.items():
            raw = json.loads((self.source / entry['path']).read_text())
            for warp in raw['events']['warps']:
                expected[warp['id']] = (name, warp['x']+entry['padding'], warp['y'], warp['destination'])
        actual = {r['id']: (r['source_name'], r['x'], r['y'], r['destination'])
                  for r in self.inventory['entries'] if r['kind'] == 'warp'}
        self.assertEqual(actual, expected)
        self.assertEqual(len(actual), self.expected['warps'])
        self.assertEqual({m['name'] for m in self.inventory['maps']}, set(self.manifest))

    def test_every_connection_covers_the_entire_declared_boundary(self):
        expected = {}
        for name, entry in self.manifest.items():
            raw = json.loads((self.source / entry['path']).read_text())
            for n, connection in enumerate(raw['connections'], 1):
                direction = connection['direction']
                if direction in ('north', 'south'):
                    positions = {(x, 0 if direction == 'north' else entry['height']-1) for x in range(entry['width'])}
                else:
                    positions = {(0 if direction == 'west' else entry['width']-1, y) for y in range(entry['height'])}
                expected[(name, n)] = positions
        actual = {}
        for row in self.inventory['entries']:
            if row['kind'] == 'connection':
                actual.setdefault((row['source_name'], row['connection_index']), set()).add((row['x'], row['y']))
        self.assertEqual(actual, expected)
        self.assertEqual(len(expected), self.expected['connections'])
        self.assertEqual(sum(map(len, actual.values())), self.expected['boundary_cells'])

    def test_last_map_scripted_and_blocked_are_retained_without_fabricated_targets(self):
        warps = [r for r in self.inventory['entries'] if r['kind'] == 'warp']
        self.assertEqual(sum(r['scripted'] for r in warps), 15)
        self.assertEqual(sum(r['surface_blocked'] for r in warps), 12)
        self.assertEqual(sum(r['destination']['kind']=='last_outdoor_map' for r in warps), self.expected['last_map'])
        for row in warps:
            self.assertNotIn('to', row)
            self.assertNotIn('toX', row)
            self.assertTrue(row['approaches'])
            if row['destination']['kind'] == 'last_outdoor_map' and not row['scripted'] and not row['declared_blocked']:
                self.assertIn(row['last_outdoor'], self.manifest)

    def test_source_collision_and_padding_independently_match_candidates(self):
        definitions = {name: json.loads((self.source / entry['path']).read_text()) for name, entry in self.manifest.items()}
        for row in self.inventory['entries']:
            if row['kind'] != 'warp':
                continue
            entry = self.manifest[row['source_name']]
            raw = definitions[row['source_name']]
            for approach in row['approaches']:
                x, y = approach['x']-entry['padding'], approach['y']
                inside = 0 <= x < raw['dimensions']['cells'][0] and 0 <= y < entry['height']
                if not inside or raw['collision'][y][x]:
                    self.assertIsNotNone(approach['geometry_gap'])

    def test_authored_portals_separate_and_all_case_ids_unique(self):
        entries = self.inventory['entries']
        self.assertEqual(len({r['id'] for r in entries}), len(entries))
        authored = [r for r in entries if r['kind'].startswith('authored')]
        self.assertEqual(Counter(r['kind'] for r in authored), {'authored_door': 11, 'authored_connection': 2})
        self.assertTrue(any(r['target_class']=='authored_seam' for r in entries))

    def test_raw_pin_corruption_is_rejected_before_inventory(self):
        with tempfile.TemporaryDirectory() as temp:
            project = Path(temp)
            source = project / 'Source'
            (source / 'data/sourceMapCache').mkdir(parents=True)
            for relative in ('data/sourceMaps.json', 'data/sourceMapCache/compact.json'):
                (source / relative).write_bytes((self.source / relative).read_bytes())
            first = self.manifest[sorted(self.manifest)[0]]
            target = source / first['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((self.source / first['path']).read_bytes()+b' ')
            with self.assertRaisesRegex(ValueError, 'pin mismatch'):
                census.build_inventory(project)

    def test_pin_corruption_and_unsupported_authored_syntax_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'data').mkdir()
            original = (self.source / 'data/maps.lua').read_text()
            (root / 'data/maps.lua').write_text(original.replace('to = "reds_house"', 'to = inventedDestination()'))
            (root / 'data/viridianSlice.lua').write_bytes((self.source / 'data/viridianSlice.lua').read_bytes())
            with self.assertRaisesRegex(ValueError, 'unsupported authored'):
                census.authored_inventory(root)


class ResultTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'runtime-data').mkdir()
        self.entry = dict(id='portal', kind='warp', x=1, y=2)
        census.write_json(self.root / 'inventory.json', dict(entries=[self.entry], maps=[]))
        self.metadata = dict(build_id='identity', selected_ids=['portal'], selected_cases=1)

    def write_rows(self, rows):
        (self.root / 'runtime-data/door-census.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))

    def test_missing_tail_is_explicit_and_never_complete(self):
        result = census.summarize(self.root, self.metadata, 'stopped child')
        self.assertFalse(result['complete'])
        self.assertEqual(result['counts'], {'not_run': 2})
        self.assertEqual({r['trial'] for r in result['rows']}, {1, 2})

    def test_gaps_do_not_rank_as_measurements(self):
        self.write_rows([dict(build_id='identity', id='portal', case_index=1, trial=1, status='gap', gap='actor required')])
        result = census.summarize(self.root, self.metadata)
        self.assertEqual(result['worst_wall'], [])
        self.assertEqual(result['counts'], {'gap': 1, 'not_run': 1})

    def test_forged_measured_status_has_no_completion_proof(self):
        self.write_rows([dict(build_id='identity', id='portal', case_index=1, trial=1, status='measured')])
        with self.assertRaisesRegex(ValueError, 'completion evidence'):
            census.summarize(self.root, self.metadata)

    def test_wrong_identity_duplicate_and_boolean_trial_fail(self):
        row = dict(build_id='identity', id='portal', case_index=1, trial=1, status='gap')
        for rows in ([dict(row, build_id='foreign')], [row, row], [dict(row, trial=True)]):
            with self.subTest(rows=rows):
                self.write_rows(rows)
                with self.assertRaises(ValueError):
                    census.summarize(self.root, self.metadata)

    def test_wrong_platform_trace_and_nonfinite_segments_fail(self):
        trace = self.root / 'runtime-data/boot-trace.tsv'
        trace.write_text('schema\t1\tbuild\tidentity\tplatform\tdevice\n')
        with self.assertRaisesRegex(ValueError, 'platform'):
            census.summarize(self.root, self.metadata)
        trace.unlink()
        (self.root / 'runtime-data/door-census-segments.tsv').write_text('identity\t1\t1\t1\tyield\tnan\t1\t1\t1\n')
        with self.assertRaisesRegex(ValueError, 'segment'):
            census.summarize(self.root, self.metadata)


if __name__ == '__main__':
    unittest.main()
