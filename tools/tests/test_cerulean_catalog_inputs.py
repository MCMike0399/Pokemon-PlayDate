"""Independent pinned-input/Pillow witnesses; never execute or translate Lua."""
import hashlib
import json
import os
from pathlib import Path
import unittest
import tempfile

from PIL import Image
from tools import generate_overworld_sprites as protected_sprites

ROOT = Path(__file__).resolve().parents[2]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
MAPS = {'Route22', 'Route3', 'MtMoon1F', 'MtMoonB1F', 'MtMoonB2F', 'Route4',
        'MtMoonPokecenter', 'CeruleanCity', 'CeruleanGym', 'CeruleanPokecenter',
        'CeruleanMart', 'BikeShop', 'CeruleanTrashedHouse', 'Route24', 'Route25',
        'BillsHouse', 'Museum1F', 'Museum2F'}
SHADES = {255: '.', 170: '1', 85: '2', 0: '#'}


def record(path):
    data = json.loads((ROOT / path).read_bytes())
    if data['schema'] != 1 or data['source_revision'] != REVISION:
        raise ValueError('unverified source input')
    return data


def pinned_image(root, path, pins):
    payload = (root / path).read_bytes()
    if hashlib.sha256(payload).hexdigest() != pins[path]:
        raise ValueError('source checksum mismatch: ' + path)
    with Image.open(root / path) as image:
        image.load()
        return image.convert('L')


