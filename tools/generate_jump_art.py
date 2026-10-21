#!/usr/bin/env python3
"""Reproduce original jump data and exactly check native shadow pixels/mask.

No implicit downloads, Source writes, baseline updates or image approximation.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys
from PIL import Image,ImageChops

if __package__ in (None,''):
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.generate_overworld_sprites import mask_bytes
from tools.visual.paths import contained

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/jump-art.json'
FILES={'engine/overworld/player_animations.asm','engine/overworld/ledges.asm','gfx/overworld/shadow.png',
       'home/oam.asm','engine/gfx/sprite_oam.asm','home/overworld.asm','engine/overworld/auto_movement.asm'}


def references(reference,manifest_path=MANIFEST):
    manifest=json.loads(Path(manifest_path).read_text())
    if manifest.get('schema')!=1 or manifest.get('repository')!='https://github.com/pret/pokered' or manifest.get('revision')!='af519899719f0754965776faac0e836a3b906e6d':
        raise ValueError('unrecognized original jump source pin')
    if set(manifest.get('files',{}))!=FILES:raise ValueError('jump provenance requires exactly seven pinned inputs')
    sources={}
    for name,digest in manifest['files'].items():
        if not isinstance(digest,str) or not re.fullmatch('[0-9a-f]{64}',digest):raise ValueError('invalid source checksum')
        raw=contained(reference,name).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('source checksum mismatch: '+name)
        sources[name]=raw
    return manifest,sources


def derive(sources):
    text=sources['engine/overworld/player_animations.asm'].decode('utf-8')
    match=re.search(r'^PlayerJumpingYScreenCoords:\s*\n(?:;[^\n]*\n)*\s*db ([^\n]+)',text,re.M)
    if not match:raise ValueError('missing original jump curve')
    tokens=[token.strip()for token in match[1].split(',')]
    if any(not re.fullmatch(r'\$[0-9a-fA-F]{2}',token)for token in tokens):raise ValueError('unsupported jump curve encoding')
    curve=[int(token[1:],16)for token in tokens]
    if len(curve)!=16 or curve[-1]!=60:raise ValueError('unexpected original sixteen-sample jump curve')
    block=sources['engine/overworld/ledges.asm'].decode('utf-8').split('LedgeHoppingShadowOAMBlock:',1)[1]
    attrs=re.findall(r'^\s*db \$ff, (.*)$',block,re.M)
    if attrs!=['OAM_PAL1','OAM_XFLIP','OAM_YFLIP','OAM_XFLIP | OAM_YFLIP']:raise ValueError('unexpected original shadow transforms')
    with Image.open(io.BytesIO(sources['gfx/overworld/shadow.png']))as opened:
        if opened.format!='PNG' or opened.mode!='1' or opened.size!=(8,8) or set(opened.getdata())!={0,255}:raise ValueError('unexpected original8x8 two-shade shadow')
        quarter=opened.copy()
    rows=[''.join('#'if quarter.getpixel((x if x<8 else 15-x,y if y<8 else 15-y))==0 else '.'for x in range(16))for y in range(16)]
    return curve,[(value-60)*2 for value in curve],rows


def generate(manifest,sources):
    curve,native,rows=derive(sources)
    lines=['-- Generated from pinned original16-sample curve and original8x8 shadow/OAM flips.','KantoJumpData = {',f'    revision = "{manifest["revision"]}",',
           '    sourceY = {'+','.join(map(str,curve))+'},','    nativeOffsets = {'+','.join(map(str,native))+'},','    shadowGrid = {']
    lines+=['        "'+row+'",'for row in rows]
    lines+=['    },','    -- Source shadow screen top68 minus standing player top60 =8 source px.','    shadowOffsetFromStandingTop = 16,','}','']
    return '\n'.join(lines).encode('utf-8')


def shadow_image(sources):
    _,_,rows=derive(sources);alpha=mask_bytes(rows)
    image=Image.new('RGBA',(32,32));image.putdata([(0,0,0,alpha[y*32+x])if rows[y//2][x//2]=='#'else(255,255,255,alpha[y*32+x])for y in range(32)for x in range(32)])
    return image


def pixel_difference(expected,actual):
    before,after=expected.convert('RGBA'),actual.convert('RGBA')
    if before.size!=after.size:return {'equal':False,'reason':'dimensions','expected_size':before.size,'actual_size':after.size}
    rgb=ImageChops.difference(before.convert('RGB'),after.convert('RGB'));alpha=ImageChops.difference(before.getchannel('A'),after.getchannel('A'))
    rgbmask=Image.new('L',before.size);rgbmask.putdata([255 if any(value)else 0 for value in rgb.getdata()])
    alphamask=alpha.point(lambda value:255 if value else 0);union=ImageChops.lighter(rgbmask,alphamask)
    return {'equal':union.getbbox()is None,'changed_pixels':sum(value!=0 for value in union.getdata()),
            'rgb_pixels':sum(value!=0 for value in rgbmask.getdata()),'alpha_pixels':sum(value!=0 for value in alphamask.getdata()),'bbox':union.getbbox()}


def check_native(sources,image_path,mask_path=None):
    expected=shadow_image(sources)
    with Image.open(image_path)as actual:
        if actual.format!='PNG':raise ValueError('native shadow must be PNG')
        result={'image':pixel_difference(expected,actual)}
    if mask_path:
        with Image.open(mask_path)as actual:
            if actual.format!='PNG':raise ValueError('native mask must be PNG')
            result['mask']=pixel_difference(expected.getchannel('A'),actual)
    result['ok']=all(value['equal']for value in result.values())
    return result


def writable_candidate(path,reference):
    target=Path(path).resolve()
    if target.is_relative_to(ROOT/'Source') or target==ROOT or target.is_relative_to(Path(reference).resolve()):raise ValueError('output must be outside live Source and pinned inputs')
    return target


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reference-root',type=Path,required=True)
    mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument('--check',type=Path);mode.add_argument('--output',type=Path)
    parser.add_argument('--native-image',type=Path);parser.add_argument('--native-mask',type=Path);parser.add_argument('--report',type=Path)
    args=parser.parse_args(argv)
    try:
        if args.native_mask and not args.native_image:raise ValueError('--native-mask requires --native-image')
        manifest,sources=references(args.reference_root);data=generate(manifest,sources)
        curve,offsets,_=derive(sources)
        report={'ok':True,'revision':manifest['revision'],'source_files':manifest['files'],'samples':len(curve),'native_offsets':offsets,
                'data_sha256':hashlib.sha256(data).hexdigest(),'review_status':'deterministic source reproduction; native scene review separate'}
        if args.check:
            report['data_equal']=args.check.read_bytes()==data;report['ok']=report['data_equal']
        else:
            target=writable_candidate(args.output,args.reference_root);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('xb')as stream:stream.write(data)
            report['candidate']=str(target)
        if args.native_image:
            report['native']=check_native(sources,args.native_image,args.native_mask);report['ok']=report['ok']and report['native']['ok']
    except (OSError,ValueError,KeyError,IndexError)as error:report={'ok':False,'error':str(error)}
    text=json.dumps(report,indent=2)
    if args.report:
        try:writable_candidate(args.report,args.reference_root).write_text(text+'\n',encoding='utf-8')
        except (OSError,ValueError)as error:print(str(error),file=sys.stderr);return 1
    print(text);return 0 if report['ok']else 1
if __name__=='__main__':raise SystemExit(main())
