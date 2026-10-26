"""Pinned inputs and generated content; all runtime assertions belong to SDK."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from PIL import Image
from tools import generate_cerulean_content as generator
from tools.generate_source_map_cache import check as cache_check

ROOT = generator.ROOT


class CeruleanContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        reference = os.environ.get('POKERED_REFERENCE_DIR')
        if not reference:
            raise RuntimeError('source ~/Developer/Pokemon-PlayDate-env/env.sh before host tests')
        cls.reference = Path(reference)
        cls.artifacts = generator.build(cls.reference)
        cls.maps = {name: json.loads(cls.artifacts[name + '.json']) for name in generator.MAPS}
        cls.events = json.loads(cls.artifacts['events.json'])
        cls.trainers = json.loads(cls.artifacts['trainers.json'])
        cls.texts = json.loads(cls.artifacts['dialogue.json'])['texts']
        cls.scripts = json.loads(cls.artifacts['scripts.json'])
        cls.pin = json.loads(generator.PIN.read_bytes())
        cls.manifest = json.loads((ROOT / 'Source/data/ceruleanSourceMaps.json').read_bytes())

    def test_generator_and_candidate_cache_are_exact_and_deterministic(self):
        self.assertEqual(self.artifacts, generator.build(self.reference))
        generator.verify(self.artifacts, generator.OUTPUT)
        manifest = generator.candidate_manifest(self.artifacts)
        self.assertEqual(manifest, (ROOT / 'Source/data/ceruleanSourceMaps.json').read_bytes())
        cache_check(generator.candidate_cache(manifest), ROOT / 'Source/data/ceruleanMapCache')

    def test_all_consumed_files_match_exact_revision_and_checked_pins(self):
        self.assertEqual(subprocess.check_output(['git', '-C', str(self.reference), 'rev-parse', 'HEAD'], text=True).strip(), generator.REVISION)
        consumed = json.loads(self.artifacts['provenance.json'])['source_files']
        self.assertEqual(consumed, self.pin['files'])
        subprocess.run(['git', '-C', str(self.reference), 'diff', '--exit-code', generator.REVISION, '--', *consumed], check=True, capture_output=True)
        for path, digest in consumed.items():
            self.assertEqual(hashlib.sha256((self.reference / path).read_bytes()).hexdigest(), digest, path)

    def test_inventory_matches_source_names_and_has_no_regional_geometry(self):
        expected = {'Route22', 'Route3', 'MtMoon1F', 'MtMoonB1F', 'MtMoonB2F', 'Route4',
                    'MtMoonPokecenter', 'CeruleanCity', 'CeruleanGym', 'CeruleanPokecenter',
                    'CeruleanMart', 'BikeShop', 'CeruleanTrashedHouse', 'Route24', 'Route25',
                    'BillsHouse', 'Museum1F', 'Museum2F'}
        self.assertEqual(set(self.maps), expected)
        active = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
        self.assertEqual(set(self.manifest['maps']) - set(active['maps']), expected)
        for name in expected:
            entry = self.manifest['maps'][name]
            self.assertEqual(entry['profile'], 'source')
            self.assertEqual(entry['path'], f'data/sourceSlice/{name}.json')
            self.assertEqual(entry['source_sha256'], generator.digest(self.artifacts[name + '.json']))

    def test_existing_manifest_cache_and_art_are_untouched(self):
        paths = ['Source/data/sourceMaps.json', 'Source/data/sourceMapCache',
                 'Source/data/viridianSlice', 'Source/data/pewterSlice', 'Source/world/sprites',
                 'Source/world/tilefactory.lua', 'Source/lib/shade.lua', 'Source/images']
        subprocess.run(['git', 'diff', '--exit-code', '9f3e37b', '--', *paths], cwd=ROOT, check=True, capture_output=True)

    def test_candidate_preserves_every_old_blocked_surface_and_boundary_gate(self):
        old = json.loads((ROOT / 'Source/data/sourceMapCache/compact.json').read_bytes())
        new = json.loads((ROOT / 'Source/data/ceruleanMapCache/compact.json').read_bytes())
        for name, descriptor in old['maps'].items():
            self.assertEqual(new['maps'][name]['blocked'], descriptor['blocked'])
        self.assertIn('east:ROUTE_3', new['maps']['PewterCity']['blocked_connections'])
        self.assertIn('west:ROUTE_22', new['maps']['ViridianCity']['blocked_connections'])
        self.assertIn('north:ROUTE_2', new['maps']['ViridianCity']['blocked_connections'])

    def test_each_cell_uses_original_block_quadrants_and_original_png_pixels(self):
        # Independent geometry/art oracle: byte indexing and Pillow, rather than
        # the generator's PNG decoder, tile composition or quadrant helpers.
        codes = {255: '.', 170: '1', 85: '2', 0: '#'}
        for name, definition in self.maps.items():
            layout_binding = re.search(rf'{name}_Blocks:(?:[^\n]*\n)*?[^\n]*INCBIN "([^"]+)"',
                                       (self.reference / 'maps.asm').read_text())
            self.assertIsNotNone(layout_binding, name)
            layout = (self.reference / layout_binding[1]).read_bytes()
            blocks = (self.reference / definition['tileset']['blockset']).read_bytes()
            image = Image.open(self.reference / definition['tileset']['graphics']).convert('L')
            width, height = definition['dimensions']['cells']
            self.assertEqual(len(layout), width * height // 4)
            for y in range(height):
                for x in range(width):
                    offset = y // 2 * (width // 2) + x // 2
                    block = layout[offset]
                    quadrant = y % 2 * 2 + x % 2
                    self.assertEqual(definition['source_refs'][y][x], [offset, block, quadrant])
                    top = block * 16 + y % 2 * 8 + x % 2 * 2
                    ids = [blocks[top], blocks[top + 1], blocks[top + 4], blocks[top + 5]]
                    grid = definition['grids'][definition['tile_ids'][y][x] - 1]
                    self.assertEqual(grid['source_tile_ids'], ids)
                    self.assertEqual(definition['collision'][y][x], int(not grid['terrain']['land_passable']))
            for grid in definition['grids']:
                expected = []
                for y in range(16):
                    row = ''
                    for x in range(16):
                        tile = grid['source_tile_ids'][y // 8 * 2 + x // 8]
                        row += codes[image.getpixel((tile % (image.width // 8) * 8 + x % 8,
                                                   tile // (image.width // 8) * 8 + y % 8))]
                    expected.append(row)
                self.assertEqual(grid['grid'], expected, name)

    def test_music_uses_source_map_slot_and_bank_expression(self):
        rows = []
        for number, line in enumerate((self.reference / 'data/maps/songs.asm').read_text().splitlines(), 1):
            match = re.fullmatch(r'\s*db (MUSIC_\w+), (BANK\(Music_\w+\))\s*;\s*(\w+)', line)
            if match:
                rows.append((number, match.groups()))
        for definition in self.maps.values():
            number, (symbol, bank, constant) = rows[definition['source_map_id']]
            self.assertEqual(constant, definition['source_map_constant'])
            self.assertEqual(definition['music'], dict(symbol=symbol, audio_bank=bank,
                source='data/maps/songs.asm', source_line=number))
        self.assertEqual(self.maps['Route3']['music']['symbol'], 'MUSIC_ROUTES3')
        self.assertEqual(self.maps['Route4']['music']['symbol'], 'MUSIC_ROUTES3')
        self.assertEqual(self.maps['Route24']['music']['symbol'], 'MUSIC_ROUTES2')
        self.assertEqual(self.maps['Route25']['music']['symbol'], 'MUSIC_ROUTES2')

    def test_every_event_is_ordinary_or_has_an_explicit_bespoke_gap(self):
        bound = set(self.events['events']) | set(self.events['signs'])
        gaps = {g['id'] for g in self.scripts['gaps']}
        self.assertFalse(bound & gaps)
        expected = {e['id'] for d in self.maps.values() for group in ('objects', 'background_events') for e in d['events'][group]}
        self.assertEqual(bound | gaps, expected)
        for name, indexes in generator.BESPOKE.items():
            for event in self.maps[name]['events']['objects']:
                if event['source_index'] in indexes:
                    self.assertIn(event['id'], gaps)
        self.assertEqual(len(self.events['events']), 79)
        self.assertEqual(len(self.events['signs']), 16)

    def test_text_recipes_retain_exact_original_lines_and_all_descriptor_labels_resolve(self):
        for record in self.texts.values():
            lines = (self.reference / record['source']).read_text().splitlines()
            for row in record['recipe']:
                source = lines[row['source_line'] - 1].strip()
                if 'text' in row:
                    self.assertEqual(source, f'{row["op"]} "{row["text"]}"')
                elif row['op'] == 'text_ram':
                    self.assertEqual(source, 'text_ram ' + row['symbol'])
                else:
                    self.assertEqual(source, row['source'])
        def check(value):
            if isinstance(value, str) and value.startswith('_'):
                self.assertTrue(value in self.texts, value)
            elif isinstance(value, dict):
                for child in value.values():
                    check(child)
            elif isinstance(value, list):
                for child in value:
                    check(child)
        check(self.events)

    def test_trainer_parties_match_independent_known_source_teams(self):
        trainers = self.trainers['trainers']
        self.assertEqual(len(trainers), 41)
        self.assertEqual([(m['level'], m['species']) for m in trainers['pokered:ROUTE_3:objects:2']['party']],
                         [(10, 'caterpie'), (10, 'weedle'), (10, 'caterpie')])
        self.assertEqual([(m['level'], m['species']) for m in trainers['pokered:CERULEAN_GYM:objects:1']['party']],
                         [(18, 'staryu'), (21, 'starmie')])
        self.assertEqual([(m['level'], m['species']) for m in trainers['pokered:MT_MOON_B2F:objects:1']['party']],
                         [(12, 'grimer'), (12, 'voltorb'), (12, 'koffing')])
        for id, trainer in trainers.items():
            self.assertEqual(trainer['id'], id)
            self.assertEqual(trainer['payout'], trainer['base_money'] * trainer['party'][-1]['level'])
        self.assertEqual(len(self.trainers['rival_classes']['OPP_RIVAL1']['parties']), 9)

    def test_immutable_sprite_converter_preserves_every_source_frame(self):
        sprites = json.loads(self.artifacts['sprites.json'])['sprites']
        self.assertEqual(len(sprites), 28)
        shades = {255: '.', 170: '1', 85: '2', 0: '#'}
        for strip in sprites.values():
            image = Image.open(self.reference / strip['source']).convert('L')
            for index, grid in strip['frames'].items():
                self.assertEqual(grid, [''.join(shades[image.getpixel((x, int(index) * 16 + y))]
                                                for x in range(16)) for y in range(16)])

    def test_missing_mutated_and_extra_outputs_fail_without_repair(self):
        for mutation in ('missing', 'mutated', 'extra'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temporary:
                path = Path(temporary)
                for name, data in self.artifacts.items():
                    (path / name).write_bytes(data)
                if mutation == 'missing':
                    (path / 'Route3.json').unlink()
                elif mutation == 'mutated':
                    (path / 'Route3.json').write_bytes(b'{}')
                else:
                    (path / 'extra').write_bytes(b'{}')
                before = {p.name: p.read_bytes() for p in path.iterdir()}
                with self.assertRaises(ValueError):
                    generator.verify(self.artifacts, path)
                self.assertEqual(before, {p.name: p.read_bytes() for p in path.iterdir()})

    def test_pinned_input_mutation_is_rejected(self):
        from tools.generate_kanto_maps import MapError, Reference
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'data/maps/songs.asm'
            path.parent.mkdir(parents=True)
            path.write_bytes((self.reference / 'data/maps/songs.asm').read_bytes() + b'\n')
            with self.assertRaisesRegex(MapError, 'checksum'):
                Reference(temporary, self.pin['files']).bytes('data/maps/songs.asm')


if __name__ == '__main__':
    unittest.main()
