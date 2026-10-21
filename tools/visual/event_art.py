#!/usr/bin/env python3
"""Read-only exact source oracle for seven native EventArt images/masks/composites.

BLUE's legacy dither phase is calibrated ONLY from reviewed protected standing
images, never from candidate walking pixels. Additions remain unreviewed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image,ImageChops

if __package__ in (None,''):
    sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from tools.visual.paths import contained,image_directory
from tools.generate_overworld_sprites import mask_bytes

REVISION='af519899719f0754965776faac0e836a3b906e6d'
PINS={'gfx/sprites/blue.png':('2134b4c3540a600f9e121b271d61e80da5b05b2ec6ff94b103a5c839bf523999',(16,96)),
      'gfx/sprites/pokedex.png':('9c971143ee561a78368bf96437ff02fb37a096e1f7b5dce3b584dbc11c98475a',(16,16)),
      'gfx/overworld/heal_machine.png':('44450428c793419c0a265541676bc8e8b497ef894e4c8b49068a7b5692bb84ab',(8,16))}
DARK=(0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA)
LIGHT=(0xBB,0xFF,0xEE,0xFF,0xBB,0xFF,0xEE,0xFF)


def specifications():
    result=[]
    for direction,index in (('down',3),('up',4),('left',5),('right',5)):
        result.append(dict(name='event_blue_walk_'+direction,source_id=f'pokered:SPRITE_BLUE:frame:{index}'+(':flip-x' if direction=='right' else ''),
            source_path='gfx/sprites/blue.png',source_frame=index,phase_policy='legacy-omitted',flip_x=direction=='right',width=32,height=32))
    for name,identity,path,index,size in (('event_pokedex','pokered:SPRITE_POKEDEX:frame:0','gfx/sprites/pokedex.png',0,32),
        ('event_heal_monitor','pokered:heal_machine:tile:0','gfx/overworld/heal_machine.png',0,16),
        ('event_heal_ball','pokered:heal_machine:tile:1','gfx/overworld/heal_machine.png',1,16)):
        result.append(dict(name=name,source_id=identity,source_path=path,source_frame=index,phase_policy='explicit-zero',flip_x=False,width=size,height=size))
    return result


def expected_inventory():
    return sorted(item['name']+suffix+'.png' for item in specifications() for suffix in ('','__mask','__white','__black','__texture'))


def load_sources(root):
    root=Path(root);result={}
    for name,(digest,size) in PINS.items():
        path=contained(root,name)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise ValueError('pinned source mismatch: '+name)
        with Image.open(path) as image:
            if image.mode!='L' or image.size!=size or set(image.getdata())!={0,85,170,255}:raise ValueError('source dimensions/palette mismatch: '+name)
            result[name]=image.copy()
    return result


def source_grid(image,index,small=False,greyhair=False):
    size=8 if small else 16
    mapping={255:'.',170:'.' if greyhair else '1',85:'2',0:'#'}
    rows=[''.join(mapping[image.getpixel((x,index*size+y))] for x in range(size)) for y in range(size)]
    if small:rows=[row+'.'*8 for row in rows]+['.'*16]*8
    return rows


def raster(grid,legacy_inversion=0):
    opacity=mask_bytes(grid);image=Image.new('RGBA',(32,32))
    pixels=[]
    for y in range(32):
        for x in range(32):
            code=grid[y//2][x//2];white=code=='.'
            if code in ('1','2'):
                pattern=LIGHT if code=='1' else DARK
                white=bool(pattern[y%8] & (0x80>>(x%8)))
                if legacy_inversion and code=='2':white=not white
            value=255 if white else 0
            pixels.append((value,value,value,opacity[y*32+x]))
    image.putdata(pixels);return image


def clear_transparent_rgb(image):
    # Actual cleared-image draw/flip storage differs from direct white-base
    # SpriteFactory images. Preserve that distinction, including invisible RGB.
    result=image.copy();result.putdata([pixel if pixel[3] else (0,0,0,0) for pixel in image.getdata()]);return result


def difference(expected,actual):
    actual=actual.convert('RGBA');expected=expected.convert('RGBA')
    if actual.size!=expected.size:return dict(equal=False,reason='dimensions',expected_size=expected.size,actual_size=actual.size)
    rgb=ImageChops.difference(expected.convert('RGB'),actual.convert('RGB'))
    alpha=ImageChops.difference(expected.getchannel('A'),actual.getchannel('A'))
    rgbmask=Image.new('L',expected.size);rgbmask.putdata([255 if any(pixel) else 0 for pixel in rgb.getdata()])
    alphamask=alpha.point(lambda value:255 if value else 0);union=ImageChops.lighter(rgbmask,alphamask)
    return dict(equal=union.getbbox() is None,changed_pixels=sum(v!=0 for v in union.getdata()),
                rgb_pixels=sum(v!=0 for v in rgbmask.getdata()),alpha_pixels=sum(v!=0 for v in alphamask.getdata()),bbox=union.getbbox())


def catalog(root):
    root=Path(root);manifest=json.loads((root/'catalog.json').read_text());images=image_directory(root,manifest)
    paths=[entry['path'] for entry in manifest['images']]
    if not paths or len(paths)!=len(set(paths)):raise ValueError('empty/duplicate catalog inventory')
    for path in paths:contained(images,path)
    return manifest,images,set(paths)


def read_png(images,paths,name):
    if name not in paths:raise ValueError('artifact missing from manifest: '+name)
    with Image.open(contained(images,name)) as image:
        if image.format!='PNG':raise ValueError('PNG required: '+name)
        image.load();return image.convert('RGBA')


def standing_references(sources,protected):
    manifest,images,paths=catalog(protected);blue=sources['gfx/sprites/blue.png'];grids={};actual={};candidates=[]
    for direction,index in (('down',0),('up',1),('left',2)):
        grids[direction]=source_grid(blue,index,greyhair=True)
        actual[direction]=read_png(images,paths,'npc_rival_'+direction+'.png')
    # Only the two possible checker phases are permitted, calibrated using all
    # reviewed standing pixels. No fitting to new candidate art is performed.
    for inversion in (0,1):
        if all(difference(raster(grid,inversion),actual[direction])['equal'] for direction,grid in grids.items()):candidates.append(inversion)
    if len(candidates)!=1:raise ValueError('protected BLUE source/phase mismatch or ambiguous calibration')
    inversion=candidates[0]
    grids['right']=[row[::-1] for row in grids['left']]
    actual['right']=read_png(images,paths,'npc_rival_right.png')
    right=clear_transparent_rgb(raster(grids['left'],inversion).transpose(Image.Transpose.FLIP_LEFT_RIGHT))
    if not difference(right,actual['right'])['equal']:raise ValueError('protected BLUE right flip mismatch')
    for direction in grids:
        alpha=actual[direction].getchannel('A').convert('RGBA')
        if not difference(alpha,read_png(images,paths,'npc_rival_'+direction+'__mask.png'))['equal']:
            raise ValueError('protected BLUE standalone mask mismatch: '+direction)
    return inversion,grids,actual


def expected_images(sources,legacy_inversion):
    result={};grids={}
    for spec in specifications():
        name=spec['name'];small=spec['width']==16
        grid=source_grid(sources[spec['source_path']],spec['source_frame'],small=small,greyhair=name.startswith('event_blue_'))
        image=raster(grid,legacy_inversion if spec['phase_policy']=='legacy-omitted' else 0)
        if spec['flip_x']:
            image=clear_transparent_rgb(image.transpose(Image.Transpose.FLIP_LEFT_RIGHT));grid=[row[::-1] for row in grid]
        if small:image=clear_transparent_rgb(image.crop((0,0,16,16)))
        grids[name]=grid;result[name+'.png']=image
        result[name+'__mask.png']=image.getchannel('A').convert('RGBA')
        for background in ('white','black','texture'):
            base=Image.new('RGBA',image.size,'black' if background=='black' else 'white')
            if background=='texture':
                base.putdata([(0,0,0,255) if (x//4+y//4)%2==0 else (255,255,255,255)
                              for y in range(image.height) for x in range(image.width)])
            base.alpha_composite(image);result[name+'__'+background+'.png']=base
    return result,grids


def inspect(reference_root,protected,candidate):
    sources=load_sources(reference_root);inversion,stand_grids,stands=standing_references(sources,protected)
    expected,grids=expected_images(sources,inversion);manifest,images,paths=catalog(candidate)
    failures=[];metadata={entry['path']:entry for entry in manifest.get('event_art',[])}
    for spec in specifications():
        path=spec['name']+'.png';entry=metadata.get(path)
        required=dict(spec,source_revision=REVISION,source_sha256=PINS[spec['source_path']][0],path=path)
        if not entry or any(entry.get(key)!=value for key,value in required.items()):failures.append(dict(path=path,reason='source metadata'))
    loaded={}
    for path,expected_image in expected.items():
        try:
            actual=read_png(images,paths,path);loaded[path]=actual;result=difference(expected_image,actual)
            if not result['equal']:failures.append(dict(path=path,**result))
        except (OSError,ValueError) as error:failures.append(dict(path=path,reason=str(error)))
    shared=[]
    for direction in ('down','up','left','right'):
        name='event_blue_walk_'+direction;image=loaded.get(name+'.png');count=0;points=[]
        if image is not None and image.size==(32,32):
            for y in range(32):
                for x in range(32):
                    if grids[name][y//2][x//2]==stand_grids[direction][y//2][x//2]=='2':
                        count+=1
                        if image.getpixel((x,y))!=stands[direction].getpixel((x,y)):points.append((x,y))
        evidence=dict(direction=direction,shared_hair_pixels=count,mismatched_pixels=len(points))
        shared.append(evidence)
        if not count or points:failures.append(dict(path=name+'.png',reason='shared protected hair phase',**evidence))
    return dict(ok=not failures,source_revision=REVISION,checked_images=len(expected),failures=failures,
                legacy_phase=dict(policy='legacy-omitted',calibrated_from='reviewed protected BLUE standing only',dark_checker_inversion=inversion),
                shared_hair=shared,added_unreviewed=sorted(expected),review_status='source comparison only; native scene/motion review still required')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reference-root',type=Path,required=True)
    parser.add_argument('--protected',type=Path,required=True);parser.add_argument('--catalog',type=Path,required=True);parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    try:report=inspect(args.reference_root,args.protected,args.catalog)
    except (OSError,ValueError,KeyError) as error:report={'ok':False,'error':str(error)}
    text=json.dumps(report,indent=2)
    if args.report:args.report.write_text(text+'\n')
    print(text);return 0 if report['ok'] else 1
if __name__=='__main__':raise SystemExit(main())
