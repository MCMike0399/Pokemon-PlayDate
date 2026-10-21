import json,os
from pathlib import Path
import tempfile
import unittest
from PIL import Image
from tools.visual import event_art as art
import importlib.util
inventory_path=Path(__file__).resolve().parents[1]/'visual/inventory.py'
spec=importlib.util.spec_from_file_location('candidate_event_inventory',inventory_path)
inventory=importlib.util.module_from_spec(spec);spec.loader.exec_module(inventory)
expected_slice=inventory.expected_slice

PROJECT=Path(os.environ.get('POKEMON_PROJECT',Path.cwd())).resolve()
REFERENCE=os.environ.get('POKERED_REFERENCE_DIR')

class EventInventoryTests(unittest.TestCase):
    def test_exact_extension_leaves_old_inventory_default_unchanged(self):
        self.assertEqual(len(art.expected_inventory()),35)
        self.assertEqual(len(set(art.expected_inventory())),35)
        self.assertEqual(len({row['source_id'] for row in art.specifications()}),7)
        self.assertEqual(expected_slice(PROJECT/'Source')['counts']['images'],635)
        result=expected_slice(PROJECT/'Source',include_events=True)
        self.assertEqual(result['counts']['images'],670);self.assertEqual(result['counts']['event_art_images'],7)
    def test_pattern_mask_and_clear_storage_remain_exact(self):
        grid=['.'*16]+['.'+'2'*14+'.' for _ in range(14)]+['.'*16]
        zero=art.raster(grid,0);legacy=art.raster(grid,1)
        self.assertEqual(zero.getpixel((2,2)),(0,0,0,255))
        self.assertEqual(legacy.getpixel((2,2)),(255,255,255,255))
        self.assertEqual(zero.getpixel((0,0)),(255,255,255,0))
        self.assertEqual(art.clear_transparent_rgb(zero).getpixel((0,0)),(0,0,0,0))
        self.assertEqual(art.difference(zero,legacy)['alpha_pixels'],0)

@unittest.skipUnless(REFERENCE,'set POKERED_REFERENCE_DIR to checksum-pinned source tree')
class EventSourceOracleTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.protected=self.root/'protected';self.candidate=self.root/'candidate'
        self.protected.mkdir();self.candidate.mkdir();self.sources=art.load_sources(REFERENCE)
        images={};blue=self.sources['gfx/sprites/blue.png']
        for direction,index in [('down',0),('up',1),('left',2)]:
            images['npc_rival_'+direction+'.png']=art.raster(art.source_grid(blue,index,greyhair=True),1)
        images['npc_rival_right.png']=art.clear_transparent_rgb(images['npc_rival_left.png'].transpose(Image.Transpose.FLIP_LEFT_RIGHT))
        for direction in ('down','up','left','right'):
            image=images['npc_rival_'+direction+'.png'];images['npc_rival_'+direction+'__mask.png']=image.getchannel('A').convert('RGBA')
        self.write(self.protected,images)
        self.expected,_=art.expected_images(self.sources,1);self.write(self.candidate,self.expected,metadata=True)
    def write(self,root,images,metadata=False):
        (root/'frames').mkdir(exist_ok=True)
        for name,image in images.items():image.save(root/'frames'/name)
        manifest={'image_root':'frames','images':[{'path':name}for name in images]}
        if metadata:
            manifest['event_art']=[dict(row,path=row['name']+'.png',source_revision=art.REVISION,source_sha256=art.PINS[row['source_path']][0])for row in art.specifications()]
        (root/'catalog.json').write_text(json.dumps(manifest))
    def inspect(self):return art.inspect(REFERENCE,self.protected,self.candidate)
    def test_complete_source_mapping_reports_exact_but_unreviewed(self):
        report=self.inspect();self.assertTrue(report['ok'],report['failures'])
        self.assertEqual(report['checked_images'],35);self.assertEqual(len(report['added_unreviewed']),35)
        self.assertEqual(report['legacy_phase']['dark_checker_inversion'],1)
        self.assertTrue(all(item['shared_hair_pixels']>0 and item['mismatched_pixels']==0 for item in report['shared_hair']))
        self.assertNotIn('equal',report)
    def test_wrong_walking_phase_cannot_recalibrate_to_candidate(self):
        grid=art.source_grid(self.sources['gfx/sprites/blue.png'],3,greyhair=True)
        art.raster(grid,0).save(self.candidate/'frames/event_blue_walk_down.png')
        report=self.inspect();self.assertFalse(report['ok'])
        self.assertEqual(report['legacy_phase']['dark_checker_inversion'],1)
        self.assertTrue(any(row['reason']=='shared protected hair phase' for row in report['failures'] if 'reason'in row))
    def test_one_standalone_mask_pixel_reports_exact_count_region(self):
        path=self.candidate/'frames/event_pokedex__mask.png'
        with Image.open(path)as image:
            image=image.convert('RGBA');image.putpixel((0,0),(255,255,255,255));image.save(path)
        report=self.inspect();self.assertFalse(report['ok'])
        row=next(row for row in report['failures']if row['path']=='event_pokedex__mask.png')
        self.assertEqual(row['changed_pixels'],1);self.assertEqual(row['bbox'],(0,0,1,1))
    def test_transparent_rgb_defect_is_not_ignored(self):
        path=self.candidate/'frames/event_heal_ball.png'
        with Image.open(path)as image:
            image=image.convert('RGBA');point=next((x,y)for y in range(image.height)for x in range(image.width)if image.getpixel((x,y))[3]==0)
            image.putpixel(point,(255,255,255,0));image.save(path)
        report=self.inspect();row=next(row for row in report['failures']if row['path']=='event_heal_ball.png')
        self.assertEqual(row['rgb_pixels'],1);self.assertEqual(row['alpha_pixels'],0)
    def test_missing_artifact_and_wrong_metadata_fail(self):
        (self.candidate/'frames/event_pokedex__texture.png').unlink()
        manifest=json.loads((self.candidate/'catalog.json').read_text());manifest['event_art'][0]['phase_policy']='explicit-zero'
        (self.candidate/'catalog.json').write_text(json.dumps(manifest));report=self.inspect()
        self.assertFalse(report['ok']);self.assertTrue(any(row.get('reason')=='source metadata' for row in report['failures']))
    def test_catalog_escape_is_rejected_before_image_reads(self):
        manifest=json.loads((self.candidate/'catalog.json').read_text());manifest['images'].append({'path':'../escape.png'})
        (self.candidate/'catalog.json').write_text(json.dumps(manifest))
        with self.assertRaises(ValueError):self.inspect()
    def test_mutated_primary_input_is_rejected(self):
        (self.root/'gfx/sprites').mkdir(parents=True);(self.root/'gfx/sprites/blue.png').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'pinned source mismatch'):art.load_sources(self.root)

if __name__=='__main__':unittest.main()
