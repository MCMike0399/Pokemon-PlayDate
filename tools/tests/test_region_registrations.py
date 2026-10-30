"""Generated declarations preserve actual SDK outputs; no host Lua execution."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

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

    def test_staged_owner_and_import_drift_are_rejected_with_unchanged_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            staged = Path(directory) / 'Source'
            shutil.copytree(ROOT / 'Source', staged)
            owner = staged / 'game/hideoutTowerContent.lua'
            original = owner.read_bytes()
            owner.write_bytes(original + b'\n-- copied owner changed\n')
            with self.assertRaisesRegex(ValueError, 'dependency changed'):
                generator.build(ROOT, source_root=staged)
            owner.write_bytes(original)
            main = staged / 'main.lua'
            main.write_text(main.read_text() + '\nimport "game/silphStory"\n')
            with self.assertRaisesRegex(ValueError, 'owner imports changed'):
                generator.build(ROOT, source_root=staged)

    def test_staging_race_rejects_copied_owner_and_import_drift(self):
        from tools import build
        original_copy = shutil.copytree
        for relative, suffix, reason in (
                ('game/hideoutTowerContent.lua', '\n-- copied owner differs\n', 'dependency changed'),
                ('main.lua', '\nimport "game/silphStory"\n', 'owner imports changed')):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as directory:
                stage = Path(directory)
                def copy_changed(source, destination, *args, **kwargs):
                    result = original_copy(source, destination, *args, **kwargs)
                    if Path(source) == ROOT / 'Source':
                        path = Path(destination) / relative
                        path.write_text(path.read_text() + suffix)
                    return result
                with mock.patch.object(build.shutil, 'copytree', side_effect=copy_changed):
                    with self.assertRaisesRegex(ValueError, reason):
                        build.stage_production(ROOT, stage)
                self.assertIn('regionDeclarationsQualified <const> = false',
                              (stage / 'Source/game/shippedDataPolicy.lua').read_text())

    def test_qualification_rejects_changed_staged_cache_before_setting_trust(self):
        from tools.build import qualify_region_declarations
        with tempfile.TemporaryDirectory() as directory:
            stage = Path(directory)
            source = stage / 'Source'
            shutil.copytree(ROOT / 'Source', source)
            artifacts = {path.relative_to(source / 'data/contentCache').as_posix():
                         hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in (source / 'data/contentCache').rglob('*.json')}
            cache = source / 'data/contentCache/catalog.json'
            cache.write_bytes(cache.read_bytes() + b' ')
            with self.assertRaisesRegex(ValueError, 'copied content cache drift'):
                qualify_region_declarations(ROOT, source, stage, {'artifacts': artifacts})
            self.assertIn('regionDeclarationsQualified <const> = false',
                          (source / 'game/shippedDataPolicy.lua').read_text())

    def test_generation_is_deterministic_and_all_new_chunks_are_content_addressed(self):
        first, second = generator.build(ROOT), generator.build(ROOT)
        self.assertEqual(first, second)
        for name, raw in first.items():
            if name.startswith('chunks/'):
                self.assertEqual(Path(name).stem, hashlib.sha256(raw).hexdigest())
