"""Validate content projection/checksums in Python; never execute game Lua."""
import copy
import hashlib
import json
import subprocess
from pathlib import Path
import tempfile
import unittest

from tools import generate_content_cache as generator

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source'
CACHE = SOURCE / 'data/contentCache'


class ContentCacheTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = generator.build()
        cls.pins = json.loads(generator.PINS.read_bytes())

    def decode(self, index, record, field):
        return {key: json.loads(self.files['chunks/' + digest + '.json'])
                for key, digest in index['records'][record][field].items()}

    def test_exact_generated_file_set_and_chunk_checksums(self):
        actual = {str(p.relative_to(CACHE)): p.read_bytes() for p in CACHE.rglob('*.json')}
        self.assertEqual(actual, self.files)
        for name, raw in self.files.items():
            if name.startswith('chunks/'):
                self.assertEqual(Path(name).stem, hashlib.sha256(raw).hexdigest())

    def test_every_package_field_round_trips_without_metadata_or_art_loss(self):
        catalog = json.loads(self.files['catalog.json'])
        self.assertEqual(set(catalog['packages']), set(self.pins['packages']))
        for root, name in catalog['packages'].items():
            index = json.loads(self.files[name + '.json'])
            for record, fields in index['records'].items():
                original = json.loads((SOURCE / root / (record + '.json')).read_bytes())
                for field in fields:
                    self.assertEqual(self.decode(index, record, field), original[field], (root, record, field))
            events = json.loads((SOURCE / root / 'events.json').read_bytes())
            trainers = json.loads((SOURCE / root / 'trainers.json').read_bytes())['trainers']
            expected = {key for key, event in events['events'].items() if event['kind'] == 'trainer'}
            self.assertEqual(set(index['ordinary_trainers']), expected)
            self.assertLessEqual(expected, trainers.keys())
            for field in ['events', 'signs']:
                self.assertEqual(index['items'][field], sorted(generator.item_ids(events[field])))
            self.assertEqual(index['trainer_flags'], {key: value['source_flag'] for key, value in trainers.items()
                                                     if value.get('source_flag')})

    def test_base_events_and_normalized_pewter_trainers_are_exact(self):
        index = json.loads(self.files['base.json'])
        original = json.loads((SOURCE / 'data/sourceEvents.json').read_bytes())['events']
        self.assertEqual(self.decode(index, 'events', 'events'), original)
        self.assertEqual(index['items']['events'], sorted(generator.item_ids(original)))
        meta = json.loads((SOURCE / 'data/pewterSlice/trainerNames.json').read_bytes())
        original = json.loads((SOURCE / 'data/pewterSlice/trainers.json').read_bytes())['trainers']
        expected = {d['id']: dict(d, name=meta['names'][d['class_source']], sprite_source=meta['sprites'][d['id']])
                    for d in original}
        self.assertEqual(self.decode(index, 'trainers', 'trainers'), expected)

    def test_pins_are_exact_starting_revision_inputs_and_map_activation_is_unchanged(self):
        for path, digest in self.pins['inputs'].items():
            baseline = subprocess.check_output(['git', 'show', 'd858032:Source/' + path])
            self.assertEqual(hashlib.sha256(baseline).hexdigest(), digest, path)
        manifest = SOURCE / 'data/sourceMaps.json'
        self.assertEqual(manifest.read_bytes(), subprocess.check_output(['git', 'show', 'd858032:Source/data/sourceMaps.json']))
        self.assertEqual(len(json.loads(manifest.read_bytes())['maps']), 65)

    def test_registered_package_event_and_trainer_membership_stays_disjoint(self):
        base = json.loads(self.files['base.json'])
        events = set(base['records']['events']['events'])
        trainers = set(base['records']['trainers']['trainers'])
        catalog = json.loads(self.files['catalog.json'])
        for root, name in catalog['packages'].items():
            index = json.loads(self.files[name + '.json'])
            for field in ['events', 'signs']:
                current = set(index['records']['events'][field])
                self.assertFalse(events & current)
                events.update(current)
            current = set(index['records']['trainers']['trainers'] if root == 'data/sourceSlice/'
                          else index['ordinary_trainers'])
            self.assertFalse(trainers & current)
            trainers.update(current)

    def test_shared_art_and_text_have_identical_canonical_checksums(self):
        catalog = json.loads(self.files['catalog.json'])
        seen = {}
        for name in catalog['packages'].values():
            data = json.loads(self.files[name + '.json'])
            for record, field in [('dialogue', 'texts'), ('sprites', 'sprites')]:
                for key, digest in data['records'][record][field].items():
                    identity = (record, key)
                    if identity in seen:
                        self.assertEqual(seen[identity], digest, identity)
                    seen[identity] = digest

    def test_any_changed_pinned_input_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for path in self.pins['inputs']:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((SOURCE / path).read_bytes())
            for path in self.pins['inputs']:
                target = root / path
                raw = target.read_bytes()
                target.write_bytes(raw + b' ')
                with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'checksum differs'):
                    generator.build(root)
                target.write_bytes(raw)

    def test_future_package_is_data_driven_without_activating_existing_packages(self):
        # A future checkpoint supplies an explicitly pinned package. It needs no
        # Lua bootstrap edits to generate its index, and does not enter today's pins.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            pins = copy.deepcopy(self.pins)
            for path in pins['inputs']:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((SOURCE / path).read_bytes())
            new_root = 'data/checkpointFuture/'
            pins['packages'].append(new_root)
            for name in ['dialogue', 'sprites', 'events', 'trainers']:
                old = 'data/sourceSlice/' + name + '.json'
                new = new_root + name + '.json'
                target = root / new
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((SOURCE / old).read_bytes())
                pins['inputs'][new] = pins['inputs'][old]
            pin_path = root / 'pins.json'
            pin_path.write_text(json.dumps(pins))
            files = generator.build(root, pin_path)
            catalog = json.loads(files['catalog.json'])
            self.assertIn(new_root, catalog['packages'])
            self.assertNotIn(new_root, self.pins['packages'])
            for name, raw in self.files.items():
                if name.startswith('chunks/'):
                    self.assertEqual(files[name], raw)


if __name__ == '__main__':
    unittest.main()
