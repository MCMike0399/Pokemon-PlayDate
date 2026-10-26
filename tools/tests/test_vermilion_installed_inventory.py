"""Installed inventory proposal checks, using real pinned data/cache generation."""
import json
import os
import shutil
import tempfile
from unittest.mock import patch
from pathlib import Path
import unittest

from tools import generate_vermilion_preparation as g


class VermilionInstalledInventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifacts = g.build(Path(os.environ['POKERED_REFERENCE_DIR']))
        cls.promoted = json.loads(cls.artifacts['proposed-source-maps.json'])

    def manifest(self):
        return json.loads(g.canonical(self.promoted))

    def test_uninstalled_and_fully_installed_inputs_build_the_same_shared_proposal(self):
        active = json.loads((g.ROOT / 'Source/data/sourceMaps.json').read_bytes())
        active['maps'] = {name: entry for name, entry in active['maps'].items() if name not in g.MAPS}
        self.assertFalse(g.verify_installed_entries(self.artifacts, active))
        self.assertTrue(g.verify_installed_entries(self.artifacts, self.promoted))
        expected = {name: raw for name, raw in self.artifacts.items() if name.startswith('proposed-')}
        self.assertEqual(g.proposed_pipeline(self.artifacts, manifest=self.promoted), expected)
        self.assertEqual(len(self.promoted['maps']), 65)

    def test_full_build_accepts_an_installed_manifest_in_a_private_source_inventory(self):
        # A real filesystem inventory, not an SDK or Lua substitute. Only the
        # regional generator's root is scoped; active project bytes stay put.
        active = json.loads((g.ROOT / 'Source/data/sourceMaps.json').read_bytes())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = root / 'Source/data/sourceMaps.json'
            manifest.parent.mkdir(parents=True)
            manifest.write_bytes(g.canonical(self.promoted))
            for entry in active['maps'].values():
                target = root / 'Source' / entry['path']
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(g.ROOT / 'Source' / entry['path'], target)
            for path in ['tools/generate_kanto_maps.py', 'tools/generate_cerulean_content.py',
                         'tools/generate_viridian_slice.py', 'tools/generate_source_map_cache.py']:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(g.ROOT / path, target)
            with patch.object(g, 'ROOT', root):
                actual = g.build(Path(os.environ['POKERED_REFERENCE_DIR']))
                self.assertTrue(g.verify_installed_entries(actual))
            self.assertEqual(actual, self.artifacts)
            self.assertEqual(manifest.read_bytes(), g.canonical(self.promoted))

    def test_installed_mode_preserves_root_blockers_last_map_and_existing_entries(self):
        manifest = self.manifest()
        manifest['maps']['VermilionGym']['blocked_events'] = ['pokered:VERMILION_GYM:warps:1']
        manifest['maps']['VermilionDock']['last_outdoor'] = 'VermilionCity'
        before = g.canonical(manifest)
        generated = g.proposed_pipeline(self.artifacts, manifest=manifest)
        self.assertEqual(g.canonical(manifest), before)
        self.assertEqual(json.loads(generated['proposed-source-maps.json']), manifest)
        compact = json.loads(generated['proposed-compact.json'])
        self.assertTrue(compact['maps']['VermilionGym']['blocked'])
        self.assertEqual(compact['maps']['VermilionDock']['last_outdoor'], 'VermilionCity')
        self.assertEqual(compact['tiles']['pokered:GYM:cell:20-21-30-31']['collision'], 1)
        self.assertIn('pokered:GYM:cell:20-21-30-31', json.loads(generated['proposed-tile-grids.json'])['tiles'])

    def test_partial_inventory_is_rejected_without_overwriting_it(self):
        manifest = self.manifest()
        del manifest['maps']['SSAnneBow']
        before = g.canonical(manifest)
        with self.assertRaisesRegex(ValueError, 'partial installed Vermilion inventory'):
            g.proposed_pipeline(self.artifacts, manifest=manifest)
        self.assertEqual(g.canonical(manifest), before)

    def test_owned_fields_keep_strict_identity_geometry_pin_and_spawn_guards(self):
        for field in ['id', 'key', 'path', 'profile', 'width', 'height', 'padding', 'source_sha256', 'spawn']:
            with self.subTest(field=field):
                manifest = self.manifest()
                manifest['maps']['VermilionGym'][field] = None
                before = g.canonical(manifest)
                with self.assertRaisesRegex(ValueError, 'installed Vermilion entry drift: VermilionGym:' + field):
                    g.proposed_pipeline(self.artifacts, manifest=manifest)
                self.assertEqual(g.canonical(manifest), before)

    def test_original_strict_artifact_preservation_verifier_is_unchanged(self):
        g.verify(self.artifacts, g.OUTPUT)
        changed = dict(self.artifacts)
        changed['VermilionGym.json'] += b' '
        with self.assertRaisesRegex(ValueError, 'artifact drift'):
            g.verify(changed, g.OUTPUT)

    def test_installed_proposal_never_changes_the_current_active_map_files(self):
        paths = [g.ROOT / 'Source/data/sourceMaps.json',
                 g.ROOT / 'Source/data/sourceMapCache/compact.json',
                 g.ROOT / 'Source/data/sourceMapCache/tile-grids.json']
        before = [path.read_bytes() for path in paths]
        g.proposed_pipeline(self.artifacts, manifest=self.promoted)
        self.assertEqual([path.read_bytes() for path in paths], before)
        self.assertEqual(len(json.loads(before[0])['maps']), 65)

if __name__ == '__main__':
    unittest.main()
