"""Pinned original Town Map transcription; check-only by default, staged writes."""
import argparse,hashlib,json,re
from pathlib import Path
from PIL import Image
REV='af519899719f0754965776faac0e836a3b906e6d'
FILES=['gfx/town_map/town_map.png','gfx/town_map/town_map.rle','gfx/town_map/town_map_cursor.png','constants/map_constants.asm','data/maps/names.asm','data/maps/town_map_entries.asm','data/maps/town_map_order.asm','engine/items/town_map.asm','data/tilesets/escape_rope_tilesets.asm','engine/items/item_effects.asm','engine/overworld/special_warps.asm','scripts/BluesHouse.asm','text/BluesHouse.asm','data/items/marts.asm']
HEADERS=['PalletTown','RedsHouse1F','RedsHouse2F','BluesHouse','OaksLab','Route1','ViridianCity','ViridianMart','ViridianPokecenter','Route2','ViridianForestSouthGate','ViridianForest','ViridianForestNorthGate','PewterCity','PewterGym','PewterMart','PewterPokecenter']
FILES += ['data/maps/headers/'+name+'.asm'for name in HEADERS]+['Makefile','gfx/font.asm','engine/events/set_blackout_map.asm','engine/events/pokecenter.asm','data/maps/special_warps.asm']
def extract(reference):
    read=lambda name:(reference/name).read_text()
    constants={};groups={}
    for line in read('constants/map_constants.asm').splitlines():
        match=re.match(r'\s*map_const (\w+),',line)
        if match:constants[match[1]]=len(constants)
        match=re.match(r'\s*end_indoor_group (\w+)',line)
        if match:groups[match[1]]=len(constants)
    names=dict(re.findall(r'(\w+):\s+db "([^"@]+)@"',read('data/maps/names.asm')))
    names={key:{'source_name':value,'name':value.replace('#MON','POKEMON').replace('<PKMN>','POKEMON')}for key,value in names.items()}
    entries=read('data/maps/town_map_entries.asm')
    outside=[dict(x=int(x),y=int(y),**names[name])for x,y,name in re.findall(r'^\s*outdoor_map\s+(\d+),\s*(\d+),\s*(\w+)',entries,re.M)]
    inside=[(groups[group],dict(x=int(x),y=int(y),**names[name]))for group,x,y,name in re.findall(r'^\s*indoor_map\s+(\w+),\s*(\d+),\s*(\d+),\s*(\w+)',entries,re.M)]
    locations={}
    for name,number in constants.items():
        point=outside[number]if number<len(outside)else next(point for bound,point in inside if number<bound)
        locations[name]=point
    order=re.findall(r'^\s*db (\w+)\s*$',read('data/maps/town_map_order.asm'),re.M)
    palette={255:'.',170:'1',85:'2',0:'#'}
    im=Image.open(reference/'gfx/town_map/town_map.png').convert('L');assert im.size==(32,32)
    tiles=[[''.join(palette[im.getpixel(((index%4)*8+x,(index//4)*8+y))]for x in range(8))for y in range(8)]for index in range(16)]
    cursor=Image.open(reference/'gfx/town_map/town_map_cursor.png').convert('L');assert cursor.size==(16,16)
    cursor_rows=[''.join(palette[cursor.getpixel((x,y))]for x in range(16))for y in range(16)]
    wire=(reference/'gfx/town_map/town_map.rle').read_bytes();assert wire[-1]==0 and 0 not in wire[:-1]
    cells=[]
    for value in wire[:-1]:
        assert value&15
        cells.extend([value>>4]*(value&15))
    assert len(cells)==360
    aliases={'pallet_town':'PALLET_TOWN','reds_house':'REDS_HOUSE_1F','reds_house_2f':'REDS_HOUSE_2F','blues_house':'BLUES_HOUSE','oaks_lab':'OAKS_LAB'}
    tilesets={}
    for name in HEADERS:
        m=re.search(r'map_header\s+\w+,\s*(\w+),\s*(\w+)',read('data/maps/headers/'+name+'.asm'));assert m
        tilesets[m[1]]=m[2]
    return {'aliases':aliases,'tilesets':tilesets,'schema':1,'source_revision':REV,'width':20,'height':18,'tiles':tiles,'cells':cells,'cursor':cursor_rows,'locations':locations,'order':order}
def main():
    project=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,default=project/'tools/references/field-items')
    parser.add_argument('--output-dir',type=Path)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args()
    output=(args.output_dir or project/'Source/data').resolve()
    if args.write and (args.output_dir is None or output.is_relative_to(project/'Source')):
        parser.error('--write requires an explicit candidate directory outside project Source')
    pin=json.loads((project/'tools/references/field-items-source.json').read_text())
    if pin['revision']!=REV or set(pin['files'])!=set(FILES):
        raise ValueError('field source pin inventory changed')
    for name,entry in pin['files'].items():
        if hashlib.sha256((args.reference/name).read_bytes()).hexdigest()!=entry['sha256']:
            raise ValueError('source drift: '+name)
    result=extract(args.reference)
    payloads={'townMap.json':result,'fieldItems.json':{key:result[key]for key in ['schema','source_revision','aliases','tilesets']}}
    for name,data in payloads.items():
        if args.write:
            output.mkdir(parents=True,exist_ok=True)
            (output/name).write_text(json.dumps(data,separators=(',',':'))+'\n')
        elif json.loads((output/name).read_text())!=data:
            raise ValueError('field transcription drift: '+name)
    print(len(result['cells']),len(result['tiles']),len(result['locations']),len(result['order']))
if __name__=='__main__':main()
