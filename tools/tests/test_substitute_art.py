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

# fd4561b4 and 66ff1861 are not in this clone. These commits are, and their
# blobs are the current bytes. ordinaryAbilities and contactAbilities also
# still match the sha256 recorded for the missing mechanics baseline.
ART_FREEZE = '251c12dc1a845de7718b227a2b576b01352c1b74'
PRESENTATION_FREEZE = '0721a2b2c3f45e4b826796ff3f3957e05c277d3d'
PRESENTATION_PREFIX = '178b7f6f1527626b0b306e5d4cbfe7437d84c53d'
PROTECTED_DRIFT = {
    'Source/lib/shade.lua': '946c4b00b736632ebf7fa08e7a25ea118e7deb9c',
    'Source/world/tilefactory.lua': '946c4b00b736632ebf7fa08e7a25ea118e7deb9c',
    'Source/world/spritefactory.lua': '61ea7445f4f783113ff359f68b167cf5273a8b69',
    'Source/world/player.lua': '411d4428c55a341d22e54673269dcb50a38bfbd8',
    'Source/world/zone.lua': 'b086c523fb0e7ab6193a7de6cff67f65674317cd',
    'Source/data/maps.lua': '42f9286346663a3270ff2a136c0bb6d78fab4745',
}
MECHANICS_FREEZE = {
    'Source/battle/dsl.lua': '02846a40d85c0d3d5965070d44207b7556d74572',
    'Source/battle/moves.lua': '89905295b577884e020f5b91c131a0179083eb42',
    'Source/battle/ordinaryAbilities.lua': 'd9c39c119d3e0b001d1fd33e4d7849f5c1806dda',
    'Source/battle/contactAbilities.lua': 'd9c39c119d3e0b001d1fd33e4d7849f5c1806dda',
    'Source/battle/substitutePolicy.lua': 'd9c39c119d3e0b001d1fd33e4d7849f5c1806dda',
    'Source/domain/pokemonCodec.lua': '0ed37d2bdadb65e5934b8d1f201c4856b6daf1ea',
    'Source/domain/sessionCodec.lua': 'e6e3262816b88d078463e7a8a64ac383d49b5639',
    'Source/lib/rng.lua': '921f02bb3a81c25010b2983d9c0024b307ea7708',
    'tools/references/move-producer-migrations.json': '89905295b577884e020f5b91c131a0179083eb42',
    'Source/dev/substituteContracts.lua': '02846a40d85c0d3d5965070d44207b7556d74572',
    'Source/dev/substituteSeamContracts.lua': 'd9c39c119d3e0b001d1fd33e4d7849f5c1806dda',
}
RECORDED_BASELINE_SHA256 = {
    'Source/battle/ordinaryAbilities.lua': 'e6d576d9bb878df59d5df44efe12d45985d8982234ec2ce91f0972eaa50f314d',
    'Source/battle/contactAbilities.lua': 'aafe03063ffc3cc5796993cf622da8b1ee7c0fd1f2bc1ad108cf6711fc5db400',
}


def original(name, revision):
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

    def test_every_existing_image_and_grid_matches_the_living_art_freeze(self):
        names = subprocess.check_output(['git','ls-tree','-r','--name-only',ART_FREEZE,'Source/images','Source/world/sprites'], cwd=art.ROOT, text=True).splitlines()
        self.assertGreater(len(names), 302)
        for name in names:
            self.assertEqual((art.ROOT/name).read_bytes(), original(name, ART_FREEZE), name)
        pins = json.loads((art.ROOT/'tools/visual/protected-source-pins.json').read_text())
        for record in pins['files']:
            name = 'Source/' + record['path']
            current = (art.ROOT/name).read_bytes()
            if hashlib.sha256(current).hexdigest() == record['sha256']:
                continue
            self.assertEqual(current, original(name, PROTECTED_DRIFT[name]), name)

    def test_mechanics_producer_schema_rng_and_existing_case_names_are_unchanged(self):
        # Transform owns battle.lua, conditions.lua, effects.lua, moveSupport.lua,
        # and move-support.json. This freeze keeps the files Transform does not change.
        # e6e32628 keeps the v4 codec and adds the Hall of Fame team record.
        # 02846a40 retargets the substitute damage line to "SUBSTITUTE took damage".
        for name, revision in MECHANICS_FREEZE.items():
            current = (art.ROOT/name).read_bytes()
            self.assertEqual(current, original(name, revision), name)
            recorded = RECORDED_BASELINE_SHA256.get(name)
            if recorded is not None:
                self.assertEqual(hashlib.sha256(current).hexdigest(), recorded, name)
        name = 'Source/dev/battlePresentationContracts.lua'
        self.assertEqual((art.ROOT/name).read_bytes(), original(name, PRESENTATION_FREEZE), name)
        before = re.findall(r'    test\("([^"]+)"', original(name, PRESENTATION_PREFIX).decode())
        after = re.findall(r'    test\("([^"]+)"', (art.ROOT/name).read_text())
        self.assertEqual(after[:len(before)], before)
        self.assertEqual(len(after)-len(before), 13)


if __name__ == '__main__':
    unittest.main()
