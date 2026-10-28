"""Independent pinned art/timing checks. No host Lua or SDK emulation."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from PIL import Image

from tools import generate_vermilion_ship as ship
from tools import generate_vermilion_preparation as preparation

ROOT = Path(__file__).resolve().parents[2]
BASE = '4c851502d89a4faa1e37fabf93a16e27c4dbfc3e'


class VermilionShipSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = Path(os.environ['POKERED_REFERENCE_DIR'])
        cls.artifacts = ship.build()
        cls.art = json.loads(cls.artifacts['art.json'])
        cls.timing = json.loads(cls.artifacts['timing.json'])
        cls.prepared = preparation.build(cls.reference)

    def test_exact_reproduction_from_vendored_and_external_pinned_source(self):
        self.assertEqual(self.artifacts, ship.build(self.reference))
        for name, raw in self.artifacts.items():
            self.assertEqual((ship.OUTPUT / name).read_bytes(), raw)
        pin = json.loads((ship.REFERENCE / 'manifest.json').read_bytes())
        for path, digest in pin['files'].items():
            original = subprocess.check_output(['git', '-C', str(self.reference), 'show', ship.REVISION + ':' + path])
            self.assertEqual(hashlib.sha256(original).hexdigest(), digest, path)
            self.assertEqual((ship.REFERENCE / path).read_bytes(), original, path)

    def test_changed_script_or_png_is_rejected_before_art_generation(self):
        for path in ['scripts/VermilionDock.asm', 'gfx/overworld/smoke.png']:
            with self.subTest(path=path), tempfile.TemporaryDirectory() as directory:
                reference = Path(directory) / 'reference'
                shutil.copytree(ship.REFERENCE, reference)
                target = reference / path
                target.write_bytes(target.read_bytes() + b'!')
                with self.assertRaisesRegex(ValueError, 'unverified pinned ship source'):
                    ship.build(reference)

    def test_original_scroll_and_two_waits_have_exact_sixty_to_thirty_hz_clock(self):
        timing = self.timing
        self.assertEqual((timing['source_hz'], timing['native_hz']), (60, 30))
        self.assertEqual((timing['initial_wait'], timing['transfer_wait'], timing['final_wait']), (120, 6, 120))
        self.assertEqual((timing['chunks'], timing['pixels_per_chunk'], timing['source_frames_per_pixel']), (8, 16, 8))
        self.assertEqual((timing['band_top'], timing['band_bottom']), (0x50, 0x80))
        self.assertEqual((4 + 120 + 6 + 8 * 16 * 8 + 2 + 120 + 4 + 3 + 1) // 2, 642)
        self.assertEqual([cue['source_frame'] for cue in timing['audio_cues']], [0, 0, 130, 1156])
        self.assertEqual([cue['symbol'] for cue in timing['audio_cues']],
                         ['SFX_STOP_ALL_MUSIC', 'MUSIC_SURFING', 'SFX_SS_ANNE_HORN', 'SFX_SS_ANNE_HORN'])
        self.assertIn('no audio engine', timing['audio_status'])

    def test_hull_every_pixel_matches_original_layout_blockset_and_png(self):
        layout = (self.reference / 'maps/VermilionDock.blk').read_bytes()
        blockset = (self.reference / 'gfx/blocksets/ship_port.bst').read_bytes()
        image = Image.open(self.reference / 'gfx/tilesets/ship_port.png').convert('L')
        shades = {255: '.', 170: '1', 85: '2', 0: '#'}
        for row in self.art['hull']['cells']:
            for cell in row:
                x, y = cell['source_x'], cell['source_y']
                block = layout[(y // 2) * 14 + x // 2]
                start = block * 16 + (y % 2) * 8 + (x % 2) * 2
                ids = [blockset[start + offset] for offset in [0, 1, 4, 5]]
                self.assertEqual(cell['source_tile_ids'], ids)
                expected = []
                for py in range(16):
                    pixels = []
                    for px in range(16):
                        tile = ids[py // 8 * 2 + px // 8]
                        source_x = tile % (image.width // 8) * 8 + px % 8
                        source_y = tile // (image.width // 8) * 8 + py % 8
                        pixels.append(shades[image.getpixel((source_x, source_y))])
                    expected.append(''.join(pixels))
                self.assertEqual(cell['grid'], expected)
        self.assertEqual(self.art['pattern_phase'], [0, 0])
        self.assertEqual(self.art['band'], {'source_y': 3, 'height_cells': 3})
        self.assertEqual((len(self.art['hull']['cells']), len(self.art['hull']['cells'][0])), (3, 8))

    def test_smoke_uses_repeated_original_tile_and_obp1_zero_transparency(self):
        image = Image.open(self.reference / 'gfx/overworld/smoke.png').convert('L')
        indices = [[3 - image.getpixel((x, y)) // 85 for x in range(8)] for y in range(8)]
        self.assertEqual(self.art['smoke']['source_indices'], indices)
        self.assertEqual(self.art['smoke']['palette'], 0)
        self.assertEqual(self.art['smoke']['copies'], 4)
        for y in range(16):
            for x in range(16):
                self.assertEqual(self.art['smoke']['mask'][y][x], '1' if indices[y % 8][x % 8] else '0')
        source = ship.verified()
        self.assertIn(b'ld [wSSAnneSmokeDriftAmount], a\n\tldh [rOBP1], a', source['scripts/VermilionDock.asm'])
        self.assertIn(b'ld a, $1\n\tld de, VermilionDockOAMBlock\n\tcall WriteOAMBlock', source['scripts/VermilionDock.asm'])
        self.assertEqual(self.timing['oam_initial_x'], 88)
        self.assertEqual(self.timing['oam_y'], 100)
        self.assertEqual(self.timing['puff_step_drift'], 2)
        self.assertEqual(self.timing['puff_chunk_decrement'], 16)

    def test_water_fill_uses_original_ship_port_tile_14(self):
        image = Image.open(self.reference / 'gfx/tilesets/ship_port.png').convert('L')
        shades = {255: '.', 170: '1', 85: '2', 0: '#'}
        tile_x, tile_y = (0x14 % (image.width // 8)) * 8, (0x14 // (image.width // 8)) * 8
        expected = [''.join(shades[image.getpixel((tile_x + x % 8, tile_y + y % 8))] for x in range(16)) for y in range(16)]
        self.assertEqual(self.art['water_grid'], expected)

    def test_closed_door_adds_only_original_unused_grid_and_preserves_layout(self):
        before = json.loads(subprocess.check_output(['git', 'show', BASE + ':Source/data/vermilionPreparation/VermilionGym.json']))
        after = json.loads(self.prepared['VermilionGym.json'])
        for key in before.keys() - {'grids'}:
            self.assertEqual(after[key], before[key], key)
        self.assertEqual(after['grids'][:-1], before['grids'])
        self.assertEqual(len(after['grids']), len(before['grids']) + 1)
        added = after['grids'][-1]
        self.assertEqual(added['stable_id'], 'pokered:GYM:cell:20-21-30-31')
        self.assertEqual(added['source_tile_ids'], [0x20, 0x21, 0x30, 0x31])
        self.assertEqual(added['id'], len(after['grids']))
        self.assertFalse(added['terrain']['land_passable'])
        blockset = (self.reference / 'gfx/blocksets/gym.bst').read_bytes()
        self.assertEqual([blockset[0x24 * 16 + offset] for offset in [0, 1, 4, 5]], added['source_tile_ids'])
        image = Image.open(self.reference / 'gfx/tilesets/gym.png').convert('L')
        shades = {255: '.', 170: '1', 85: '2', 0: '#'}
        for y in range(16):
            for x in range(16):
                tile = added['source_tile_ids'][y // 8 * 2 + x // 8]
                self.assertEqual(added['grid'][y][x], shades[image.getpixel((tile % (image.width // 8) * 8 + x % 8, tile // (image.width // 8) * 8 + y % 8))])

    def test_shared_prepared_cache_contains_door_grid_and_solid_collision(self):
        key = 'pokered:GYM:cell:20-21-30-31'
        grids = json.loads(self.prepared['proposed-tile-grids.json'])['tiles']
        compact = json.loads(self.prepared['proposed-compact.json'])
        self.assertIn(key, grids)
        self.assertEqual(compact['tiles'][key]['collision'], 1)
        self.assertFalse(compact['tiles'][key]['terrain']['land_passable'])
        self.assertEqual(grids[key]['grid'], json.loads(self.prepared['VermilionGym.json'])['grids'][-1]['grid'])
        self.assertIn(key, compact['maps']['VermilionGym']['palette'])
        preparation.verify(self.prepared, preparation.OUTPUT)

    def test_active_inventory_preserves_old_entries_and_every_existing_grid(self):
        path = 'Source/data/sourceMaps.json'
        previous = json.loads(subprocess.check_output(['git', 'show', BASE + ':' + path]))
        active = json.loads((ROOT / path).read_bytes())
        self.assertEqual(len(active['maps']), 65)
        for name, entry in previous['maps'].items():
            self.assertEqual(active['maps'][name], entry, name)
        path = 'Source/data/sourceMapCache/tile-grids.json'
        previous = json.loads(subprocess.check_output(['git', 'show', BASE + ':' + path]))['tiles']
        active = json.loads((ROOT / path).read_bytes())['tiles']
        for key, grid in previous.items():
            self.assertEqual(active[key], grid, key)
        self.assertIn('pokered:GYM:cell:20-21-30-31', active)

    def test_all_ship_json_is_literal_utf8_and_deterministic(self):
        self.assertEqual(self.artifacts, ship.build())
        for raw in self.artifacts.values():
            self.assertEqual(raw, ship.encoded(json.loads(raw)))
            self.assertNotRegex(raw.decode(), r'\\u[0-9a-fA-F]{4}')

if __name__ == '__main__':
    unittest.main()
