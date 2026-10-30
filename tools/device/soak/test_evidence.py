"""Host rejection checks for raw soak evidence; never launch SDK/device."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools.device.soak.evidence import rows, console_rows
from tools.device.soak import lifecycle
from tools.device_cycle import tree_hash


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name).resolve()
        self.build = dict(build_id='test', earned_slots=[])
        (self.data/'soak-done.txt').write_text('test\n')
        common = dict(build='test', profile='simulator-short-v1', guard_checks=10000,
                      observed_heap_kib=4000, maximum_slice_ms=50, segments=4000,
                      guard_total_ms=10, guard_max_ms=1, scalar_total_ms=10, scalar_max_ms=1)
        def row(kind, clock, **values):
            return dict(common, kind=kind, clock_ms=clock, wall_seconds=str(1000000000+clock//1000), **values)
        self.records = [row('title-start', 0, sampler_version=3, phase_samples=1, sample_interval_ms=60000),
                        row('minute', 60000, phase='title', minute=1, state='title', loaded=0, saved=0, heap_kib=4000, elapsed_ms=60000, previous_sampler_ms=0),
                        row('continue-input', 60001, command='DS1 1 press a 1'),
                        row('overworld-start', 61000, zone='pallet', player={'moving': False}),
                        row('minute', 121000, phase='overworld', minute=1, state='overworld', loaded=1, saved=0, heap_kib=4000, elapsed_ms=60000, previous_sampler_ms=1, zone='pallet', player={'moving': False}),
                        row('complete', 121001, samples=2, idle_full_gc=0, sampler_total_ms=2, sampler_max_ms=1, sampler_last_ms=1),
                        row('safety', 121002, boundary='after complete IO and final game guard')]
        (self.data/'device-smoke-replies.jsonl').write_text('\n'.join(json.dumps(dict(build='test', seq=seq, status=status, value=value)) for seq, status, value in [(0, 'ready', 'ready'), (1, 'accepted', 'press'), (1, 'done', {'loaded': 1, 'saved': 0})]))
        (self.data/'boot-trace.tsv').write_text('schema\t1\tbuild\ttest\tplatform\tsimulator\n')

    def check_rows(self, records=None, short=True):
        (self.data/'soak-minute.jsonl').write_text('\n'.join(map(json.dumps, records or self.records)))
        (self.data/'soak-publication.json').write_text(json.dumps(dict(
            build='test', kind='publication', guard_after_safety=True,
            application_maximum_slice_ms=50, observer_ms=1, observed_heap_kib=4000)))
        return rows(self.data, self.build, short)

    def test_short_never_hardware_acceptance(self):
        self.assertFalse(self.check_rows()['hardware_soak_accepted'])
        with self.assertRaises(ValueError):
            self.check_rows(short=False)

    def test_rejects_corruption(self):
        cases = [(5, 'maximum_slice_ms', 151), (5, 'observed_heap_kib', 9217),
                 (4, 'elapsed_ms', 59999), (4, 'loaded', 0), (4, 'saved', 1),
                 (4, 'player', {'moving': True}), (5, 'sampler_total_ms', 3),
                 (0, 'profile', 'hardware-60+60'), (2, 'command', 'direct load'),
                 (3, 'build', 'other'), (5, 'kind', 'error'), (6, 'boundary', 'before completion'),
                 (6, 'maximum_slice_ms', 151), (6, 'observed_heap_kib', 9217)]
        for index, key, value in cases:
            with self.subTest(key=key, index=index):
                changed = copy.deepcopy(self.records)
                changed[index][key] = value
                with self.assertRaises((ValueError, KeyError)):
                    self.check_rows(changed)

    def test_missing_complete(self):
        with self.assertRaises(ValueError):
            self.check_rows(self.records[:-1])

    def test_first_minute_uses_phase_elapsed_before_start_row_publication(self):
        changed = copy.deepcopy(self.records)
        changed[0]['clock_ms'] = 109
        self.assertFalse(self.check_rows(changed)['hardware_soak_accepted'])
        changed[1]['elapsed_ms'] = 59999
        with self.assertRaises(ValueError):
            self.check_rows(changed)

    def test_console_filters_attached_hardware_without_hiding_current_duplicates(self):
        self.check_rows()
        publication = json.loads((self.data/'soak-publication.json').read_text())
        lines = ['SOAK1 '+json.dumps(row) for row in self.records]
        lines += ['SOAK-PUBLISHED '+json.dumps(publication), 'SOAK-DONE test',
                  'SOAK1 '+json.dumps({'build': 'attached-device'}),
                  'SOAK-PUBLISHED '+json.dumps({'build': 'attached-device'}),
                  'SOAK-DONE attached-device']
        log = self.data/'console.log'
        log.write_text('\n'.join(lines))
        console_rows(log, self.data)
        for duplicate in (lines[0], lines[7], 'SOAK-DONE test'):
            log.write_text('\n'.join(lines+[duplicate]))
            with self.assertRaises(ValueError):
                console_rows(log, self.data)

    def test_live_reservation_blocks_other_build_and_uncertain_collect(self):
        from types import SimpleNamespace
        manifest = {'build': self.build}
        record = dict(launch_output=str(self.data), build=self.build, manifest_sha256=tree_hash(manifest), state='running')
        path = self.data/'reservation.json'
        path.write_text(json.dumps(record))
        args = SimpleNamespace(soak_collect=None, soak_launch=False, soak_proof=None)
        cycle = SimpleNamespace(args=args)
        with patch.object(lifecycle, 'reservation_path', return_value=path):
            with self.assertRaises(ValueError):
                lifecycle.enter(cycle, manifest)
            args.soak_collect, args.soak_proof = str(self.data), 'proof'
            lifecycle.enter(cycle, manifest)
            record['state'] = 'collecting'
            path.write_text(json.dumps(record))
            with self.assertRaises(ValueError):
                lifecycle.enter(cycle, manifest)


if __name__ == '__main__':
    unittest.main()