def inventory():
    """Source-derived declarations only; no claim about native PNG publication."""
    manifest = record('Source/data/sourceMaps.json')['maps']
    compact = record('Source/data/sourceMapCache/compact.json')
    source = record('Source/data/sourceSlice/sprites.json')['sprites']
    tutorial = record('Source/data/tutorialEscort/scenes.json')['art']
    legacy = {key for name, entry in manifest.items() if entry['profile'] in ('viridian', 'pewter')
              for key in compact['maps'][name]['palette']}
    new = {key for name in MAPS
           for key in compact['maps'][name]['palette']} - legacy
    result = {}

    def add(stem, width, height, category, mask=False):
        path = stem + '.png'
        if path in result:
            raise ValueError('duplicate source-derived path')
        result[path] = dict(path=path, width=width, height=height, category=category, mask=mask)

    def asset(stem, width, height, category, backgrounds=True):
        add(stem, width, height, category)
        add(stem + '__mask', width, height, category, True)
        if backgrounds:
            for background in ('white', 'black', 'texture'):
                add(stem + '__' + background, width, height, category + '-background')

    for key in new:
        asset('tile_imported_' + key.encode().hex(), 32, 32, 'imported-tile', False)
    for name in MAPS:
        d = compact['maps'][name]
        for kind in ('terrain', 'collision', 'actors', 'events'):
            add('cerulean-' + name + '-' + kind, d['width'] * 32, d['height'] * 32,
                'events-warps-connections' if kind == 'events' else kind)
        add('cerulean-' + name + '-viewport', 400, 240, 'map-viewport')
    for name, strip in source.items():
        asset('cerulean-strip-' + name, strip['size'][0] * 2, strip['size'][1] * 2, 'source-strip')
        for frame in strip['frames']:
            asset('cerulean-frame-' + name + '-' + frame, 32, 32, 'source-frame')
        for pose in ('stand', 'walk', 'alternate') if strip['walking'] else ('stand',):
            for direction in ('down', 'up', 'left', 'right'):
                asset('cerulean-pose-' + name + '-' + pose + '-' + direction, 32, 32, 'cerulean-character')
    for name, art in tutorial.items():
        asset('cerulean-tutorial-' + name, art['width'] * 2, art['height'] * 2, 'tutorial-source-art')
        if art['width'] == 16:
            for frame in range(art['height'] // 16):
                asset('cerulean-tutorial-' + name + '-frame-' + str(frame), 32, 32, 'tutorial-source-frame')
    return result, legacy, new


class CeruleanCatalogInputTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reference = os.environ.get('POKERED_REFERENCE_DIR')
        if not reference:
            raise RuntimeError('source ~/Developer/Pokemon-PlayDate-env/env.sh before host checks')
        cls.reference = Path(reference)
        cls.pins = json.loads((ROOT / 'tools/references/cerulean-content.json').read_bytes())['files']
        cls.tutorial_pins = {entry['path']: entry['sha256'] for entry in
                             json.loads((ROOT / 'tools/references/tutorial-escort.json').read_bytes())['files']}

    def test_explicit_inventory_has_no_protected_overlap_and_preserves_legacy_projection(self):
        images, legacy, new = inventory()
        self.assertEqual((len(images), len(legacy), len(new)), (2448, 145, 154))
        protected = json.loads((ROOT / 'docs/validation/catalog-pewter/catalog.json').read_bytes())['images']
        self.assertEqual(len(protected), 2494)
        self.assertFalse(images.keys() & {entry['path'] for entry in protected})
        compact = record('Source/data/sourceMapCache/compact.json')
        projected = {key: compact['tiles'][key] for key in legacy}
        digest = hashlib.sha256(json.dumps(projected, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(digest, 'fb7622c5ef2f96385441c9c437e02e36775d8b7add871ef749aa318fe3e851c0')
        manifest = record('Source/data/sourceMaps.json')['maps']
        self.assertEqual({name for name, entry in manifest.items()
                          if entry['path'].startswith('data/sourceSlice/')}, MAPS)
        self.assertEqual(sum(row['category'] == 'source-strip' and not row['mask'] for row in images.values()), 28)
        self.assertEqual(sum(row['category'] == 'source-frame' and not row['mask'] for row in images.values()), 124)
        self.assertEqual(sum(row['category'] == 'cerulean-character' and not row['mask'] for row in images.values()), 240)
        self.assertEqual(sum(row['category'] == 'map-viewport' for row in images.values()), 18)

    def test_every_actor_grid_matches_pinned_original_png_pixels(self):
        source = record('Source/data/sourceSlice/sprites.json')['sprites']
        self.assertEqual(len(source), 28)
        for name, strip in source.items():
            with self.subTest(actor=name):
                image = pinned_image(self.reference, strip['source'], self.pins)
                self.assertEqual(strip['sha256'], self.pins[strip['source']])
                self.assertEqual(list(image.size), strip['size'])
                self.assertEqual(set(strip['frames']), {str(index) for index in range(image.height // 16)})
                for index, grid in strip['frames'].items():
                    expected = [''.join(SHADES[image.getpixel((x, int(index)*16+y))] for x in range(16))
                                for y in range(16)]
                    self.assertEqual(grid, expected)
                for direction in ('down', 'up', 'left', 'right'):
                    actual_direction = 'down' if strip['fixed'] else 'left' if direction == 'right' else direction
                    self.assertIn(str(strip['standing'][actual_direction]), strip['frames'])
                    if strip['walking']:
                        self.assertIn(str(strip['walking'][actual_direction]), strip['frames'])

    def test_blue_world_family_has_the_same_pinned_input_and_greyhair_stands(self):
        strip = record('Source/data/sourceSlice/sprites.json')['sprites']['SPRITE_BLUE']
        pin = protected_sprites.load_manifest()
        protected = pin['characters']['rival']
        self.assertEqual(pin['commit'], REVISION)
        self.assertEqual(strip['sha256'], protected['sha256'])
        self.assertEqual(protected['mapping'], 'greyhair')
        image = pinned_image(self.reference, strip['source'], self.pins)
        canonical = protected_sprites.parse_grids(
            (ROOT / 'Source/world/sprites/rival.lua').read_text(), 'rival')
        greyhair = {255: '.', 170: '.', 85: '2', 0: '#'}
        for direction, index in strip['standing'].items():
            expected = [''.join(greyhair[image.getpixel((x, index*16+y))] for x in range(16))
                        for y in range(16)]
            self.assertEqual(canonical[direction], expected)
            self.assertEqual(protected_sprites.mask_bytes(canonical[direction]),
                             protected_sprites.mask_bytes(expected))
        # Additive walking inputs stay source-backed, with both white source
        # shades collapsed before the production mask is computed. Raw inputs
        # continue to be checked by the unmodified four-shade oracle above.
        for index in strip['walking'].values():
            expected = [''.join(greyhair[image.getpixel((x, index*16+y))] for x in range(16))
                        for y in range(16)]
            mapped = [row.replace('1', '.') for row in strip['frames'][str(index)]]
            self.assertEqual(mapped, expected)
            self.assertIn('2', ''.join(mapped))
            self.assertEqual(set(protected_sprites.mask_bytes(mapped)), {0, 255})

    def test_all_new_terrain_grids_match_independent_pillow_source_quadrants(self):
        checked = set()
        for name in MAPS:
            definition = record('Source/data/sourceSlice/' + name + '.json')
            image = pinned_image(self.reference, definition['tileset']['graphics'], self.pins)
            tiles_per_row = image.width // 8
            for entry in definition['grids']:
                ids = entry['source_tile_ids']
                rows = []
                for y in range(16):
                    row = ''
                    for x in range(16):
                        tile = ids[(y // 8)*2 + x // 8]
                        row += SHADES[image.getpixel(((tile % tiles_per_row)*8 + x % 8,
                                                     (tile // tiles_per_row)*8 + y % 8))]
                    rows.append(row)
                self.assertEqual(rows, entry['grid'], (name, entry['stable_id']))
                checked.add(entry['stable_id'])
        _, _, new = inventory()
        self.assertEqual(new - checked, {'adapter:source:void'})

    def test_missing_and_changed_pinned_pngs_fail_without_repair(self):
        path = 'gfx/sprites/blue.png'
        payload = (self.reference / path).read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(FileNotFoundError):
                pinned_image(root, path, self.pins)
            target = root / path
            target.parent.mkdir(parents=True)
            changed = payload + b'changed input'
            target.write_bytes(changed)
            with self.assertRaisesRegex(ValueError, 'source checksum mismatch'):
                pinned_image(root, path, self.pins)
            self.assertEqual(target.read_bytes(), changed)

    def test_tutorial_art_preserves_all_five_pinned_source_images(self):
        art = record('Source/data/tutorialEscort/scenes.json')['art']
        self.assertEqual(set(art), {'oldmanBack', 'weedle', 'gambler', 'sleepy', 'youngster'})
        for name, entry in art.items():
            image = pinned_image(self.reference, entry['source'], self.tutorial_pins)
            self.assertEqual(image.size, (entry['width'], entry['height']))
            rows = [''.join(SHADES[image.getpixel((x, y))] for x in range(image.width))
                    for y in range(image.height)]
            self.assertEqual(entry['rows'], rows, name)


if __name__ == '__main__':
    unittest.main()
