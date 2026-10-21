#!/usr/bin/env python3
"""Strict read-only source oracle for comprehensive Pewter additions."""
import argparse, hashlib, io, json, re, sys
from pathlib import Path
from PIL import Image, ImageOps

PIN=Path(__file__).resolve().parents[1]/'references/comprehensive-catalog.json'
STARTS={'Route2':(8,71),'ViridianForestSouthGate':(5,7),'ViridianForest':(16,47),'ViridianForestNorthGate':(5,7),'PewterCity':(18,35),'PewterGym':(5,13),'PewterMart':(5,7),'PewterPokecenter':(3,7)}
FACING={'DOWN':'down','UP':'up','LEFT':'left','RIGHT':'right','NONE':'down','UP_DOWN':'down','LEFT_RIGHT':'left'}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def data(project,path,pins):
    target=project/path
    if digest(target)!=pins['runtime_files'][path]:raise ValueError('runtime source input drift: '+path)
    return json.loads(target.read_text())
def tile_name(key):return 'tile_imported_'+key.encode().hex()
def pose_specs(source):
    result=[]
    for constant,binding in sorted(source['mapping'].items()):
        strip=source['sprites'][binding['name']]
        for pose in ('stand','walk','alternate'):
            if pose!='stand' and not strip['walking']:continue
            for direction in ('down','up','left','right'):
                fixed=strip['fixed'] and pose=='stand'
                source_dir='left' if direction=='right' else direction
                index=strip['standing']['down'] if fixed else strip['standing' if pose=='stand' else 'walking'][source_dir]
                flip=not fixed and (direction=='right' or pose=='alternate' and direction in ('up','down'))
                result.append(dict(name=f"pewter-pose-{binding['name']}-{pose}-{direction}",source=constant,source_id=strip['id'],source_path=strip['source'],source_frame=index,flip_x=bool(flip),pose=pose,direction=direction))
    return result

def inventory(project,pins):
    source=data(project,'Source/data/pewterSlice/sprites.json',pins)
    tiles=data(project,'Source/data/pewterSlice/tile-grids.json',pins)['tiles']
    protected=json.loads((project/'docs/validation/catalog-viridian/catalog.json').read_text())
    old={row['key'] for row in protected['tiles']};paths=set()
    for name,strip in source['sprites'].items():
        for frame in strip['frames']:paths.update((f'pewter-sprite-{name}-{frame}.png',f'pewter-mask-{name}-{frame}.png'))
    for key in tiles.keys()-old:paths.update((tile_name(key)+'.png',tile_name(key)+'__mask.png'))
    for name in pins['maps']:paths.update(f'pewter-{name}-{kind}.png' for kind in ('terrain','collision','actors','events','viewport'))
    paths.update(('pewter-exclamation.png','pewter-exclamation-mask.png'))
    paths.update(f'pewter-exclamation__{bg}.png' for bg in ('white','black','texture'))
    for row in pose_specs(source):paths.update(row['name']+suffix+'.png' for suffix in ('','__mask','__white','__black','__texture'))
    if len(paths)!=859:raise ValueError('source addition inventory changed')
    return paths

