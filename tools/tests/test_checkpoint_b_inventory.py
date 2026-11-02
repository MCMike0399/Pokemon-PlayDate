"""Host release inventory checks; no runtime or controller installation claims."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from tools.activate_checkpoint_a import production_exclusions
from tools.activate_checkpoint_b import inventories, manifest
from tools.generate_source_map_cache import build

ROOT = Path(__file__).resolve().parents[2]


class CheckpointBInventory(unittest.TestCase):
    def test_exact_scope_and_unchanged_pinned_map_bytes(self):
        accepted, south = inventories()
        active = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
        self.assertEqual(active, manifest())
        self.assertEqual(len(active['maps']), 149)
        self.assertEqual(len(south), 41)
        for name, entry in active['maps'].items():
            original = subprocess.check_output(['git', 'show', '2dd9f3cc:Source/' + entry['path']], cwd=ROOT)
            self.assertEqual((ROOT / 'Source' / entry['path']).read_bytes(), original, name)
            self.assertEqual(hashlib.sha256(original).hexdigest(), entry['source_sha256'])
        for name, entry in accepted['maps'].items():
            self.assertEqual(active['maps'][name], entry)
        self.assertNotIn('Route16FlyHouse', active['maps'])
        self.assertFalse(any(n.startswith(('Saffron', 'SilphCo', 'FightingDojo')) for n in active['maps']))

    def test_binary_cells_and_runtime_records_have_exact_release_inventory(self):
        names = set(manifest()['maps'])
        self.assertEqual({p.stem for p in (ROOT / 'Source/data/sourceMapCells').glob('*.bin')}, names)
        self.assertEqual({p.stem.removeprefix('runtime-') for p in (ROOT / 'Source/data/sourceMapCache').glob('runtime-*.json')}, names)
        cells = {}
        generated = build(cell_artifacts=cells)
        for directory, records in [('sourceMapCache', generated), ('sourceMapCells', cells)]:
            self.assertEqual({p.name: p.read_bytes() for p in (ROOT / 'Source/data' / directory).iterdir()}, records)

    def test_production_scope_rejects_partial_extra_and_identity_drift(self):
        original = manifest()
        for mutation in ('partial', 'extra', 'path'):
            active = copy.deepcopy(original)
            if mutation == 'partial':
                del active['maps']['SafariZoneGate']
            elif mutation == 'extra':
                active['maps']['FutureMap'] = dict(active['maps']['Route12'])
            else:
                active['maps']['Route12']['path'] = 'data/midgameSaffron/SaffronCity.json'
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                target = root / 'Source/data'
                target.mkdir(parents=True)
                (target / 'sourceMaps.json').write_text(json.dumps(active))
                (target / 'midgameSouth').mkdir()
                (target / 'midgameSouth/manifest-entries.json').write_bytes((ROOT / 'Source/data/midgameSouth/manifest-entries.json').read_bytes())
                with self.assertRaises(ValueError):
                    production_exclusions(root)

    def test_b_policy_keeps_a_policy_and_excludes_future_content(self):
        policy = json.loads((ROOT / 'tools/integration/checkpoint-b/production-exclusions.json').read_bytes())
        self.assertEqual(production_exclusions(ROOT), policy['exclude'])
        self.assertIn('data/midgameSaffron/', policy['exclude'])
        self.assertIn('data/midgameSouth/Route16FlyHouse.json', policy['exclude'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'Source/data'
            target.mkdir(parents=True)
            (target / 'sourceMaps.json').write_text(json.dumps(inventories()[0]))
            (target / 'midgameSouth').mkdir()
            (target / 'midgameSouth/manifest-entries.json').write_bytes((ROOT / 'Source/data/midgameSouth/manifest-entries.json').read_bytes())
            expected = json.loads((ROOT / 'tools/integration/checkpoint-a/production-exclusions.json').read_bytes())['exclude']
            self.assertEqual(production_exclusions(root), expected)
