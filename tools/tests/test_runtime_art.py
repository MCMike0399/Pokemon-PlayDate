import json,os,tempfile,unittest
from pathlib import Path
from PIL import Image
from tools.visual import runtime_art
REFERENCE=os.environ.get('POKERED_REFERENCE_DIR')
@unittest.skipUnless(REFERENCE,'requires checksum-pinned original source tree')
class RuntimeArtTests(unittest.TestCase):
    def test_original_source_inventory_has_all_fifty_variants(self):
        images=runtime_art.expected(REFERENCE);self.assertEqual(len(images),50)
        self.assertEqual(len([p for p in images if p.startswith('capture_') and '__'not in p]),9)
        self.assertEqual(images['jump_shadow.png'].size,(32,32))
    def test_native_file_and_single_mask_pixel_regression(self):
        with tempfile.TemporaryDirectory()as directory:
            root=Path(directory);(root/'frames').mkdir();images=runtime_art.expected(REFERENCE)
            for name,image in images.items():image.save(root/'frames'/name)
            rows=[{'path':name}for name in images]
            metadata=[{'path':name,'source_revision':'af519899719f0754965776faac0e836a3b906e6d','source_id':'pokered:ledge-shadow:four-oam-quarters'if name=='jump_shadow.png'else'pokered:battle-capture:'+name[len('capture_'):-4]}for name in images if '__'not in name]
            (root/'catalog.json').write_text(json.dumps({'images':rows,'image_root':'frames','runtime_art':metadata}))
            report=runtime_art.inspect(REFERENCE,root);self.assertTrue(report['ok'],report['failures']);self.assertEqual(len(report['added_unreviewed']),50)
            path=root/'frames/jump_shadow__mask.png'
            with Image.open(path)as image:image=image.convert('RGBA');image.putpixel((0,0),(255,255,255,255));image.save(path)
            report=runtime_art.inspect(REFERENCE,root);self.assertFalse(report['ok'])
            row=next(r for r in report['failures']if r['path']=='jump_shadow__mask.png');self.assertEqual(row['changed_pixels'],1);self.assertEqual(row['bbox'],(0,0,1,1))
if __name__=='__main__':unittest.main()