def expected(project,reference,pins):
    from tools import generate_kanto_maps as g
    from tools.visual.event_art import raster,source_grid,clear_transparent_rgb
    refs=g.Reference(reference,pins['files'])
    # Re-decode original headers/blocks/graphics/events, not candidate previews.
    definitions={name:g.decode_map(refs,name) for name in pins['maps']}
    source=data(project,'Source/data/pewterSlice/sprites.json',pins)
    grids={}
    def sprite(constant,index,flip=False):
        binding=source['mapping'][constant];strip=source['sprites'][binding['name']]
        if strip['source'] not in pins['files'] or strip['sha256']!=pins['files'][strip['source']]:raise ValueError('sprite provenance drift')
        raw=refs.bytes(strip['source']);im=Image.open(io.BytesIO(raw)).convert('L')
        if im.size!=tuple(strip['size']) or not set(im.getdata())<={0,85,170,255}:raise ValueError('source strip dimensions/palette')
        grid=source_grid(im,index)
        if grid!=strip['frames'][str(index)]:raise ValueError('runtime sprite grid differs from source')
        result=raster(grid)
        return clear_transparent_rgb(ImageOps.mirror(result)) if flip else result
    result={}
    def asset(stem,image,mask_name=None,backgrounds=False):
        result[stem+'.png']=image;result[(mask_name or stem+'__mask')+'.png']=image.getchannel('A').convert('RGBA')
        if backgrounds:
            for bg in ('white','black','texture'):
                paper=Image.new('RGBA',image.size,'black' if bg=='black' else 'white')
                if bg=='texture':paper.putdata([(0,0,0,255) if (x//4+y//4)%2==0 else (255,255,255,255) for y in range(image.height) for x in range(image.width)])
                paper.alpha_composite(image);result[stem+'__'+bg+'.png']=paper
    for constant,binding in source['mapping'].items():
        for frame in source['sprites'][binding['name']]['frames']:
            asset(f"pewter-sprite-{binding['name']}-{frame}",sprite(constant,int(frame)),f"pewter-mask-{binding['name']}-{frame}")
    for row in pose_specs(source):asset(row['name'],sprite(row['source'],row['source_frame'],row['flip_x']),backgrounds=True)
    descriptors=data(project,'Source/data/pewterSlice/descriptors.json',pins)['maps']
    compact=data(project,'Source/data/pewterSlice/compact.json',pins)['maps']
    for name,d in definitions.items():
        # Verify source-derived canonical tile grids independently of Lua IDs.
        for entry in d['grids']:
            key=entry['stable_id']
            if key in grids and grids[key]!=entry['grid']:raise ValueError('canonical source grid conflict')
            grids[key]=entry['grid']
        width,height=d['dimensions']['cells'];pad=max(0,(13-width)//2);runtime_width=max(13,width)
        desc=descriptors[name]
        if (desc['width'],desc['height'],desc['padding'])!=(runtime_width,height,pad):raise ValueError('runtime map adapter mismatch')
        original=Image.open(io.BytesIO(g.render_map(d))).convert('RGBA')
        terrain=Image.new('RGBA',(runtime_width*32,height*32),'black');terrain.paste(original,(pad*32,0))
        result[f'pewter-{name}-terrain.png']=terrain
        blocked={str(event['y']*runtime_width+event['x']+pad+1):event['id'] for event in d['events']['warps'] if event['destination']['kind']!='last_outdoor_map' and event['destination'].get('map') not in {x['source_map_constant'] for x in definitions.values()}}
        if compact[name]['blocked']!=blocked:raise ValueError('unsupported source warp blockers differ')
        collision=Image.new('RGBA',terrain.size,'black')
        from PIL import ImageDraw
        draw=ImageDraw.Draw(collision)
        for y,row in enumerate(d['collision']):
            for x,value in enumerate(row):
                if not value and str(y*runtime_width+x+pad+1) not in blocked:draw.rectangle(((x+pad)*32,y*32,(x+pad+1)*32-1,(y+1)*32-1),fill='white')
        result[f'pewter-{name}-collision.png']=collision
        actors=terrain.copy()
        for event in d['events']['objects']:
            strip=source['sprites'][source['mapping'][event['sprite']]['name']]
            direction=FACING.get(event['range_or_facing'],'down');index=strip['standing']['left' if direction=='right' else direction]
            actors.alpha_composite(sprite(event['sprite'],index,direction=='right'),((event['x']+pad)*32,event['y']*32-8))
        result[f'pewter-{name}-actors.png']=actors
        sx,sy=STARTS[name];cx=max(0,min(terrain.width-400,sx*32-200));cy=max(0,min(terrain.height-240,sy*32-120))
        result[f'pewter-{name}-viewport.png']=terrain.crop((cx,cy,cx+400,cy+240))
    grids['adapter:pewter:void']=['#'*16]*16
    runtime_tiles=data(project,'Source/data/pewterSlice/tile-grids.json',pins)['tiles']
    for key,entry in runtime_tiles.items():
        if entry['grid']!=grids[key]:raise ValueError('runtime tile source mismatch: '+key)
        image=Image.open(io.BytesIO(g.render_map({'dimensions':{'cells':[1,1]},'grids':[{'id':1,'grid':entry['grid']}],'tile_ids':[[1]]}))).convert('RGBA')
        result[tile_name(key)+'.png']=image;result[tile_name(key)+'__mask.png']=Image.new('RGBA',(32,32),'white')
    emote=Image.open(io.BytesIO(refs.bytes('gfx/emotes/shock.png'))).convert('L')
    shock=raster(source_grid(emote,0));asset('pewter-exclamation',shock,'pewter-exclamation-mask',True)
    return result,definitions,descriptors,refs

def overlay_check(project,pins,manifest,root,paths,definitions,descriptors,refs):
    from tools.visual.event_art import read_png,difference
    from tools import generate_kanto_maps as g
    from PIL import ImageDraw
    native={row['name']:row for row in manifest['exporters']['pewter']['maps']}
    hidden=[];current=None;ordinal=0;constants={d['source_map_constant'] for d in definitions.values()}
    for line in refs.text('data/events/hidden_events.asm').splitlines():
        marker=g.records(line,'hidden_events_for')
        if marker:current=marker[0]['args'][0];ordinal=0
        for row in g.records(line,'hidden_event'):
            if current not in constants:continue
            ordinal+=1;x,y,handler,argument=row['args'];hidden.append(dict(id=f'pokered:{current}:hidden:{ordinal}',map_id='pokered:'+current,x=g.integer(x),y=g.integer(y),handler_source=handler,argument_source=argument))
    results=[]
    for name,d in definitions.items():
        pad=descriptors[name]['padding'];expected=[];boxes=[]
        for kind in ('objects','background_events','warps'):
            for event in d['events'][kind]:expected.append((event['id'],kind,event['x']+pad,event['y']));boxes.append(((event['x']+pad)*32,event['y']*32,True))
        for event in hidden:
            if event['map_id']==d['id']:expected.append((event['id'],'hidden',event['x']+pad,event['y']));boxes.append(((event['x']+pad)*32,event['y']*32,True))
        actual=native[name]
        if sorted(expected)!=sorted((x['id'],x['kind'],x['x'],x['y']) for x in actual['events']):raise ValueError('source event/hidden inventory mismatch: '+name)
        if {(c['direction'],c['target_map']) for c in d['connections']}!={(c['direction'],c['target_map']) for c in actual['connections']}:raise ValueError('source connection inventory mismatch')
        image=read_png(root,paths,f'pewter-{name}-events.png');terrain=read_png(root,paths,f'pewter-{name}-terrain.png')
        for c in d['connections']:
            direction=c['direction'];x=0 if direction=='west' else image.width-32 if direction=='east' else image.width//2-16;y=0 if direction=='north' else image.height-32 if direction=='south' else image.height//2-16
            boxes.append((x,y,False))
        allowed=Image.new('1',image.size);draw=ImageDraw.Draw(allowed)
        for x,y,event in boxes:
            draw.rectangle((x,y,x+31,y+31),fill=1)
            if event and image.getpixel((x+1,y+1))[:3]!=(0,0,0):raise ValueError('event marker border missing: '+name)
        outside=0
        for a,b,marked in zip(image.getdata(),terrain.getdata(),allowed.getdata()):
            if a[3]!=255:raise ValueError('event overlay unexpectedly transparent')
            if not marked and a!=b:outside+=1
        if outside:raise ValueError(f'event overlay changes outside source cells: {name}: {outside}')
        if boxes and difference(image,terrain)['equal']:raise ValueError('event overlay contains no markers')
        results.append({'map':name,'source_events':len(expected),'connections':len(d['connections']),'outside_marker_changes':outside,'text_glyphs':'native review required; no font tolerance applied to other artifacts'})
    return results

def verify_inventory(paths,protected,added):
    paths=list(paths)
    if len(paths)!=len(set(paths)):raise ValueError('duplicate comprehensive path')
    for path in paths:
        if not re.fullmatch(r'[A-Za-z0-9_-]+[.]png',path) or len(path)>255:raise ValueError('unsafe comprehensive path')
    if len(paths)!=2494 or set(paths)!=set(protected)|set(added) or set(protected)&set(added):raise ValueError('incomplete/undeclared comprehensive image inventory')

def inspect(project,reference,actual,protected,pin=PIN):
    sys.path.insert(0,str(project))
    from tools.visual.event_art import catalog,read_png,difference
    from tools.visual.compare import compare_catalog
    pins=json.loads(pin.read_text())
    if pins['revision']!='af519899719f0754965776faac0e836a3b906e6d':raise ValueError('unsupported source revision')
    if digest(project/'docs/validation/catalog-viridian/catalog.json')!=pins['protected_manifest_sha256']:raise ValueError('reviewed protected manifest changed')
    for path,expected_sha in pins['runtime_files'].items():
        if digest(project/path)!=expected_sha:raise ValueError('runtime source input drift: '+path)
    if digest(protected/'catalog.json')!=pins['protected_manifest_sha256']:raise ValueError('wrong protected catalog manifest')
    manifest,root,paths=catalog(actual);added=inventory(project,pins)
    protected_paths={row['path'] for row in json.loads((protected/'catalog.json').read_text())['images']}
    verify_inventory(paths,protected_paths,added)
    metadata={row['name']:row for row in manifest['exporters']['pewter']['characters']}
    source=data(project,'Source/data/pewterSlice/sprites.json',pins)
    for wanted in pose_specs(source):
        actual_meta=metadata.get(wanted['name'],{})
        for key,value in wanted.items():
            if actual_meta.get(key)!=value:raise ValueError('source pose metadata mismatch: '+wanted['name']+':'+key)
    preservation=compare_catalog(protected,actual,protected_preservation=True)
    images,definitions,descriptors,refs=expected(project,reference,pins);failures=[]
    for path,image in images.items():
        row=difference(image,read_png(root,paths,path))
        if not row['equal']:failures.append(dict(path=path,**row))
    overlays=overlay_check(project,pins,manifest,root,paths,definitions,descriptors,refs)
    return {'ok':preservation['comparison_ok'] and not failures,'equal':False,'protected_equal':preservation['protected_equal'],'protected_checked':1635,'added_unreviewed':sorted(added),'source_rgba_checked':len(images),'source_failures':failures,'event_geometry_checks':overlays,'review_complete':False,'limitation':'event text glyphs and all added native views require root visual review; additions are not automatically reviewed'}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--project',type=Path,required=True);parser.add_argument('--reference-root',type=Path,required=True);parser.add_argument('--catalog',type=Path,required=True);parser.add_argument('--protected-catalog',type=Path,required=True);parser.add_argument('--report',type=Path,required=True);args=parser.parse_args()
    try:report=inspect(args.project.resolve(),args.reference_root.resolve(),args.catalog.resolve(),args.protected_catalog.resolve())
    except (OSError,ValueError,KeyError,IndexError) as error:report={'ok':False,'error':str(error)}
    if args.report.exists():parser.error('refusing to overwrite source report')
    args.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ('added_unreviewed','source_failures','event_geometry_checks')}));return 0 if report['ok'] else 1
if __name__=='__main__':raise SystemExit(main())
