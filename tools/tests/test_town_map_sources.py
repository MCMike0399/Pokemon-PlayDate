"""Independent primary-byte/literal vectors, not native execution evidence."""
import hashlib,importlib.util,json,os,re,tarfile,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
REFERENCE=ROOT/'tools/references/field-items'
spec=importlib.util.spec_from_file_location('transcribe',ROOT/'tools/generate_town_map.py');extractor=importlib.util.module_from_spec(spec);spec.loader.exec_module(extractor)
class Sources(unittest.TestCase):
 def data(self):return json.loads((ROOT/'Source/data/townMap.json').read_text())
 def test_every_consumed_source_is_immutable(self):
  pin=json.loads((ROOT/'tools/references/field-items-source.json').read_text());self.assertEqual(len(pin['files']),36)
  self.assertEqual(pin['archive_sha256'],json.loads((ROOT/'tools/references/kanto-source.json').read_text())['archive_sha256'])
  for name,entry in pin['files'].items():self.assertEqual(hashlib.sha256((REFERENCE/name).read_bytes()).hexdigest(),entry['sha256'],name)
 def test_complete_transcription_reproduces_without_source_mutation(self):
  self.assertEqual(extractor.extract(REFERENCE),self.data())
 def test_all_bitmap_tiles_match_independent_original_pixel_coordinates(self):
  d=self.data();image=Image.open(REFERENCE/'gfx/town_map/town_map.png').convert('RGB');palette={'.':255,'1':170,'2':85,'#':0}
  for index,grid in enumerate(d['tiles']):
   for y,row in enumerate(grid):
    for x,shade in enumerate(row):self.assertEqual(image.getpixel((index%4*8+x,index//4*8+y)),(palette[shade],)*3)
 def test_cursor_is_all256_original_pixels_with_open_transparent_center(self):
  data=self.data();image=Image.open(REFERENCE/'gfx/town_map/town_map_cursor.png').convert('L')
  self.assertEqual(image.size,(16,16));self.assertEqual(set(image.getdata()),{0,255})
  for y,row in enumerate(data['cursor']):
   for x,code in enumerate(row):self.assertEqual(image.getpixel((x,y)),0 if code=='#'else 255)
  self.assertEqual(data['cursor'][0],'#######..#######');self.assertEqual(data['cursor'][7],'.'*16);self.assertEqual(data['cursor'][8],'.'*16)
 def test_compressed_runs_are_exact_no_padding_or_unknown_tiles(self):
  data=self.data();wire=(REFERENCE/'gfx/town_map/town_map.rle').read_bytes();cursor=0
  self.assertEqual(len(wire),171);self.assertEqual(wire[-1],0)
  for byte in wire[:-1]:
   tile,count=divmod(byte,16);self.assertGreater(count,0)
   self.assertEqual(data['cells'][cursor:cursor+count],[tile]*count);cursor+=count
  self.assertEqual(cursor,360);self.assertEqual(data['width'],20);self.assertEqual(data['height'],18)
 def test_independent_literal_geography_selector_and_alias_vectors(self):
  d=self.data();self.assertEqual(len(d['locations']),248);self.assertEqual(len(d['order']),47)
  self.assertEqual(d['order'][:7],['PALLET_TOWN','ROUTE_1','VIRIDIAN_CITY','ROUTE_2','VIRIDIAN_FOREST','DIGLETTS_CAVE','PEWTER_CITY'])
  for key,point in {'PALLET_TOWN':(2,11),'VIRIDIAN_CITY':(2,8),'PEWTER_CITY':(2,3),'VIRIDIAN_FOREST':(2,4),'ROUTE_1':(2,10),'ROUTE_2':(2,6),'BLUES_HOUSE':(2,11),'PEWTER_GYM':(2,3)}.items():
   self.assertEqual((d['locations'][key]['x'],d['locations'][key]['y']),point)
  self.assertEqual(d['aliases']['blues_house'],'BLUES_HOUSE')
 def test_escape_allowance_and_destination_are_original_source_not_dungeon_entrance(self):
  text=(REFERENCE/'data/tilesets/escape_rope_tilesets.asm').read_text();values=re.findall(r'^\s*db ([A-Z_]+)',text,re.M)
  self.assertEqual(values,['FOREST','CEMETERY','CAVERN','FACILITY','INTERIOR'])
  d=json.loads((ROOT/'Source/data/fieldItems.json').read_text());self.assertEqual(d['tilesets']['VIRIDIAN_FOREST'],'FOREST');self.assertEqual(d['tilesets']['PEWTER_MART'],'MART')
  code=(REFERENCE/'engine/overworld/special_warps.asm').read_text();self.assertRegex(code,r'bit BIT_ESCAPE_WARP[\s\S]+?ld a, \[wLastBlackoutMap\]')
  self.assertIn('call GiveItem',(REFERENCE/'scripts/BluesHouse.asm').read_text())
  warps=(REFERENCE/'data/maps/special_warps.asm').read_text()
  self.assertRegex(warps,r'\.PewterCity:\s+fly_warp PEWTER_CITY,\s+13, 26')
  self.assertRegex(warps,r'\.PalletTown:\s+fly_warp PALLET_TOWN,\s+5,  6')
 def test_daisy_pokedex_prerequisite_success_only_flag_and_original_shop_rope_stock(self):
  script=(REFERENCE/'scripts/BluesHouse.asm').read_text();self.assertIn('CheckEvent EVENT_GOT_POKEDEX',script)
  give=script[script.index('.give_town_map\n'):script.index('.got_town_map\n',script.index('.give_town_map\n'))]
  self.assertRegex(give,r'call GiveItem\s+jr nc, \.bag_full');self.assertIn('SetEvent EVENT_GOT_TOWN_MAP',give)
  stock=(REFERENCE/'data/items/marts.asm').read_text();self.assertRegex(stock,r'PewterMartClerkText::\s+script_mart POKE_BALL, POTION, ESCAPE_ROPE,')
if __name__=='__main__':unittest.main(verbosity=2)
