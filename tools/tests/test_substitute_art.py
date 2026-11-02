"""Exact source indexing, artifact reproduction and protected-byte preservation."""
import copy
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from PIL import Image
from tools import generate_substitute_art as art

BASE = 'fd4561b4a9cc2c3e4734d368ac5b3dbcc69e462e'
MECHANICS_BASE = '66ff1861acd6cbcdb4f624d0908833ec1ff9a2ab'


def original(name, revision=BASE):
    return subprocess.check_output(['git', 'show', revision + ':' + name], cwd=art.ROOT)


class SubstituteArtTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(art.MANIFEST.read_text())
        cls.data = art.load_inputs(art.DEFAULT_REFERENCE, cls.manifest)

    def test_all_input_checksums_equal_the_exact_pinned_git_objects(self):
        self.assertEqual(self.manifest['revision'], 'af519899719f0754965776faac0e836a3b906e6d')
        for path, checksum in self.manifest['inputs'].items():
            git_bytes = subprocess.check_output(['git', '-C', str(art.DEFAULT_REFERENCE), 'show', art.REVISION + ':' + path])
            self.assertEqual(git_bytes, self.data[path], path)
            self.assertEqual(hashlib.sha256(git_bytes).hexdigest(), checksum)

    def test_crop_quadrant_order_canvas_coordinates_and_palette_match_each_source_pixel(self):
        artifacts, receipt = art.build()
        source = Image.open(io.BytesIO(self.data['gfx/sprites/monster.png']))
        # Independent direct 16x16 crop oracle, rather than the tile assembler.
        for view, source_y, target_x in [('front', 0, 16), ('back', 16, 24)]:
            actual = Image.open(io.BytesIO(artifacts['substitute-' + view + '.png']))
            self.assertEqual(actual.mode, '1')
            self.assertEqual(actual.size, (56,56))
            for y in range(56):
                for x in range(56):
                    pixel = source.getpixel((x-target_x, y-32+source_y)) if target_x <= x < target_x+16 and 32 <= y < 48 else 255
                    self.assertEqual(actual.getpixel((x,y)), 255 if pixel >= 128 else 0, (view,x,y))
            self.assertEqual(set(actual.convert('RGBA').getchannel('A').getdata()), {255})
        self.assertEqual(receipt, self.manifest['reproduction'])

    def test_both_production_assets_reproduce_exact_png_bytes(self):
        artifacts, _ = art.build()
        art.check(artifacts)
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            for name, raw in artifacts.items(): (output/name).write_bytes(raw)
            art.check(artifacts, output)
            name = 'substitute-front.png'
            image = Image.open(output/name)
            image.putpixel((0,0),0)
            image.save(output/name)
            with self.assertRaisesRegex(ValueError, 'asset drift'):
                art.check(artifacts, output)

    def test_input_corruption_or_missing_pinned_input_fails_without_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            reference = Path(temporary)
            for name, raw in self.data.items():
                target = reference/name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            path = reference/'gfx/sprites/monster.png'
            path.write_bytes(path.read_bytes()+b'corrupt')
            with self.assertRaisesRegex(ValueError, 'input checksum'):
                art.build(reference)
            path.unlink()
            with self.assertRaises(FileNotFoundError):
                art.build(reference)

    def test_wrong_tile_index_order_or_picture_tilemap_is_rejected(self):
        changed = dict(self.data)
        changed['engine/battle/animations.asm'] = changed['engine/battle/animations.asm'].replace(b'ld hl, MonsterSprite tile 0', b'ld hl, MonsterSprite tile 1', 1)
        with self.assertRaisesRegex(ValueError, 'index/order/placement'):
            art.placements(changed)
        changed = dict(self.data)
        changed['gfx/pokemon/front.tilemap'] = bytes(range(49))
        with self.assertRaisesRegex(ValueError, 'display tile order'):
            art.placements(changed)

    def test_every_existing_image_and_grid_is_byte_identical_to_fd456(self):
        names = subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'Source/images','Source/world/sprites'], cwd=art.ROOT, text=True).splitlines()
        self.assertGreater(len(names), 302)
        for name in names:
            self.assertEqual((art.ROOT/name).read_bytes(), original(name), name)
        pins = json.loads((art.ROOT/'tools/visual/protected-source-pins.json').read_text())
        for record in pins['files']:
            name = 'Source/' + record['path']
            self.assertEqual((art.ROOT/name).read_bytes(), original(name), name)

    def test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged(self):
        for name in ['Source/battle/battle.lua','Source/battle/conditions.lua','Source/battle/effects.lua','Source/battle/dsl.lua',
                     'Source/battle/moves.lua','Source/battle/moveSupport.lua','Source/battle/ordinaryAbilities.lua',
                     'Source/battle/contactAbilities.lua','Source/battle/substitutePolicy.lua',
                     'Source/domain/pokemonCodec.lua','Source/domain/sessionCodec.lua','Source/lib/rng.lua',
                     'tools/references/move-producer-migrations.json','tools/references/move-support.json',
                     'Source/dev/substituteContracts.lua','Source/dev/substituteSeamContracts.lua']:
            # Root's native-qualified runtime HM coverage is the current mechanics
            # baseline; the art/pose preservation baseline above stays fd456.
            # Root's reviewed formatting-only fix changes this contract's bytes,
            # while production mechanics retain their native-qualified baseline.
            expected_base = '4160ce96' if name == 'Source/dev/substituteContracts.lua' else MECHANICS_BASE
            self.assertEqual((art.ROOT/name).read_bytes(), original(name, expected_base), name)
        name = 'Source/dev/battlePresentationContracts.lua'
        before = re.findall(r'    test\("([^"]+)"', original(name).decode())
        after = re.findall(r'    test\("([^"]+)"', (art.ROOT/name).read_text())
        self.assertEqual(after[:len(before)], before)
        self.assertEqual(len(after)-len(before), 6)


if __name__ == '__main__':
    unittest.main()
