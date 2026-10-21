#!/usr/bin/env python3
"""Assemble original Red/Blue battle ball/poof frames; never redraw sprites.

Only explicit staged output roots are writable. --check compares decoded pixel
bytes and generated Lua without writes. All source pins are mandatory.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/capture-animation.json'
class GenerationError(ValueError):pass

def sha(raw):return hashlib.sha256(raw).hexdigest()
def references(source,manifest):
    source=Path(source).resolve();out={}
    for entry in manifest['inputs']:
        path=(source/entry['path']).resolve()
        if not path.is_relative_to(source):raise GenerationError('reference path escapes root')
        raw=path.read_bytes()
        if sha(raw)!=entry['sha256']:raise GenerationError('pinned source checksum mismatch: '+entry['path'])
        out[entry['path']]=raw
    return out

def number(text):return int(text[1:],16) if text.startswith('$') else int(text)
def block_rows(text,identity):
    match=re.search(r'^FrameBlock'+identity+r':\n(.*?)(?=^FrameBlock\w+:|\Z)',text,re.S|re.M|re.I)
    if not match:raise GenerationError('missing frame block '+identity)
    count=re.search(r'^\s*db (\d+)\s*;',match[1],re.M)
    rows=[]
    for line in match[1].splitlines():
        if not line.strip().startswith('dbsprite '):continue
        parts=[p.strip() for p in line.strip()[len('dbsprite '):].split(',')]
        if len(parts)!=6:raise GenerationError('bad dbsprite row')
        x,y,dx,dy,tile=map(number,parts[:5]);flags=parts[5]
        if dx!=0 or dy!=0 or not 0<=x<=5 or not 0<=y<=5 or not 0<=tile<80:raise GenerationError('unsupported sprite geometry')
        if flags not in ('0','OAM_XFLIP','OAM_YFLIP','OAM_XFLIP | OAM_YFLIP'):raise GenerationError('unsupported sprite flags')
        rows.append((x,y,tile,'OAM_XFLIP' in flags,'OAM_YFLIP' in flags))
    if not count or int(count[1])!=len(rows) or not rows:raise GenerationError('sprite count mismatch')
    return rows

def assemble(sheet,rows,flash=False):
    width=(max(row[0] for row in rows)+1)*8;height=(max(row[1] for row in rows)+1)*8
    result=Image.new('RGBA',(width,height),(255,255,255,0))
    for x,y,tile,flip_x,flip_y in rows:
        tile_image=sheet.crop(((tile%16)*8,(tile//16)*8,(tile%16+1)*8,(tile//16+1)*8))
        if flip_x:tile_image=tile_image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if flip_y:tile_image=tile_image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        pixels=[]
        for shade in tile_image.getdata():
            if shade not in (0,85,170,255):raise GenerationError('non-original palette shade')
            color=({0:0,85:255,170:0,255:255} if flash else {0:0,85:0,170:255,255:255})[shade]
            pixels.append((color,color,color,0 if shade==255 else 255))
        rgba=Image.new('RGBA',(8,8));rgba.putdata(pixels);result.alpha_composite(rgba,(x*8,y*8))
    return result.resize((width*2,height*2),Image.Resampling.NEAREST)

def subanimation(raw,name):
    match=re.search(r'^'+name+r':\n(.*?)(?=^\w+:|\Z)',raw,re.M|re.S)
    if not match:raise GenerationError('missing subanimation '+name)
    rows=re.findall(r'db FRAMEBLOCK_(\w+), BASECOORD_(\w+), FRAMEBLOCKMODE_\w+',match[1])
    return rows

def metadata(raw,manifest):
    coords={label:(int(x,16),int(y,16)) for y,x,label in re.findall(r'db \$(\w+), \$(\w+) ; BASECOORD_(\w+)',raw['data/battle_anims/base_coords.asm'].decode())}
    sub=raw['data/battle_anims/subanimations.asm'].decode()
    profiles={}
    for name in ('High','Middle','Low'):
        rows=subanimation(sub,'Subanim_0BallToss'+name)
        if len(rows)!=11 or any(frame!='03' for frame,_ in rows):raise GenerationError('unexpected toss poses')
        profiles[name.lower()]=[coords[coordinate] for _,coordinate in rows]
    shake=[frame for frame,_ in subanimation(sub,'Subanim_0BallShakeEnemy')]
    poof=[frame for frame,_ in subanimation(sub,'Subanim_0BallPoofEnemy')]
    if shake!=['03','04','03','05'] or poof!=['06','07','08','09','0A','0A']:raise GenerationError('unexpected original capture frame sequence')
    timing=manifest['timing']
    lua=['-- Generated original capture paths/frames; see capture-animation.json.', 'CaptureAnimationData = {','    assets = {']
    for asset in manifest['assets']:lua.append('        ["'+asset['name']+'"] = "/images/battle-capture/'+asset['name']+'",')
    lua+=['    },','    paths = {']
    for name,points in profiles.items():lua.append('        '+name+' = {'+', '.join('{'+str(x)+','+str(y)+'}' for x,y in points)+'},')
    lua+=['    },','    throwHold = {high=3,middle=3,low=2},','    poof = {"poof-1","poof-2","poof-3","poof-4","poof-5","poof-5"},','    shake = {"closed","tilt-left","closed","tilt-right"},','    shakePause = '+str(timing['shake_gb_pause']//2)+',','    dropTicks = '+str(timing['drop_ticks'])+',','    caughtHold = '+str(timing['caught_hold_ticks'])+',','}', '']
    return '\n'.join(lua)

def generate(raw,manifest):
    with Image.open(io.BytesIO(raw['gfx/battle/move_anim_0.png'])) as opened:
        if opened.mode!='L' or list(opened.size)!=manifest['transform']['sheet_size']:raise GenerationError('unexpected original animation sheet')
        sheet=opened.copy()
    if set(sheet.getdata())!={0,85,170,255}:raise GenerationError('unexpected original palette')
    text=raw['data/battle_anims/frame_blocks.asm'].decode()
    assets={}
    for asset in manifest['assets']:
        result=assemble(sheet,block_rows(text,asset['frame_block']),asset['flash'])
        if 'pixel_sha256' in asset and sha(result.tobytes())!=asset['pixel_sha256']:raise GenerationError('generated sprite pixel pin mismatch: '+asset['name'])
        assets[asset['name']]=result
    return assets,metadata(raw,manifest)

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reference-root',type=Path,required=True);parser.add_argument('--output-root',type=Path,required=True);parser.add_argument('--check',action='store_true');args=parser.parse_args(argv)
    try:
        manifest=json.loads(MANIFEST.read_text())
        if manifest.get('schema')!=1 or manifest['transform']['scale']!=2:raise GenerationError('unsupported transform schema')
        output=args.output_root.resolve()
        if not args.check and (output==ROOT or output.is_relative_to(ROOT/'Source')):raise GenerationError('generation requires a staged output root')
        assets,data=generate(references(args.reference_root,manifest),manifest)
        directory=output/'Source/images/battle-capture';data_path=output/'Source/data/captureAnimationData.lua'
        if args.check:
            if data_path.read_text()!=data:raise GenerationError('capture animation metadata drift')
            for name,result in assets.items():
                with Image.open(directory/(name+'.png')) as existing:
                    if existing.size!=result.size or existing.convert('RGBA').tobytes()!=result.tobytes():raise GenerationError('capture asset drift: '+name)
        else:
            directory.mkdir(parents=True,exist_ok=True);data_path.parent.mkdir(parents=True,exist_ok=True)
            for name,result in assets.items():result.save(directory/(name+'.png'))
            data_path.write_text(data)
        print('9 original battle ball/poof assets and capture paths verified/generated');return 0
    except (OSError,ValueError,KeyError) as error:print('capture art failed: '+str(error),file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
