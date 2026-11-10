"""Pinned Blue negative warp proof and the unchanged accepted B boundary."""
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.generate_source_map_cache import (ROOT, CELL_HEADER, build, canonical,
                                             warp_authority, warp_classification)

B = 'bbb42aaadc41a0db3904eb83d27d83270cd704d4'
C = '8203e1192ad77a559305ebccd9c0d4f74e777c40'


def original(revision, path):
    return subprocess.check_output(['git', '-C', str(ROOT), 'show', revision + ':' + path])


class SourceWarpEligibility(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
        cls.compact = json.loads(build()['compact.json'])
        cls.authority = warp_authority()

    def test_complete_source_inventory_preserves_all_510_b_classifications(self):
        previous = json.loads(original(B, 'Source/data/sourceMaps.json'))
        checkpoint_c = set(json.loads(original(C, 'Source/data/sourceMaps.json'))['maps'])
        counts = Counter()
        b_counts = Counter()
        for name, entry in self.manifest['maps'].items():
            raw = (ROOT / 'Source' / entry['path']).read_bytes()
            if name in checkpoint_c:
                self.assertEqual(raw, original(C, 'Source/' + entry['path']))
            d = json.loads(raw)
            classifications = [warp_classification(d, event, self.authority)[0] for event in d['events']['warps']]
            counts.update(classifications)
            if name in previous['maps']:
                self.assertEqual(entry, previous['maps'][name])
                self.assertEqual(raw, original(B, 'Source/' + entry['path']))
                b_counts.update(classifications)
        self.assertEqual(b_counts, dict(standing_tile=220, function2=82, edge=208))
        self.assertEqual(counts, dict(standing_tile=369, function2=82, edge=256, non_triggering=2))

    def test_all_function2_overrides_and_ship3_function1_remain_conservative(self):
        self.assertEqual(self.authority['map_rules'], dict(SS_ANNE_3F='1', ROCKET_HIDEOUT_B1F='2',
            ROCKET_HIDEOUT_B2F='2', ROCKET_HIDEOUT_B4F='2', ROCK_TUNNEL_1F='2'))
        self.assertEqual(self.authority['tileset_rules'], dict(OVERWORLD='2', SHIP='2', SHIP_PORT='2', PLATEAU='2'))
        # Interior coordinate alone cannot negate an overworld/ship/gate warp.
        interior_without_standing = Counter()
        previous = json.loads(original(B, 'Source/data/sourceMaps.json'))
        for name, entry in previous['maps'].items():
            d = json.loads((ROOT / 'Source' / entry['path']).read_bytes())
            width, height = d['dimensions']['cells']
            for event in d['events']['warps']:
                classification, _ = warp_classification(d, event, self.authority)
                if classification == 'function2' and 0 < event['x'] < width - 1 and 0 < event['y'] < height - 1:
                    interior_without_standing[d['tileset']['constant']] += 1
        self.assertEqual(interior_without_standing, dict(OVERWORLD=44, SHIP=12, FACILITY=6, SHIP_PORT=1))

    def test_exact_two_inert_declarations_keep_coordinates_destination_and_floor(self):
        actual = {event: (name, metadata) for name, d in self.compact['maps'].items()
                  for event, metadata in d['non_triggering_warps'].items()}
        self.assertEqual(set(actual), {'pokered:SILPH_CO_11F:warps:3', 'pokered:SILPH_CO_1F:warps:5'})
        for name, index, foot, x, y in [('SilphCo11F', 3, 31, 5, 5), ('SilphCo1F', 5, 1, 16, 10)]:
            d = self.compact['maps'][name]
            event = d['warps'][index - 1]
            metadata = actual[event['id']][1]
            self.assertEqual((metadata['source_x'], metadata['source_y'], metadata['foot_tile']), (x, y, foot))
            self.assertEqual(metadata['edge_check'], 'function1_interior')
            self.assertNotIn(str(y * d['width'] + x + 1), d['blocked'])
            self.assertEqual(self.compact['tiles'][metadata['key']]['collision'], 0)
        self.assertIsNone(self.compact['maps']['SilphCo11F']['last_outdoor'])

    def test_scripted_inventory_preserves_15_and_adds_exact_owner_13(self):
        old = json.loads(original(C, 'Source/data/sourceMaps.json'))
        ids = lambda m: {id for entry in m['maps'].values() for id in entry.get('scripted_warps', [])}
        old_ids, new_ids = ids(old), ids(self.manifest)
        self.assertEqual(len(old_ids), 15)
        self.assertEqual(len(new_ids), 28)
        scenes = json.loads((ROOT / 'Source/data/silphStory/scenes.json').read_bytes())['scenes']
        expected = {row['map_id'] + ':warps:' + str(row['source_warp_byte'] + 1) for row in scenes['elevator']}
        expected.update('pokered:SILPH_CO_ELEVATOR:warps:' + str(i) for i in (1, 2))
        self.assertEqual(new_ids - old_ids, expected)
        self.assertTrue(old_ids <= new_ids)
        for name, d in self.compact['maps'].items():
            for event in d['warps']:
                if event['id'] in new_ids:
                    self.assertNotIn(str(event['y'] * d['width'] + event['x'] + 1), d['blocked'])
        for floor in (3, 5):
            event = self.compact['maps'][f'SilphCo{floor}F']['warps'][2]
            self.assertEqual((event['x'], event['y']), (20, 0))

    def test_blocked_and_scripted_inert_overlaps_fail_before_propagation(self):
        for field in ('blocked_events', 'scripted_warps'):
            manifest = copy.deepcopy(self.manifest)
            manifest['maps']['SilphCo11F'].setdefault(field, []).append('pokered:SILPH_CO_11F:warps:3')
            with self.subTest(field=field), tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / 'manifest.json'
                path.write_bytes(canonical(manifest))
                with self.assertRaisesRegex(ValueError, 'non-triggering warp sets overlap'):
                    build(path)

    def test_unavailable_target_cannot_turn_inert_floor_into_barrier(self):
        manifest = copy.deepcopy(self.manifest)
        del manifest['maps']['SilphCo3F']
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'manifest.json'
            path.write_bytes(canonical(manifest))
            compact = json.loads(build(path)['compact.json'])
        d = compact['maps']['SilphCo1F']
        self.assertNotIn('317', d['blocked'])  # source (16,10), width 30
        self.assertIn('pokered:SILPH_CO_1F:warps:5', d['non_triggering_warps'])

    def test_pinned_control_flow_mutation_fails_closed(self):
        from tools.generate_kanto_maps import Reference
        read = Reference.bytes
        def corrupt(reference, name):
            if name.endswith('player_state.asm'):
                # Exercise checksum validation, without touching shared references.
                reference.pins[name] = '0' * 64
            return read(reference, name)
        with patch.object(Reference, 'bytes', corrupt), self.assertRaisesRegex(ValueError, 'checksum'):
            build()

    def test_region_qualification_binds_fresh_export_to_copied_input_bytes(self):
        from tools.generate_region_registrations import build as qualify
        self.assertTrue(qualify())
        provenance = json.loads((ROOT / 'tools/references/content-transforms-149/provenance.json').read_bytes())
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            for name in provenance['dependencies']:
                target = source / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / 'Source' / name).read_bytes())
            manifest = source / 'data/sourceMaps.json'
            manifest.write_bytes(manifest.read_bytes() + b'\n')
            with self.assertRaisesRegex(ValueError, 'staged transform dependency changed: data/sourceMaps.json'):
                qualify(source_root=source)

    def test_prior_149_geometry_bindings_and_all_171_binary_cell_payloads_are_preserved(self):
        old = json.loads(original(C, 'Source/data/sourceMapCache/compact.json'))
        previous = json.loads(original(B, 'Source/data/sourceMaps.json'))['maps']
        changed = {}
        for name, d in self.compact['maps'].items():
            if name not in old['maps']:
                continue
            before = old['maps'][name]
            self.assertEqual(d['warps'], before['warps'])
            if before['blocked'] != d['blocked']:
                changed[name] = set(before['blocked']) - set(d['blocked'])
                self.assertEqual(set(d['blocked']) - set(before['blocked']), set())
            if name in previous:
                self.assertEqual({k: v for k, v in d.items() if k != 'non_triggering_warps'}, before)
            before_cells = original(C, 'Source/data/sourceMapCells/' + name + '.bin')
            after_cells = (ROOT / 'Source/data/sourceMapCells' / (name + '.bin')).read_bytes()
            self.assertEqual(before_cells[CELL_HEADER.size:], after_cells[CELL_HEADER.size:])
            self.assertEqual(CELL_HEADER.unpack_from(before_cells)[:4], CELL_HEADER.unpack_from(after_cells)[:4])
            self.assertEqual(CELL_HEADER.unpack_from(before_cells)[5], CELL_HEADER.unpack_from(after_cells)[5])
        self.assertEqual(changed, {**{f'SilphCo{floor}F': {str((21 if floor <= 5 else 19) if floor <= 9 else 13)}
                                                    for floor in range(1, 11)},
                                  'SilphCo11F': {'14', '96'}, 'SilphCoElevator': {'45', '46'}})
