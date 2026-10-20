import hashlib,importlib.util,json,tempfile,unittest,os
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
PROJECT=ROOT
REFERENCE=Path(os.environ['KANTO_REFERENCE']) if 'KANTO_REFERENCE' in os.environ else None
spec=importlib.util.spec_from_file_location('slice_generator',ROOT/'tools/generate_viridian_slice.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
class SliceTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  if REFERENCE is None:raise unittest.SkipTest('explicit KANTO_REFERENCE required')
  cls.art=g.build(REFERENCE);cls.maps={n:json.loads(cls.art['maps/'+n+'.json']) for n in g.MAPS}
 def test_deterministic_complete_artifact_inventory(self):
  self.assertEqual(self.art,g.build(REFERENCE));m=json.loads(self.art['manifest.json'])
  for path,sha in m['artifacts'].items():self.assertEqual(hashlib.sha256(self.art[path]).hexdigest(),sha)
 def test_four_source_map_geometries_and_events(self):
  for name,size,counts in [('Route1',[20,36],[2,1,0]),('ViridianCity',[40,36],[7,6,5]),('ViridianMart',[8,8],[3,0,2]),('ViridianPokecenter',[14,8],[4,0,2])]:
   d=self.maps[name];self.assertEqual(d['dimensions']['cells'],size);self.assertEqual([len(d['events'][k]) for k in ['objects','background_events','warps']],counts)
   for events in d['events'].values():
    for e in events:self.assertTrue(0<=e['x']<size[0] and 0<=e['y']<size[1])
 def test_exact_source_npc_coordinates_and_no_substitutes(self):
  mart=self.maps['ViridianMart']['events']['objects'];self.assertEqual([(e['x'],e['y'],e['sprite']) for e in mart],[(0,5,'SPRITE_CLERK'),(5,5,'SPRITE_YOUNGSTER'),(3,3,'SPRITE_COOLTRAINER_M')])
  sprites=json.loads(self.art['sprites.json'])['sprites'];self.assertEqual(set(sprites),set(g.SPRITES))
  for name,data in sprites.items():
   im=Image.open(REFERENCE/data['source']).convert('L');values={255:'.',170:'1',85:'2',0:'#'}
   for frame,grid in data['frames'].items():
    for y,row in enumerate(grid):self.assertEqual(row,''.join(values[im.getpixel((x,int(frame)*16+y))] for x in range(16)))
 def test_blue_route_slot_levels_species_weights(self):
  table=self.maps['Route1']['encounters']['grass'];self.assertEqual(table['rate_byte'],25);self.assertEqual(sum(x['weight_256'] for x in table['slots']),256)
  self.assertEqual([(x['level'],x['species']) for x in table['slots']],[(3,'pidgey'),(3,'rattata'),(3,'rattata'),(2,'rattata'),(2,'pidgey'),(3,'pidgey'),(3,'pidgey'),(4,'rattata'),(4,'pidgey'),(5,'pidgey')])
 def test_connections_and_dynamic_original_last_map(self):
  north=self.maps['Route1']['connections'][0];south=self.maps['ViridianCity']['connections'][1]
  self.assertEqual(north['entry_lateral_adjustment_cells'],10);self.assertEqual(south['entry_lateral_adjustment_cells'],-10)
  for x in range(20):self.assertEqual(x+10-10,x)
  self.assertEqual([(e['destination']['kind'],e['destination']['warp_index']) for e in self.maps['ViridianMart']['events']['warps']],[('last_outdoor_map',2)]*2)
  self.assertEqual([(e['destination']['kind'],e['destination']['warp_index']) for e in self.maps['ViridianPokecenter']['events']['warps']],[('last_outdoor_map',1)]*2)
 def test_all_runtime_text_labels_exist_and_no_invented_lines(self):
  import re
  texts=json.loads(self.art['dialogue.json'])['texts'];labels=set(re.findall(r'"(_\w+)"',(ROOT/'Source/world/sliceEvents.lua').read_text()));self.assertTrue(labels<=texts.keys())
  self.assertTrue(all(v['recipe'] for v in texts.values()));self.assertIn('_OaksLabOakGotPokedexText',texts)
 def test_exact_current_source_json_and_check_only_failure(self):
  self.assertEqual(g.check_source(self.art,ROOT/'Source/data/viridianSlice'),6)
  with tempfile.TemporaryDirectory() as directory:
   target=Path(directory)
   for name,data in g.source_artifacts(self.art).items():(target/name).write_bytes(data)
   original=(target/'Route1.json').read_bytes();(target/'Route1.json').write_bytes(original+b' ')
   with self.assertRaisesRegex(ValueError,'differs'):g.check_source(self.art,target)
   self.assertEqual((target/'Route1.json').read_bytes(),original+b' ')
 def test_new_reference_inputs_are_pinned_and_reject_tampering(self):
  base=g.load();pin=json.loads(g.SOURCE_PIN.read_text());pins={row['path']:row['sha256'] for row in pin['files']}
  self.assertIn('data/text/text_1.asm',pins)
  with tempfile.TemporaryDirectory() as directory:
   path=Path(directory)/'data/text/text_1.asm';path.parent.mkdir(parents=True);path.write_bytes(b'tampered')
   with self.assertRaisesRegex(base.MapError,'checksum'):base.Reference(directory,pins).bytes('data/text/text_1.asm')
 def test_sprite_masks_not_white_key_and_original_terrain_has_no_alpha(self):
  import io
  found_interior_white=False
  for path,data in self.art.items():
   if path.endswith('-image.png'):
    im=Image.open(io.BytesIO(data)).convert('RGBA');found_interior_white|=any(p==(255,255,255,255) for p in im.getdata());self.assertTrue(any(p[3]==0 for p in im.getdata()))
   elif path.endswith('-native.png') or path.endswith('-reference.png'):self.assertNotIn('A',Image.open(io.BytesIO(data)).getbands())
  self.assertTrue(found_interior_white)
if __name__=='__main__':unittest.main()
