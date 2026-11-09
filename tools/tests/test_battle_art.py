import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tools/generate_battle_art.py'
spec = importlib.util.spec_from_file_location('battle_art', SCRIPT)
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


def original(size=40):
    image = Image.new('L', (size, size))
    image.putdata([sorted(art.PALETTE)[x*4//size] for y in range(size) for x in range(size)])
    return image


def png_bytes(image):
    output = io.BytesIO()
    image.save(output, format='PNG')
    return output.getvalue()


class BattleArtReproduction(unittest.TestCase):
    def test_native_threshold_contract_and_all_palette_search(self):
        source = original()
        target = art.threshold(source)
        self.assertEqual(target.mode, '1')
        self.assertEqual(target.size, (40, 40))
        for x in range(40):
            self.assertEqual(target.getpixel((x, 0)), 0 if x < 20 else 255)
        variants = list(art.binary_variants(source))
        self.assertEqual(len(variants), 37)  # 16 palettes, FS, 4+16 Bayer phases.
        exact = [name for name, image in variants if art.decoded_delta(target, image)['equal']]
        self.assertEqual(exact, ['palette-0011'])
        self.assertEqual(set(target.convert('RGBA').getchannel('A').getdata()), {255})

    def test_exact_pixels_and_alpha_mutations_are_separate_failures(self):
        expected = art.threshold(original()).convert('RGBA')
        changed = expected.copy()
        changed.putpixel((3, 7), (255, 255, 255, 255))
        delta = art.decoded_delta(expected, changed)
        self.assertFalse(delta['equal'])
        self.assertEqual(delta['changed_pixels'], 1)
        self.assertEqual(delta['mask_pixels'], 0)
        self.assertEqual(delta['bbox'], [3, 7, 4, 8])
        changed = expected.copy()
        changed.putpixel((3, 7), (0, 0, 0, 0))
        delta = art.decoded_delta(expected, changed)
        self.assertFalse(delta['equal'])
        self.assertEqual(delta['mask_pixels'], 1)
        self.assertEqual(delta['changed_pixels'], 1)

    def test_geometry_search_is_explicit_and_nearest_preserves_pixels(self):
        source = Image.new('1', (40, 40), 1)
        source.putpixel((10, 20), 0)
        self.assertEqual(art.geometry(source, 'crop-black').size, (1, 1))
        self.assertEqual(art.geometry(source, 'crop-center-native').getpixel((19, 19)), 0)
        self.assertEqual(art.geometry(source, 'crop-bottom-native').getpixel((19, 39)), 0)
        enlarged = art.geometry(source, 'nearest-2x')
        self.assertEqual(enlarged.size, (80, 80))
        self.assertEqual(enlarged.getpixel((20, 40)), 0)
        self.assertEqual(enlarged.getpixel((21, 41)), 0)
        self.assertEqual(art.decoded_delta(source, enlarged)['reason'], 'dimensions')

    def test_reference_checksum_palette_size_and_missing_input_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            data = png_bytes(original())
            (root / 'source.png').write_bytes(data)
            entry = {'path': 'source.png', 'kind': 'image', 'sha256': art.sha(data), 'size': [40, 40]}
            references = art.References({'revision': art.REVISION}, root=root)
            self.assertIn('source.png', art.verify_inputs({'inputs': [entry]}, references))
            (root / 'source.png').write_bytes(data + b'x')
            with self.assertRaisesRegex(ValueError, 'checksum'):
                art.verify_inputs({'inputs': [entry]}, references)
            with self.assertRaises(FileNotFoundError):
                references.read('missing.png')
            with self.assertRaises(ValueError):
                references.read('../outside.png')
            with self.assertRaisesRegex(ValueError, 'dimensions'):
                art.validate_reference(original(32), entry)
            with self.assertRaisesRegex(ValueError, 'four pinned'):
                art.validate_reference(Image.new('L', (40, 40), 0), entry)

    def test_trace_reports_one_pixel_defect_without_rewriting_target(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            inputs, source = root / 'refs', root / 'Source'
            inputs.mkdir(); (source / 'data').mkdir(parents=True); (source / 'images/pokemon').mkdir(parents=True)
            reference = png_bytes(original())
            (inputs / 'front.png').write_bytes(reference)
            aliases = b'{"schema":1,"aliases":{}}'
            (source / 'data/pokemon-art.json').write_bytes(aliases)
            target = art.threshold(original())
            protected = png_bytes(target)
            asset = {'species': 'bulbasaur', 'view': 'front', 'asset': 'bulbasaur-front.png',
                     'size': [40, 40], 'reference': 'front.png', 'reference_sha256': art.sha(reference), 'sha256': art.sha(protected)}
            manifest = {'revision': art.REVISION, 'runtime_aliases_sha256': art.sha(aliases), 'assets': [asset],
                        'inputs': [{'path': 'front.png', 'sha256': art.sha(reference), 'kind': 'image', 'size': [40, 40]}]}
            path = source / 'images/pokemon/bulbasaur-front.png'
            path.write_bytes(protected)
            reader = art.References(manifest, root=inputs)
            self.assertTrue(art.trace(manifest, reader, source)['ok'])
            target.putpixel((3, 7), 255)
            changed = png_bytes(target); path.write_bytes(changed)
            result = art.trace(manifest, reader, source)
            self.assertFalse(result['ok'])
            self.assertEqual(result['results'][0]['direct']['changed_pixels'], 1)
            self.assertEqual(result['results'][0]['direct']['bbox'], [3, 7, 4, 8])
            self.assertEqual(path.read_bytes(), changed)

    def test_archive_and_production_output_guards(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'wrong.tar.gz'
            archive.write_bytes(b'wrong archive')
            with self.assertRaisesRegex(ValueError, 'archive checksum'):
                art.References({'revision': art.REVISION, 'archive_sha256': '0'*64}, archive=archive)
            for path in (ROOT / 'Source', ROOT / 'Source/images/pokemon', ROOT / 'Source/../Source/world'):
                with self.assertRaisesRegex(ValueError, 'outside'):
                    art.safe_output(path)
            proc = subprocess.run([sys.executable, str(SCRIPT), '--check', '--archive', str(archive), '--output', str(Path(folder) / 'never')], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 1)
            self.assertFalse((Path(folder) / 'never').exists())
            report = subprocess.run([sys.executable, str(SCRIPT), '--check', '--archive', str(archive), '--report', str(ROOT / 'Source/images/pokemon/forbidden-report.json')], capture_output=True, text=True)
            self.assertEqual(report.returncode, 1)
            self.assertIn('outside', report.stdout)
            self.assertFalse((ROOT / 'Source/images/pokemon/forbidden-report.json').exists())

    def test_manifest_covers_current_302_protected_bytes_and_runtime_aliases(self):
        manifest = art.load_manifest()
        self.assertEqual(len(manifest['inputs']), 455)
        self.assertEqual(manifest['unchanged_since_import'], 302)
        aliases = json.loads((ROOT / 'Source/data/pokemon-art.json').read_text())['aliases']
        for item in manifest['assets']:
            self.assertEqual(item['asset'], aliases.get(item['species'], item['species']) + '-' + item['view'] + '.png')
            data = (ROOT / 'Source/images/pokemon' / item['asset']).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), item['sha256'])
            with Image.open(io.BytesIO(data)) as image:
                art.validate_target(image, item)
                self.assertEqual(hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest(), item['rgba_sha256'])


if __name__ == '__main__':
    unittest.main()
