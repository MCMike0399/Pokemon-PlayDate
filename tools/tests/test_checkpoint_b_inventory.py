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
from tools.activate_checkpoint_c import manifest as checkpoint_c, BASE as CURRENT_BASE
from tools.activate_endgame import ENDGAME
from tools.activate_remainder import REMAINDER, manifest as current_manifest
from tools.generate_source_map_cache import build

ROOT = Path(__file__).resolve().parents[2]


class CheckpointBInventory(unittest.TestCase):
    def test_exact_scope_and_unchanged_pinned_map_bytes(self):
        accepted, south = inventories()
        active = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
        checkpoint_b = manifest()
        self.assertEqual(active, current_manifest())
        prior = checkpoint_c()
        self.assertEqual(len(active['maps']), 222)
        self.assertEqual(len(prior['maps']), 171)
        self.assertEqual(len(checkpoint_b['maps']), 149)
        self.assertEqual({name: active['maps'][name] for name in checkpoint_b['maps']}, checkpoint_b['maps'])
        self.assertEqual({name: active['maps'][name] for name in prior['maps']}, prior['maps'])
        self.assertEqual(len(south), 41)
        for name, entry in prior['maps'].items():
            original = subprocess.check_output(['git', 'show', CURRENT_BASE + ':Source/' + entry['path']], cwd=ROOT)
            self.assertEqual((ROOT / 'Source' / entry['path']).read_bytes(), original, name)
            self.assertEqual(hashlib.sha256(original).hexdigest(), entry['source_sha256'])
        for name in set(active['maps']) - set(prior['maps']):
            entry = active['maps'][name]
            raw = (ROOT / 'Source' / entry['path']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), entry['source_sha256'], name)
            if name in REMAINDER:
                prefix = 'data/zRemainder/'
            elif name in ENDGAME:
                prefix = 'data/zEndgame/'
            else:
                prefix = 'data/zCoast/'
            self.assertTrue(entry['path'].startswith(prefix), name)
        for name, entry in accepted['maps'].items():
            self.assertEqual(active['maps'][name], entry)
        self.assertNotIn('Route16FlyHouse', checkpoint_b['maps'])
        self.assertFalse(any(n.startswith(('Saffron', 'SilphCo', 'FightingDojo')) for n in checkpoint_b['maps']))
        self.assertEqual(len(set(active['maps']) - set(checkpoint_b['maps'])), 73)

    def test_binary_cells_and_runtime_records_have_exact_release_inventory(self):
        names = set(current_manifest()['maps'])
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
        current_policy = json.loads((ROOT / 'tools/integration/remainder/production-exclusions.json').read_bytes())
        self.assertEqual(production_exclusions(ROOT), current_policy['exclude'])
        self.assertIn('data/midgameSaffron/', policy['exclude'])
        self.assertIn('data/midgameSouth/Route16FlyHouse.json', policy['exclude'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'Source/data'
            target.mkdir(parents=True)
            (target / 'sourceMaps.json').write_text(json.dumps(manifest()))
            (target / 'midgameSouth').mkdir()
            (target / 'midgameSouth/manifest-entries.json').write_bytes((ROOT / 'Source/data/midgameSouth/manifest-entries.json').read_bytes())
            self.assertEqual(production_exclusions(root), policy['exclude'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'Source/data'
            target.mkdir(parents=True)
            (target / 'sourceMaps.json').write_text(json.dumps(inventories()[0]))
            (target / 'midgameSouth').mkdir()
            (target / 'midgameSouth/manifest-entries.json').write_bytes((ROOT / 'Source/data/midgameSouth/manifest-entries.json').read_bytes())
            expected = json.loads((ROOT / 'tools/integration/checkpoint-a/production-exclusions.json').read_bytes())['exclude']
            self.assertEqual(production_exclusions(root), expected)
