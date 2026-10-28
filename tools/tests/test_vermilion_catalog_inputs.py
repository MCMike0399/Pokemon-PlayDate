"""Primary PNG/pin/declaration checks only. No Lua execution or SDK substitute."""
import hashlib
import json
import os
from pathlib import Path
import unittest

from PIL import Image
from tools.tests.test_cerulean_catalog_inputs import inventory as cerulean_inventory
from tools.tests.test_cerulean_catalog_inputs import pinned_image, record, SHADES

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = 'Source/data/vermilionPreparation/'
GRASS_SOURCE_FRAMES = (0, 7, 8, 15, 16, 23, 24, 31)
SHIP_FRAMES = (0, 4, 124, 130, 137, 138, 258, 770, 1153, 1154, 1156, 1276, 1280, 1283)


def inventory():
    """Independent inventory from package definitions, not Lua exporter counts."""
    maps = record(PACKAGE + 'manifest-entries.json')['maps']
    compact = record('Source/data/sourceMapCache/compact.json')
    old_images, old_tiles, cerulean_tiles = cerulean_inventory()
    old_actors = record('Source/data/sourceSlice/sprites.json')['sprites']
    actors = record(PACKAGE + 'sprites.json')['sprites']
    new_tiles = {key for name in maps for key in compact['maps'][name]['palette']} - old_tiles - cerulean_tiles
    images, shared = {}, {}

    def add(target, stem, width, height, category, mask=False):
        path = stem + '.png'
        if path in images or path in shared:
            raise ValueError('duplicate package path')
        target[path] = dict(path=path, width=width, height=height, category=category, mask=mask)

    def asset(target, stem, width, height, category, composites=True):
        add(target, stem, width, height, category)
        add(target, stem + '__mask', width, height, category, True)
        if composites:
            for background in ('white', 'black', 'texture'):
                add(target, stem + '__' + background, width, height, category + '-background')

    for name in maps:
        definition = record(PACKAGE + name + '.json')
        # Source geometry + adapter padding are independently pinned inputs.
        width, height = definition['dimensions']['cells']
        d = compact['maps'][name]
        if width != d['source_width'] or height > d['height']:
            raise ValueError('source map dimensions differ')
        for kind in ('terrain', 'collision', 'actors', 'events', 'viewport'):
            viewport = kind == 'viewport'
            add(images, 'vermilion-' + name + '-' + kind,
                400 if viewport else d['width'] * 32, 240 if viewport else d['height'] * 32,
                'map-viewport' if viewport else 'events-warps-connections' if kind == 'events' else kind)
    for key in new_tiles:
        asset(images, 'tile_imported_' + key.encode().hex(), 32, 32, 'imported-tile', False)
    for name, strip in actors.items():
        owner = 'cerulean' if name in old_actors else 'vermilion'
        target = shared if name in old_actors else images
        asset(target, owner + '-strip-' + name, strip['size'][0] * 2, strip['size'][1] * 2, 'source-strip')
        for frame in strip['frames']:
            asset(target, owner + '-frame-' + name + '-' + frame, 32, 32, 'source-frame')
        for pose in ('stand', 'walk', 'alternate') if strip['walking'] else ('stand',):
            for direction in ('down', 'up', 'left', 'right'):
                asset(target, owner + '-pose-' + name + '-' + pose + '-' + direction, 32, 32, owner + '-character')
    art = record('Source/data/vermilionShip/art.json')
    asset(images, 'vermilion-ship-hull', len(art['hull']['cells'][0]) * 32, len(art['hull']['cells']) * 32, 'ship-source-art')
    for name in ('smoke', 'water'):
        asset(images, 'vermilion-ship-' + name, 32, 32, 'ship-source-art')
    for frame in SHIP_FRAMES:
        add(images, 'vermilion-ship-frame-' + str(frame), art['map_width_cells'] * 32,
            art['band']['height_cells'] * 32, 'ship-presentation')
    for palette in (228, 128):
        asset(images, 'vermilion-cut-palette-' + str(palette), 32, 32, 'cut-source-art')
    for frame in range(record('Source/data/fieldMoves.json')['tree_frames']):
        add(images, 'vermilion-cut-frame-' + str(frame), 64, 32, 'cut-presentation')
    field = record('Source/data/fieldMoves.json')
    for palette in (228, 128):
        asset(images, 'vermilion-grass-leaf-palette-' + str(palette), 16, 16, 'grass-source-art')
    for frame in GRASS_SOURCE_FRAMES:
        add(images, 'vermilion-grass-source-frame-' + str(frame), 128, 96, 'grass-source-presentation')
    for update in range(field['grass_frames'] // 2):
        add(images, 'vermilion-grass-native-update-' + str(update), 128, 96, 'grass-native-presentation')
    return images, shared, new_tiles


class VermilionCatalogInputs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = Path(os.environ['POKERED_REFERENCE_DIR'])
        cls.pins = json.loads((ROOT / 'tools/references/vermilion-preparation.json').read_bytes())['files']

    def test_declaration_is_bounded_disjoint_and_shared_ownership_is_exact(self):
        images, shared, tiles = inventory()
        prior, _, _ = cerulean_inventory()
        protected = json.loads((ROOT / 'docs/validation/catalog-pewter/catalog.json').read_bytes())['images']
        self.assertFalse(images.keys() & prior.keys())
        self.assertFalse(images.keys() & {entry['path'] for entry in protected})
        self.assertTrue(shared.keys() <= prior.keys())
        for path, entry in shared.items():
            self.assertEqual(entry, prior[path])
        actors = record(PACKAGE + 'sprites.json')['sprites']
        old = record('Source/data/sourceSlice/sprites.json')['sprites']
        self.assertEqual(len(actors), 34)
        self.assertEqual(len(actors.keys() - old.keys()), 14)
        for actor in actors.keys() & old.keys():
            self.assertEqual(actors[actor], old[actor])
        maps = record(PACKAGE + 'manifest-entries.json')['maps']
        manifest = record('Source/data/sourceMaps.json')['maps']
        self.assertEqual({n for n, e in manifest.items() if e['path'].startswith('data/vermilionPreparation/')}, set(maps))
        self.assertEqual(len(maps), 35)
        # Reviewed host declaration fingerprint, computed from primary inputs.
        digest = hashlib.sha256(json.dumps(sorted(images.values(), key=lambda e: e['path']), sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(digest, 'e4c7d7340fefc9a5043cbd2e82d8f45be0685a6d45bab91ecf2a8fc370bb5065')
        old = {path: entry for path, entry in images.items() if not path.startswith('vermilion-grass-')}
        old_digest = hashlib.sha256(json.dumps(sorted(old.values(), key=lambda e: e['path']), sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(old_digest, 'ed4c3443850b40809237d923b45545e28c0de58b3a4c97d504b80c5d4aeda645')
        self.assertEqual(len(old), 1702)
        self.assertEqual(len(images) - len(old), 2 * 5 + 8 + 32 // 2)
        self.assertEqual(len(images), 1736)
        self.assertEqual(len(tiles), 190)

    def test_all_34_actor_strips_and_pose_indices_match_pinned_pngs(self):
        for source, strip in record(PACKAGE + 'sprites.json')['sprites'].items():
            with self.subTest(source=source):
                image = pinned_image(self.reference, strip['source'], self.pins)
                self.assertEqual(strip['sha256'], self.pins[strip['source']])
                self.assertEqual(list(image.size), strip['size'])
                self.assertEqual(set(strip['frames']), {str(i) for i in range(image.height // 16)})
                for index, rows in strip['frames'].items():
                    self.assertEqual(rows, [''.join(SHADES[image.getpixel((x, int(index) * 16 + y))]
                                                    for x in range(16)) for y in range(16)])
                for poses in (strip['standing'], strip['walking']):
                    for index in poses.values():
                        self.assertIn(str(index), strip['frames'])
        blue = record(PACKAGE + 'sprites.json')['sprites']['SPRITE_BLUE']
        self.assertEqual(blue, record('Source/data/sourceSlice/sprites.json')['sprites']['SPRITE_BLUE'])

    def test_all_package_terrain_grids_match_original_png_quadrants(self):
        checked = set()
        for name in record(PACKAGE + 'manifest-entries.json')['maps']:
            definition = record(PACKAGE + name + '.json')
            image = pinned_image(self.reference, definition['tileset']['graphics'], self.pins)
            for entry in definition['grids']:
                ids = entry['source_tile_ids']
                expected = []
                for y in range(16):
                    row = ''
                    for x in range(16):
                        tile = ids[(y // 8) * 2 + x // 8]
                        row += SHADES[image.getpixel(((tile % (image.width // 8)) * 8 + x % 8,
                                                     (tile // (image.width // 8)) * 8 + y % 8))]
                    expected.append(row)
                self.assertEqual(entry['grid'], expected, (name, entry['stable_id']))
                checked.add(entry['stable_id'])
        self.assertFalse(inventory()[2] - checked)

    def test_cerulean_helpers_preserve_default_package_and_raw_paths(self):
        text = (ROOT / 'Source/dev/ceruleanCatalogExporter.lua').read_text()
        self.assertIn('return CeruleanCatalogExporter.poseInventory(actors(), "cerulean")', text)
        self.assertIn('(packagePrefix or "cerulean")', text)
        self.assertIn('scriptPath or "data/sourceSlice/scripts.json"', text)
        self.assertIn('assert(#result.images == 2448', text)
        self.assertIn('local prefix = "data/sourceSlice/"', text)


if __name__ == '__main__':
    unittest.main()
