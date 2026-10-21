#!/usr/bin/env python3
"""Exact independent source checker for nine capture images + actual jump shadow."""
import argparse,json,sys
from pathlib import Path
from PIL import Image
if __package__ in (None,''):sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from tools import generate_capture_art as capture,generate_jump_art as jump
from tools.visual.event_art import catalog,read_png,difference

def expected_inventory():
    names=["capture_"+entry["name"]for entry in json.loads(capture.MANIFEST.read_text())["assets"]]+["jump_shadow"]
    if len(names)!=10:raise ValueError("runtime art roster changed")
    return sorted(name+suffix+".png"for name in names for suffix in ("","__mask","__white","__black","__texture"))

def expected(reference):
    manifest=json.loads(capture.MANIFEST.read_text());raw=capture.references(reference,manifest)
    images,_=capture.generate(raw,manifest);sources={}
    for name,image in images.items():sources['capture_'+name]=image
    _,raw=jump.references(reference);sources['jump_shadow']=jump.shadow_image(raw)
    result={}
    for name,image in sources.items():
        result[name+'.png']=image;result[name+'__mask.png']=image.getchannel('A').convert('RGBA')
        for bg in ('white','black','texture'):
            base=Image.new('RGBA',image.size,'black'if bg=='black'else'white')
            if bg=='texture':base.putdata([(0,0,0,255)if(x//4+y//4)%2==0 else(255,255,255,255)for y in range(image.height)for x in range(image.width)])
            base.alpha_composite(image);result[name+'__'+bg+'.png']=base
    if len(sources)!=10 or len(result)!=50:raise ValueError('runtime art inventory changed')
    return result

def inspect(reference,directory):
    images=expected(reference);manifest,root,paths=catalog(directory);failures=[]
    metadata={item['path']:item for item in manifest.get('runtime_art',[])}
    for path,image in images.items():
        try:
            actual=read_png(root,paths,path);row=difference(image,actual)
            if not row['equal']:failures.append(dict(path=path,**row))
        except(OSError,ValueError)as error:failures.append(dict(path=path,error=str(error)))
        if '__'not in path:
            entry=metadata.get(path)
            identity='pokered:ledge-shadow:four-oam-quarters'if path=='jump_shadow.png'else'pokered:battle-capture:'+path[len('capture_'):-4]
            if not entry or entry.get('source_revision')!='af519899719f0754965776faac0e836a3b906e6d' or entry.get('source_id')!=identity:failures.append(dict(path=path,error='source metadata missing or changed'))
    return {'ok':not failures,'checked':50,'failures':failures,'added_unreviewed':sorted(images),'review_status':'independent source check only; native scene review remains required'}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-root',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--report',type=Path);args=p.parse_args()
    try:report=inspect(args.reference_root,args.catalog)
    except(OSError,ValueError,KeyError)as error:report={'ok':False,'error':str(error)}
    text=json.dumps(report,indent=2)
    if args.report:args.report.write_text(text+'\n')
    print(text);return 0 if report['ok']else 1
if __name__=='__main__':raise SystemExit(main())
