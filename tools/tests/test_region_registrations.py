"""Generated declarations preserve actual SDK outputs; no host Lua execution."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools import generate_region_registrations as generator

ROOT = Path(__file__).resolve().parents[2]


class RegionRegistrationTests(unittest.TestCase):
    def test_transformed_records_and_rosters_equal_actual_sdk_export(self):
        files = generator.build(ROOT)
        for name in ('midgameEast',):
            declaration = json.loads(files[name + '.json'])
            exported = json.loads((ROOT / 'tools/references/content-transforms-108' / (name + '.json')).read_bytes())
            for stable, record in exported['events'].items():
                digest = declaration['records'][stable]
                self.assertEqual(json.loads(files['chunks/' + digest + '.json']), record)
            self.assertEqual(set(declaration['trainers']), set(exported['trainers']))
            for stable, record in exported['trainers'].items():
                digest = declaration['trainers'][stable]
                if isinstance(record, str):
                    self.assertEqual(digest, record)
                else:
                    self.assertEqual(json.loads(files['chunks/' + digest + '.json']), record)
        memberships = [set(json.loads(files[name + '.json'])['records'])
                       for name in ('vermilion', 'midgameEast')]
        self.assertFalse(memberships[0] & memberships[1])

    def test_dependency_drift_cannot_be_relabelled_as_the_old_export(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            shutil.copytree(ROOT / 'Source', project / 'Source')
            shutil.copytree(ROOT / 'tools/references', project / 'tools/references')
            owner = project / 'Source/game/hideoutTowerContent.lua'
            owner.write_bytes(owner.read_bytes() + b'\n-- changed producer\n')
            with self.assertRaisesRegex(ValueError, 'dependency changed'):
                generator.build(project)

    def test_generation_is_deterministic_and_all_new_chunks_are_content_addressed(self):
        first, second = generator.build(ROOT), generator.build(ROOT)
        self.assertEqual(first, second)
        for name, raw in first.items():
            if name.startswith('chunks/'):
                self.assertEqual(Path(name).stem, hashlib.sha256(raw).hexdigest())
