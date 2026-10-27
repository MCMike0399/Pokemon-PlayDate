import hashlib,json,shutil,tempfile,unittest
from pathlib import Path
from PIL import Image
from tools.harness.motion_journey import verify_rendered_poses,MotionJourney
from tools.harness.protocol import ProtocolError
from tools.visual.event_art import raster

class MotionRenderTests(unittest.TestCase):
    def fixture(self,root):
        root=Path(root);source=root/'Source/data/pewterSlice';source.mkdir(parents=True)
        hashes={}
        for name in ['sprites.json','descriptors.json','PewterMart.json']:
            path=source/name;shutil.copyfile(Path.cwd()/'Source/data/pewterSlice'/name,path)
            hashes['data/pewterSlice/'+name]=hashlib.sha256(path.read_bytes()).hexdigest()
        for relative in ['data/sourceMaps.json']:
            path = root/'Source'/relative
            shutil.copyfile(Path.cwd()/'Source'/relative, path)
            hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        (root/'source-manifest.json').write_text(json.dumps(hashes))
        data=json.loads((source/'sprites.json').read_text());mapping=data['mapping']['SPRITE_YOUNGSTER'];strip=data['sprites'][mapping['name']]
        sprite=raster(strip['frames'][str(strip['standing']['down'])])
        image=Image.new('RGBA',(400,240),(255,255,255,255));image.alpha_composite(sprite,(160,88));png=root/'world.png';image.save(png)
        state={'zone_id':'pokered:PEWTER_MART','camera':{'x':0,'y':16},'npcs':[{'source_event_id':'pokered:PEWTER_MART:objects:2','pixel_x':160,'pixel_y':104,'facing':'down','motion':{'phase':'moving','tick':4}}]}
        return root,png,state,sprite
    def test_exact_source_pose_passes_and_one_opaque_pixel_change_fails(self):
        with tempfile.TemporaryDirectory()as folder:
            root,png,state,sprite=self.fixture(folder);report=verify_rendered_poses(root,png,state)
            self.assertEqual(report['actors'][0]['native_tick'],4);self.assertEqual(report['actors'][0]['pose'],'stand')
            self.assertGreater(report['actors'][0]['opaque_pixels_checked'],32)
            point=next((x,y)for y in range(32)for x in range(32)if sprite.getpixel((x,y))[3]==255)
            with Image.open(png)as opened:image=opened.convert('RGBA')
            x,y=point;x+=160;y+=88;pixel=image.getpixel((x,y));image.putpixel((x,y),(255-pixel[0],255-pixel[1],255-pixel[2],255));image.save(png)
            with self.assertRaisesRegex(ProtocolError,'source pose mismatch'):verify_rendered_poses(root,png,state)
    def test_transparent_source_cells_do_not_hide_expected_opaque_art(self):
        with tempfile.TemporaryDirectory()as folder:
            root,png,state,sprite=self.fixture(folder)
            point=next((x,y)for y in range(32)for x in range(32)if sprite.getpixel((x,y))[3]==0)
            with Image.open(png)as opened:image=opened.convert('RGBA')
            image.putpixel((160+point[0],88+point[1]),(0,0,0,255));image.save(png)
            self.assertTrue(verify_rendered_poses(root,png,state)['actors'])
    def test_identified_source_drift_and_title_image_fail(self):
        with tempfile.TemporaryDirectory()as folder:
            root,png,state,sprite=self.fixture(folder)
            Image.new('RGBA',(400,240),(255,255,255,255)).save(png)
            with self.assertRaisesRegex(ProtocolError,'source pose mismatch'):verify_rendered_poses(root,png,state)
            path=root/'Source/data/pewterSlice/sprites.json';path.write_text(path.read_text()+'\n')
            with self.assertRaisesRegex(ProtocolError,'source input drift'):verify_rendered_poses(root,png,state)
    def test_boundary_request_retains_install_and_first_world_snapshots(self):
        class Client:
            def send(self,commands,**kwargs):
                self.commands=commands
                return {'results':[{'command':i,'op':op,'status':'ok','snapshot':{'tick':i}}for i,op in enumerate(['record','press','snapshot'],1)]}
        with tempfile.TemporaryDirectory()as folder:
            path=Path(folder);client=Client();j=MotionJourney(client,path,{'name':'npc-motion-continue'})
            j.frames_dir.mkdir()
            for i in range(1,4):(j.frames_dir/f'motion-continue-boundary-{i:02d}.png').write_bytes(b'file existence fixture')
            installed,rendered=j.continue_frames()
            self.assertEqual(client.commands,['record motion-continue-boundary 3','press a','snapshot'])
            self.assertEqual(installed,{'tick':2});self.assertEqual(rendered,{'tick':3})

if __name__=='__main__':unittest.main()
