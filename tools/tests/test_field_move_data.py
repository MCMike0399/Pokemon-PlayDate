"""Field inputs/generation only. Gameplay contracts require the actual SDK."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools import generate_field_moves as gen
from tools.generate_kanto_maps import quadrant_ids, records, integer


class FieldMoveDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifacts = gen.build()
        cls.data = json.loads(cls.artifacts['fieldMoves.json'])
        cls.pins = json.loads((gen.INPUT / 'pins.json').read_bytes())

    def test_generated_files_match_committed_inputs(self):
        for name, raw in self.artifacts.items():
            self.assertEqual(raw, (gen.ROOT / 'Source/data' / name).read_bytes())
        self.assertEqual(gen.build(), self.artifacts)

    def test_every_vendored_primary_file_is_pinned(self):
        expected = set()
        for directory, pins in [('pokered', self.pins['pokered']), ('showdown', self.pins['showdown']['files'])]:
            for name, digest in pins.items():
                path = gen.INPUT / directory / name
                expected.add(path)
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
        actual = {p for directory in ('pokered', 'showdown') for p in (gen.INPUT / directory).rglob('*') if p.is_file()}
        self.assertEqual(actual, expected)

    def test_tampered_primary_source_fails_before_publication(self):
        for relative in ['pokered/engine/overworld/cut.asm', 'pokered/maps/Route2.blk',
                         'showdown/data/mods/gen5/moves.ts']:
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as temporary:
                inputs = Path(temporary) / 'inputs'
                shutil.copytree(gen.INPUT, inputs)
                path = inputs / relative
                path.write_bytes(path.read_bytes() + b'\n; tampered\n')
                with self.assertRaises((ValueError, AssertionError)):
                    gen.build(inputs)

    def test_source_block_replacement_table_has_all_nine_exact_pairs(self):
        rows = records((gen.INPUT / 'pokered/data/tilesets/cut_tree_blocks.asm').read_text(), 'db')
        pairs = [tuple(integer(v) for v in row['args']) for row in rows if len(row['args']) == 2]
        self.assertEqual(pairs, [(0x32,0x6d),(0x33,0x6c),(0x34,0x6f),(0x35,0x4c),
                                 (0x60,0x6e),(0x0b,0x0a),(0x3c,0x35),(0x3f,0x35),(0x3d,0x36)])
        for spec in self.data['maps'].values():
            for site in spec['sites']:
                self.assertIn((site['block'],site['replacement']), pairs)
                self.assertEqual(len(site['cells']), 4)
                blockset = (gen.INPUT / ('pokered/gfx/blocksets/' + spec['tileset'].lower() + '.bst')).read_bytes()
                for q, cell in enumerate(site['cells']):
                    for field, block in [('before',site['block']),('after',site['replacement'])]:
                        ids = quadrant_ids(blockset,block,q)
                        self.assertEqual(cell[field], 'pokered:'+spec['tileset']+':cell:'+'-'.join(f'{i:02x}' for i in ids))

    def test_cut_sites_bind_exact_source_positions_and_no_authored_pallet(self):
        self.assertNotIn('pallet_town', self.data['maps'])
        self.assertNotIn('pokered:PALLET_TOWN', self.data['maps'])
        route = self.data['maps']['pokered:ROUTE_2']
        self.assertEqual([(s['x'],s['y']) for s in route['sites']], [(4,10),(14,22),(4,38),(12,52),(12,60),(12,68)])
        vermilion = self.data['maps']['pokered:VERMILION_CITY']['sites']
        self.assertEqual([(s['block'],s['replacement'],s['targets']) for s in vermilion],
                         [(0x35,0x4c,[{'x':15,'y':18}])])
        for spec in self.data['maps'].values():
            for site in spec['sites']:
                for target in site['targets']:
                    cell = next(c for c in site['cells'] if c['x']==target['x'] and c['y']==target['y'])
                    before, after = (self.data['tiles'][cell[f]] for f in ('before','after'))
                    self.assertEqual(before['terrain']['foot_tile'], 0x3d if spec['tileset']=='OVERWORLD' else 0x50)
                    self.assertEqual(before['collision'], 1)
                    self.assertEqual(after['collision'], 0)

    def test_existing_imported_metadata_and_art_are_identical(self):
        compact = json.loads((gen.ROOT / 'Source/data/sourceMapCache/compact.json').read_bytes())
        atlas = json.loads((gen.ROOT / 'Source/data/sourceMapCache/tile-grids.json').read_bytes())
        for key, entry in self.data['tiles'].items():
            self.assertIn(key, compact['tiles'], 'root cache must already own the exact field tile')
            self.assertIn(key, atlas['tiles'])
            self.assertEqual({k:v for k,v in entry.items() if k!='grid'}, compact['tiles'][key])
            self.assertEqual(entry['grid'],atlas['tiles'][key]['grid'])

    def test_flash_adapter_names_only_source_dark_maps_and_source_timing(self):
        self.assertEqual(self.data['dark_maps'], ['pokered:ROCK_TUNNEL_1F','pokered:ROCK_TUNNEL_B1F'])
        self.assertEqual(self.data['tree_frames'],8)
        self.assertEqual(self.data['flash_white_frames'],3)
        self.assertTrue(all(len(row)==16 and set(row)<=set('.12#') for row in self.data['tree_grid']))

    def test_battle_extension_does_not_override_core_dispatch(self):
        lua = self.artifacts['fieldMoveBattleData.lua'].decode()
        self.assertIn('accuracy=95, pp=30',lua)
        self.assertIn('accuracy=100, pp=20',lua)
        self.assertIn('ModifyStat(DEFENDER, "acc", -1)',lua)
        self.assertNotIn('MoveSupport.handlers.',lua)
        self.assertIn('moveData.cut == nil and moveData.flash == nil',lua)


if __name__ == '__main__':
    unittest.main()
