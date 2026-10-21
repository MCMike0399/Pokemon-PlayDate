import contextlib,io,json,os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
from tools import generate_jump_art as jump

ROOT=Path(__file__).resolve().parents[2]
CURVE=[56,54,52,50,49,48,48,48,49,50,51,52,54,56,60,60]


def synthetic():
    image=Image.new('1',(8,8),1);image.putpixel((7,7),0);stream=io.BytesIO();image.save(stream,format='PNG')
    return {'engine/overworld/player_animations.asm':('PlayerJumpingYScreenCoords:\n db '+','.join(f'${n:02x}'for n in CURVE)+'\n').encode(),
            'engine/overworld/ledges.asm':b'LedgeHoppingShadowOAMBlock:\n db $ff, OAM_PAL1\n db $ff, OAM_XFLIP\n db $ff, OAM_YFLIP\n db $ff, OAM_XFLIP | OAM_YFLIP\n',
            'gfx/overworld/shadow.png':stream.getvalue()}


class JumpArtTests(unittest.TestCase):
    def test_source_curve_and_all_four_original_shadow_quadrants(self):
        curve,offsets,rows=jump.derive(synthetic())
        self.assertEqual(curve,CURVE);self.assertEqual(offsets,[-8,-12,-16,-20,-22,-24,-24,-24,-22,-20,-18,-16,-12,-8,0,0])
        self.assertEqual({(x,y)for y,row in enumerate(rows)for x,cell in enumerate(row)if cell=='#'}, {(7,7),(8,7),(7,8),(8,8)})
        image=jump.shadow_image(synthetic());self.assertEqual(image.size,(32,32))
        self.assertEqual(image.getpixel((14,14)),(0,0,0,255));self.assertEqual(image.getpixel((0,0)),(255,255,255,0))
    def test_missing_or_wrong_original_oam_transform_rejected(self):
        sources=synthetic();sources['engine/overworld/ledges.asm']=sources['engine/overworld/ledges.asm'].replace(b'OAM_XFLIP | OAM_YFLIP',b'OAM_XFLIP')
        with self.assertRaisesRegex(ValueError,'transforms'):jump.derive(sources)
    def test_native_one_mask_pixel_and_invisible_rgb_defects_fail(self):
        sources=synthetic();expected=jump.shadow_image(sources)
        with tempfile.TemporaryDirectory()as directory:
            image_path=Path(directory)/'shadow.png';mask_path=Path(directory)/'mask.png'
            expected.save(image_path);expected.getchannel('A').save(mask_path)
            self.assertTrue(jump.check_native(sources,image_path,mask_path)['ok'])
            mask=expected.getchannel('A');mask.putpixel((2,3),255);mask.save(mask_path)
            result=jump.check_native(sources,image_path,mask_path)
            self.assertFalse(result['ok']);self.assertEqual(result['mask']['changed_pixels'],1);self.assertEqual(result['mask']['bbox'],(2,3,3,4))
            changed=expected.copy();changed.putpixel((0,0),(0,0,0,0));changed.save(image_path)
            result=jump.check_native(sources,image_path)
            self.assertFalse(result['ok']);self.assertEqual(result['image']['rgb_pixels'],1);self.assertEqual(result['image']['alpha_pixels'],0)
    def test_native_alpha_and_dimension_failures(self):
        expected=jump.shadow_image(synthetic());changed=expected.copy();changed.putpixel((14,14),(0,0,0,0))
        result=jump.pixel_difference(expected,changed);self.assertEqual(result['alpha_pixels'],1);self.assertEqual(result['rgb_pixels'],0)
        self.assertFalse(jump.pixel_difference(expected,Image.new('1',(31,32)))['equal'])
    def test_pin_schema_cannot_drop_any_of_seven_inputs(self):
        manifest=json.loads(jump.MANIFEST.read_text());self.assertEqual(set(manifest['files']),jump.FILES)
        manifest['files'].pop('home/oam.asm')
        with tempfile.TemporaryDirectory()as directory:
            path=Path(directory)/'pin.json';path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError,'seven pinned'):jump.references(directory,path)
    def test_candidate_rejects_source_and_reference_mutation_and_never_overwrites(self):
        with tempfile.TemporaryDirectory()as directory:
            reference=Path(directory)/'pokered';reference.mkdir()
            with self.assertRaises(ValueError):jump.writable_candidate(ROOT/'Source/data/unwanted.lua',reference)
            with self.assertRaises(ValueError):jump.writable_candidate(reference/'new.lua',reference)
            target=Path(directory)/'existing.lua';target.write_bytes(b'preserved')
            manifest={'revision':'af519899719f0754965776faac0e836a3b906e6d','files':{}}
            with patch.object(jump,'references',return_value=(manifest,synthetic())), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(jump.main(['--reference-root',str(reference),'--output',str(target)]),1)
            self.assertEqual(target.read_bytes(),b'preserved')

@unittest.skipUnless(os.environ.get('POKERED_REFERENCE_DIR'),'set POKERED_REFERENCE_DIR for original pinned source verification')
class PinnedJumpArtTests(unittest.TestCase):
    def test_exact_checked_in_lua_matches_all_original_pins(self):
        manifest,sources=jump.references(os.environ['POKERED_REFERENCE_DIR'])
        self.assertEqual(len(sources),7)
        self.assertEqual(jump.generate(manifest,sources),(ROOT/'Source/data/kantoJump.lua').read_bytes())
    def test_mutated_primary_input_rejected_before_derivation(self):
        with tempfile.TemporaryDirectory()as directory:
            root=Path(directory);path=root/'engine/overworld/player_animations.asm';path.parent.mkdir(parents=True)
            path.write_bytes(b'one pixel / source mutation')
            with self.assertRaisesRegex(ValueError,'source checksum mismatch'):jump.references(root)

if __name__=='__main__':unittest.main()
