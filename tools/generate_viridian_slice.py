#!/usr/bin/env python3
"""Reproduce reviewed Blue Viridian JSON and candidate assets from explicit pinned sources.

No ROM, network, Source writes, Lua transpilation, or Simulator launch.
"""
import argparse,hashlib,importlib.util,io,json,re,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE_PIN=ROOT/"tools/references/viridian-slice-source.json"
MAPS=('Route1','ViridianCity','ViridianMart','ViridianPokecenter')
SPRITES=('youngster','gambler','girl','gambler_asleep','fisher','clerk','cooltrainer_m','nurse','gentleman','link_receptionist')
REVISION='af519899719f0754965776faac0e836a3b906e6d'
def load():
 spec=importlib.util.spec_from_file_location('base_generator',ROOT/'tools/generate_kanto_maps.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def text_recipes(text):
 result={};label=None
 for number,line in enumerate(text.splitlines(),1):
  found=re.match(r'^(_\w+)::',line)
  if found:label=found[1];result[label]=[];continue
  if label:
   clean=line.split(';',1)[0].strip()
   if not clean:continue
   match=re.fullmatch(r'(text|line|cont|para|next)\s+"(.*)"',clean)
   if match:result[label].append({'op':match[1],'text':match[2],'source_line':number})
   elif clean.startswith('text_ram '):result[label].append({'op':'text_ram','symbol':clean.split()[1],'source_line':number})
   else:result[label].append({'op':'control','source':clean,'source_line':number})
 return result

def sprite_data(reference,name):
 path='gfx/sprites/'+name+'.png';raw=reference.bytes(path)
 im=Image.open(io.BytesIO(raw));im.load()
 if im.mode!='L' or im.width!=16 or im.height not in (16,48,96) or set(im.getdata())!={0,85,170,255}:raise ValueError('unexpected sprite strip '+name)
 frames={};mapping={255:'.',170:'1',85:'2',0:'#'}
 for index in range(im.height//16):frames[str(index)]=[''.join(mapping[im.getpixel((x,index*16+y))] for x in range(16)) for y in range(16)]
 return {'id':'pokered:sprite:'+name,'source':path,'sha256':hashlib.sha256(raw).hexdigest(),'mapping':'faithful four original shades; candidate, no protected NPC changes','size':list(im.size),'fixed':im.height==16,'standing':{'down':0,'up':1,'left':2} if im.height>=48 else {'down':0},'walking':{'down':3,'up':4,'left':5} if im.height==96 else {},'right':'mirror original left frame when directional','frames':frames}

def build(reference):
 g=load();pin=json.loads(SOURCE_PIN.read_text())
 if pin.get('revision')!=REVISION:raise ValueError('Viridian source pin revision mismatch')
 pins={r['path']:r['sha256'] for r in pin['files']};ref=g.Reference(reference,pins)
 maps={name:g.decode_map(ref,name) for name in MAPS}
 for name,d in maps.items():
  d['runtime_adapter']['padding_cells']=[max(0,(13-d['dimensions']['cells'][0])//2),0]
  for section in ('grass','water'):
   for slot in d['encounters'][section]['slots']:
    source=slot['species_source'];assert source in ('PIDGEY','RATTATA'), 'new encounter species must get explicit mapping'
    slot['species']={'PIDGEY':'pidgey','RATTATA':'rattata'}[source]
 sprites={name:sprite_data(ref,name) for name in SPRITES}
 text={}
 for path in ['text/Route1.asm','text/ViridianCity.asm','text/ViridianMart.asm','text/ViridianPokecenter.asm','text/OaksLab.asm','data/text/text_4.asm','data/text/text_1.asm']:
  for key,value in text_recipes(ref.text(path)).items():
   if key in text:raise ValueError('duplicate text label')
   text[key]={'source':path,'recipe':value}
 for path in ['scripts/OaksLab.asm','engine/events/pokecenter.asm','data/items/marts.asm','data/sprites/facings.asm','gfx/sprites.asm','engine/overworld/ledges.asm','home/map_objects.asm','home/overworld.asm','engine/events/set_blackout_map.asm','data/maps/special_warps.asm']:
  ref.bytes(path)
 out={}
 for name,d in maps.items():out['maps/'+name+'.json']=g.json_bytes(d);out['catalog/'+name+'-native.png']=g.render_map(d);out['catalog/'+name+'-reference.png']=g.render_map(d,False)
 # Candidate sprite previews preserve exact grids; opacity is the same border
 # flood-fill rule as the accepted SpriteFactory, never white-key transparency.
 sprite_spec=importlib.util.spec_from_file_location('sprite_generator',ROOT/'tools/generate_overworld_sprites.py')
 sg=importlib.util.module_from_spec(sprite_spec);sprite_spec.loader.exec_module(sg)
 catalog=[]
 for name,sprite in sprites.items():
  for frame,grid in sprite['frames'].items():
   raw=g.render_map({'dimensions':{'cells':[1,1]},'grids':[{'id':1,'grid':grid}],'tile_ids':[[1]]})
   image=Image.open(io.BytesIO(raw)).convert('RGBA');mask=Image.frombytes('L',(32,32),sg.mask_bytes(grid));image.putalpha(mask)
   for kind,im in [('image',image),('mask',mask)]:
    stream=io.BytesIO();im.save(stream,format='PNG');filename=f'catalog/sprite-{name}-{frame}-{kind}.png';out[filename]=stream.getvalue()
   catalog.append({'id':sprite['id']+':frame:'+frame,'path':f'sprite-{name}-{frame}-image.png','mask':f'sprite-{name}-{frame}-mask.png','grid_sha256':hashlib.sha256(''.join(grid).encode()).hexdigest()})
 out['catalog/catalog.json']=g.json_bytes({'schema':1,'image_root':'.','status':'candidate Python phase0 preview; actual SDK catalog acceptance pending','images':catalog})
 item_ids={name:index for index,name in enumerate(re.findall(r'^\s*const (\w+)',ref.text('constants/item_constants.asm'),re.M))}
 prices={name:int(price) for price,name in re.findall(r'^\s*bcd3 (\d+)\s*; (\w+)',ref.text('data/items/prices.asm'),re.M)}
 key_items={name:value=='TRUE' for value,name in re.findall(r'^\s*dbit (TRUE|FALSE)\s*; (\w+)',ref.text('data/items/key_items.asm'),re.M)}
 items={}
 for source,stable in {'POKE_BALL':'pokeBall','ANTIDOTE':'antidote','PARLYZ_HEAL':'parlyzHeal','BURN_HEAL':'burnHeal','POTION':'potion','OAKS_PARCEL':'oaksParcel'}.items():
  items[stable]={'source':source,'source_id':item_ids[source],'price':prices[source],'keyItem':key_items[source]}
 out['items.json']=g.json_bytes({'schema':1,'source_revision':REVISION,'items':items,'mart_stock':['pokeBall','antidote','parlyzHeal','burnHeal'],'policy':'Blue shop stock/prices; GenV item effects remain separate runtime policy'})
 out['sprites.json']=g.json_bytes({'schema':1,'source_revision':REVISION,'sprites':sprites})
 out['dialogue.json']=g.json_bytes({'schema':1,'source_revision':REVISION,'texts':text})
 out['manifest.json']=g.json_bytes({'schema':1,'source_revision':REVISION,'version':'English Blue','maps':list(MAPS),'sprites':list(SPRITES),'source_files':ref.consumed,'artifacts':{name:hashlib.sha256(data).hexdigest() for name,data in out.items()},'status':'staged data only; bindings, NPC rendering and natural journey acceptance pending'})
 return out

def source_artifacts(artifacts):
 return {name:artifacts['maps/'+name] if name in [n+'.json' for n in MAPS] else artifacts[name]
         for name in [n+'.json' for n in MAPS]+['sprites.json','dialogue.json']}

def check_source(artifacts, directory):
 directory=Path(directory).resolve();expected=source_artifacts(artifacts)
 if {path.name for path in directory.glob('*.json')}!=set(expected):raise ValueError('Source JSON inventory mismatch')
 for name,data in expected.items():
  if (directory/name).read_bytes()!=data:raise ValueError('Source JSON differs from pinned generation: '+name)
 return len(expected)

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--reference',required=True)
 p.add_argument('--output',type=Path)
 p.add_argument('--check',action='store_true',help='check complete existing --output without writing')
 p.add_argument('--check-source',nargs='?',const=ROOT/'Source/data/viridianSlice',type=Path,help='check exact current six Source JSONs; never write Source')
 a=p.parse_args()
 if bool(a.output)==bool(a.check_source):p.error('choose exactly one of --output or --check-source')
 if a.check and not a.output:p.error('--check requires --output')
 artifacts=build(a.reference)
 if a.check_source:
  print('exact pinned Source JSONs: '+str(check_source(artifacts,a.check_source)));return
 out=a.output.resolve()
 if out.is_relative_to(ROOT/'Source'):raise ValueError('Source writes forbidden; use --check-source or a review output directory')
 if a.check:
  actual={str(f.relative_to(out)) for f in out.rglob('*') if f.is_file()}
  if actual!=set(artifacts):raise ValueError('artifact inventory mismatch')
  for name,data in artifacts.items():
   if (out/name).read_bytes()!=data:raise ValueError('artifact changed: '+name)
 else:
  if out.exists():raise ValueError('fresh output directory required')
  for name,data in artifacts.items():path=out/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 print(out)
if __name__=='__main__':main()
