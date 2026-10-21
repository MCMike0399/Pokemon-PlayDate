"""Offline pixel/ASM fixtures; no SDK replacement and no network."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

PATH=Path(__file__).resolve().parents[1]/'generate_capture_art.py'
spec=importlib.util.spec_from_file_location('capture_art',PATH)
gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)

class CaptureArtTests(unittest.TestCase):
    def test_exact_tile_flip_scale_palette_and_transparency(self):
        sheet=Image.new('L',(128,40),255)
        for x,v in enumerate((0,85,170,255)):sheet.putpixel((x,0),v)
        out=gen.assemble(sheet,[(0,0,0,False,False)])
        self.assertEqual(out.size,(16,16))
        self.assertEqual([out.getpixel((x*2,0)) for x in range(4)],[(0,0,0,255),(0,0,0,255),(255,255,255,255),(255,255,255,0)])
        flash=gen.assemble(sheet,[(0,0,0,False,False)],True)
        self.assertEqual(flash.getpixel((2,0)),(255,255,255,255))
        self.assertEqual(flash.getpixel((4,0)),(0,0,0,255))
        flipped=gen.assemble(sheet,[(0,0,0,True,True)])
        self.assertEqual(flipped.getpixel((14,14)),out.getpixel((0,0)))
        self.assertEqual(flipped.getpixel((12,14)),out.getpixel((2,0)))
        self.assertEqual(out.getpixel((0,0)),out.getpixel((1,1)))
    def test_literal_asm_count_geometry_flags(self):
        raw='FrameBlock03:\n db 1 ; count\n dbsprite 0, 1, 0, 0, $12, OAM_XFLIP | OAM_YFLIP\nFrameBlock04:\n'
        self.assertEqual(gen.block_rows(raw,'03'),[(0,1,18,True,True)])
        for bad in (raw.replace('db 1','db 2'),raw.replace('0, 1, 0, 0','0, 1, 1, 0'),raw.replace('OAM_XFLIP | OAM_YFLIP','OTHER'),raw.replace('$12','$80')):
            with self.assertRaises(gen.GenerationError):gen.block_rows(bad,'03')
    def test_unknown_palette_rejected(self):
        with self.assertRaises(gen.GenerationError):gen.assemble(Image.new('L',(128,40),42),[(0,0,0,False,False)])
    def test_checksum_and_path_escape_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);(root/'source').write_bytes(b'original')
            manifest={'inputs':[{'path':'source','sha256':gen.sha(b'original')}]}
            self.assertEqual(gen.references(root,manifest)['source'],b'original')
            (root/'source').write_bytes(b'changed')
            with self.assertRaisesRegex(gen.GenerationError,'checksum'):gen.references(root,manifest)
            manifest['inputs'][0]['path']='../outside'
            with self.assertRaisesRegex(gen.GenerationError,'escapes'):gen.references(root,manifest)
    def test_check_is_read_only_and_detects_metadata_and_pixel_drift(self):
        # Tiny generated fixture isolates CLI check semantics from network/source availability.
        image=Image.new('RGBA',(2,2),(0,0,0,255))
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);manifest=root/'manifest.json'
            manifest.write_text(json.dumps({'schema':1,'transform':{'scale':2}}))
            directory=root/'Source/images/battle-capture';directory.mkdir(parents=True)
            data=root/'Source/data/captureAnimationData.lua';data.parent.mkdir(parents=True)
            image.save(directory/'closed.png');data.write_text('fixed\n')
            args=['--reference-root',td,'--output-root',td,'--check']
            with patch.object(gen,'MANIFEST',manifest),patch.object(gen,'references',return_value={}),patch.object(gen,'generate',return_value=({'closed':image},'fixed\n')):
                self.assertEqual(gen.main(args),0)
                data.write_text('drift\n');before=data.read_bytes()
                self.assertEqual(gen.main(args),1);self.assertEqual(data.read_bytes(),before)
                data.write_text('fixed\n');Image.new('RGBA',(2,2),(255,255,255,255)).save(directory/'closed.png')
                before=(directory/'closed.png').read_bytes()
                self.assertEqual(gen.main(args),1);self.assertEqual((directory/'closed.png').read_bytes(),before)

    def test_staged_output_guard(self):
        # No source input is touched: root rejection precedes source access.
        self.assertEqual(gen.main(['--reference-root','/missing','--output-root',str(gen.ROOT)]),1)

if __name__=='__main__':unittest.main()
