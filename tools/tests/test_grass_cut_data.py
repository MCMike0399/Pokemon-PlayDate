"""Primary bytes, generated grids and bounded source inventory; no Lua execution."""
import json
import unittest

from tools import generate_field_moves as gen
from tools.generate_kanto_maps import decode_png, tile_grids


class GrassCutDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(gen.build()['fieldMoves.json'])

    def test_primary_dispatch_and_aligned_replacement(self):
        root = gen.INPUT / 'pokered'
        cut = (root / 'engine/overworld/cut.asm').read_text()
        self.assertIn('cp $52 ; grass\n\tjr z, .canCut', cut)
        self.assertIn('call ReplaceTreeTileBlock', cut)
        self.assertIn('ld a, [wXBlockCoord]', cut)
        self.assertIn('ld a, [wYBlockCoord]', cut)
        blocks = (root / 'gfx/blocksets/overworld.bst').read_bytes()
        self.assertEqual(blocks[0xb * 16:0xc * 16], bytes([0x52] * 16))
        self.assertEqual(blocks[0xa * 16:0xb * 16], bytes([0x2c] * 16))

    def test_every_grass_recipe_is_one_exact_source_block(self):
        count = 0
        for spec in self.data['maps'].values():
            for site in spec['grass_sites']:
                count += 1
                self.assertEqual((site['kind'], site['block'], site['replacement']), ('grass', 0xb, 0xa))
                self.assertEqual((site['x'] % 2, site['y'] % 2), (0, 0))
                expected = [(site['x'] + q % 2, site['y'] + q // 2) for q in range(4)]
                self.assertEqual([(c['x'], c['y']) for c in site['cells']], expected)
                self.assertEqual([(t['x'], t['y']) for t in site['targets']], expected)
                for cell in site['cells']:
                    self.assertEqual(cell['before'], 'pokered:OVERWORLD:cell:52-52-52-52')
                    self.assertEqual(cell['after'], 'pokered:OVERWORLD:cell:2c-2c-2c-2c')
                    self.assertTrue(self.data['tiles'][cell['before']]['terrain']['grass'])
                    self.assertFalse(self.data['tiles'][cell['after']]['terrain']['grass'])
                    self.assertEqual(self.data['tiles'][cell['after']]['collision'], 0)
        self.assertEqual(count, 255)
        self.assertEqual(len(self.data['maps']['pokered:ROUTE_6']['grass_sites']), 45)

    def test_all_installed_overworld_maps_are_pinned_without_pallet_recipe(self):
        compact = json.loads((gen.ROOT / 'Source/data/sourceMapCache/compact.json').read_bytes())
        ids = {d['id'] for d in compact['maps'].values() if d['tileset']['constant'] == 'OVERWORLD'}
        self.assertEqual(ids, {key for key, spec in self.data['maps'].items() if spec['tileset'] == 'OVERWORLD'})
        self.assertNotIn('pallet_town', self.data['maps'])
        self.assertNotIn('pokered:PALLET_TOWN', self.data['maps'])

    def test_leaf_pixels_and_animation_snapshots_are_source_derived(self):
        leaf = tile_grids(decode_png((gen.INPUT / 'pokered/gfx/battle/move_anim_1.png').read_bytes()))[6]
        self.assertEqual(self.data['grass_leaf'], [''.join('.12#'[v] for v in row) for row in leaf])
        frames = self.data['grass_animation']
        self.assertEqual(len(frames), self.data['grass_frames'])
        self.assertEqual(len(frames), 32)
        self.assertEqual(frames[0], {'palette': 0x80, 'entries': [
            {'x': 1, 'y': 0, 'flip': 'x'}, {'x': 10, 'y': 0, 'flip': 'y'},
            {'x': -2, 'y': 8, 'flip': 'x'}, {'x': 7, 'y': 8, 'flip': 'y'}]})
        self.assertEqual([e['x'] for e in frames[7]['entries']], [8, 24, -16, 0])
        self.assertEqual([e['x'] for e in frames[15]['entries']], [-8, 16, -8, 16])
        self.assertEqual([e['y'] for e in frames[16]['entries']], [2, 2, 10, 10])
        self.assertEqual([e['x'] for e in frames[31]['entries']], [-16, 24, -16, 24])
        self.assertEqual([f['palette'] for f in frames], [0x80, 0xe4] * 16)

    def test_cue_keeps_primary_provenance_without_audio_substitute(self):
        self.assertEqual(self.data['cut_cue'], {'symbol': 'SFX_CUT',
                         'source': 'engine/overworld/cut.asm', 'playback': 'pending-audio-owner'})
        self.assertIn('ld a, SFX_CUT\n\tcall PlaySound',
                      (gen.INPUT / 'pokered/engine/overworld/cut.asm').read_text())
