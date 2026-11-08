"""Host-only inventory and evidence-rejection checks. No SDK/runtime substitute."""
from collections import Counter
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
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
            108: dict(warps=376, connections=43, boundary_cells=1274, last_map=128,
                      scripted=15, surface_blocked=12),
            149: dict(warps=510, connections=61, boundary_cells=1922, last_map=169,
                      scripted=15, surface_blocked=12),
            # Independently counted from all 171 pinned decoded maps. C adds
            # eleven lift entrances and two cabin exits; the 11F correction
            # retains its source warp without the old floor barrier.
            171: dict(warps=637, connections=65, boundary_cells=2074, last_map=188,
                      scripted=28, surface_blocked=11),
        }[len(cls.manifest)]

    def test_every_pinned_map_and_warp_exactly_once(self):
        self.assertIn(len(self.manifest), (108, 149, 171))
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
        self.assertEqual(sum(r['scripted'] for r in warps), self.expected['scripted'])
        self.assertEqual(sum(r['surface_blocked'] for r in warps), self.expected['surface_blocked'])
        self.assertEqual(sum(r['destination']['kind']=='last_outdoor_map' for r in warps), self.expected['last_map'])
        for row in warps:
            self.assertNotIn('to', row)
            self.assertNotIn('toX', row)
            self.assertTrue(row['approaches'])
            if row['destination']['kind'] == 'last_outdoor_map' and not row['scripted'] and not row['declared_blocked']:
                # pokered maps/objects/SilphCo11F.asm: warp 3 is "LAST_MAP ; inaccessible".
                if row['id'] == 'pokered:SILPH_CO_11F:warps:3':
                    self.assertIsNone(row['last_outdoor'])
                    self.assertFalse(row['destination']['resolved'])
                else:
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

    def test_observer_collection_boundary_preserves_active_segment_inventory(self):
        path = self.root / 'runtime-data/door-census-segments.tsv'
        path.write_text('identity\t1\t1\t1\tobserver-boundary\t2.5\t3\t10.0\t1\n'
                        'identity\t1\t1\t2\tyield\t1.0\t4\t20.0\t1\n')
        _, segments = census.read_observations(self.root, self.metadata)
        self.assertEqual([r['kind'] for r in segments[(1, 1)]], ['observer-boundary', 'yield'])
        self.assertEqual(sum(r['active_ms'] for r in segments[(1, 1)]), 3.5)

    def test_short_binary_segments_keep_precision_without_relaxing_validation(self):
        data = self.root / 'runtime-data'
        (data / 'boot-trace.tsv').write_text(
            'schema\t1\tbuild\tidentity\tplatform\tsimulator\n'
            'sequence\tphase\tclock\tsince_yield\tphase_ms\theap\tpeak\n'
            '1\tdoor.map.begin\t0\t0\t0\t1\t1\n'
            '2\tdoor.map.end\t100\t0\t100\t1\t1\n')
        row = dict(build_id='identity', id='portal', case_index=1, trial=1,
                   status='measured', target_cache='cold', trace_begin=0, trace_end=2,
                   trigger={'source_event_id': 'portal'},
                   resolved={'to': 'target', 'x': 3, 'y': 4},
                   arrived={'zone_id': 'target', 'x': 3, 'y': 4},
                   input_completion_verified=True, door_entries=1, input_frames=1,
                   wall_ms=100, active_ms=62.5, max_segment_ms=.0625,
                   post_gc_lua_heap_kib=1)
        self.write_rows([row])
        def segments(precision):
            (data / 'door-census-segments.tsv').write_text(''.join(
                f'identity\t1\t1\t{i+1}\tobserver-boundary\t{.0625:.{precision}f}\t1\t{i/10:.6f}\t1\n'
                for i in range(1000)))
        segments(3)
        with self.assertRaisesRegex(ValueError, 'segment totals disagree'):
            census.summarize(self.root, self.metadata)
        segments(6)
        result = census.summarize(self.root, self.metadata)
        self.assertEqual(result['counts'], {'measured': 1, 'not_run': 1})

    def test_host_limits_stop_memory_growth_and_nonprogress(self):
        census.check_host_limits(census.MAX_PROCESS_BYTES, 60)
        with self.assertRaisesRegex(RuntimeError, 'host footprint'):
            census.check_host_limits(census.MAX_PROCESS_BYTES + 1, 0)
        with self.assertRaisesRegex(RuntimeError, 'completed census row'):
            census.check_host_limits(1, 60.001)

    def test_real_host_footprint_is_available_for_owned_process(self):
        self.assertGreater(census.process_footprint(os.getpid()), 0)

    def test_history_pause_requires_exact_identity_and_trial_order(self):
        self.assertEqual(census.validate_history_pause({'build': 'id', 'rows': 0}, 'id', -1, 4), 0)
        self.assertEqual(census.validate_history_pause({'build': 'id', 'rows': 1}, 'id', 0, 4), 1)
        self.assertEqual(census.validate_history_pause({'build': 'id', 'rows': 2}, 'id', 1, 4), 2)
        for value in ({'build': 'other', 'rows': 2}, {'build': 'id', 'rows': True},
                      {'build': 'id', 'rows': 0}, {'build': 'id', 'rows': 4},
                      {'build': 'id', 'rows': 2, 'extra': True}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                census.validate_history_pause(value, 'id', 0, 4)

    def test_history_pause_cannot_exceed_selected_case_count(self):
        with self.assertRaises(ValueError):
            census.validate_history_pause({'build': 'id', 'rows': 6}, 'id', 4, 4)

    def test_inspection_never_borrows_previous_capture(self):
        (self.root / 'malloc-log-inspection.png').write_bytes(b'old image')
        self.assertIsNone(census.inspection_capture('[]', self.root))
        path = self.root / 'malloc-log-inspection-12345678-1234-1234-1234-123456789abc.png'
        row = {'scope': 'inspection capture', 'path': str(path), 'returncode': '1'}
        with self.assertRaises(ValueError):
            census.inspection_capture(json.dumps([row]), self.root)
        row['returncode'] = '0'
        with self.assertRaises(ValueError):
            census.inspection_capture(json.dumps([row]), self.root)
        path.write_bytes(b'\x89PNG\r\n\x1a\nnew image')
        self.assertEqual(census.inspection_capture(json.dumps([row]), self.root), path)

    def test_inspection_rejects_foreign_or_legacy_capture_path(self):
        path = self.root / 'malloc-log-inspection.png'
        path.write_bytes(b'\x89PNG\r\n\x1a\nold image')
        row = {'scope': 'inspection capture', 'path': str(path), 'returncode': '0'}
        with self.assertRaises(ValueError):
            census.inspection_capture(json.dumps([row]), self.root)

    @unittest.skipUnless(sys.platform == 'darwin', 'Darwin kernel ownership proof')
    def test_history_lock_reports_parent_pid_and_excludes_existing_bsd_owners(self):
        from tools.harness.protocol import OwnerLock
        path = self.root / 'kernel-owner.lock'
        query = '''import fcntl,os,struct,sys,json
fd=os.open(sys.argv[1],os.O_RDONLY)
value=fcntl.fcntl(fd,fcntl.F_GETLK,struct.pack('qqihh',0,0,0,fcntl.F_WRLCK,os.SEEK_SET))
print(json.dumps(struct.unpack('qqihh',value)))
'''
        bsd = "import fcntl,sys; f=open(sys.argv[1],'a+'); fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)"
        posix = "import fcntl,sys; f=open(sys.argv[1],'a+'); fcntl.lockf(f,fcntl.LOCK_EX|fcntl.LOCK_NB)"
        with census.census_lock(OwnerLock, path, True):
            value = json.loads(subprocess.check_output([sys.executable, '-c', query, str(path)], text=True))
            self.assertEqual(value[:3], [0, 0, os.getpid()])
            blocked = subprocess.run([sys.executable, '-c', bsd, str(path)], capture_output=True, text=True)
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn('BlockingIOError', blocked.stderr)
        with OwnerLock(path):
            blocked = subprocess.run([sys.executable, '-c', posix, str(path)], capture_output=True, text=True)
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn('BlockingIOError', blocked.stderr)
        value = json.loads(subprocess.check_output([sys.executable, '-c', query, str(path)], text=True))
        self.assertEqual(value[3], census.fcntl.F_UNLCK)

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
