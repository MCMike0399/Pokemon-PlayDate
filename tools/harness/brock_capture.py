"""Concrete Brock presentation evidence; no game ticks, input or RNG writes."""
import hashlib,json
from pathlib import Path
from tools.harness.protocol import ProtocolError

def visual_preflight(scenario):
    if any(group.get('journey',{}).get('name')in {'brock-natural','brock-continue','cerulean-natural','cerulean-continue','vermilion-natural','vermilion-continue'}for group in scenario.get('processes',[scenario])):
        try:from PIL import Image
        except ImportError as error:raise ProtocolError('Brock presentation proof requires Pillow; install tools/requirements-dev.txt')from error

def qualify(build,png,state,kind):
    from PIL import Image
    png=Path(png)
    if state.get('frame',{}).get('phase')!='completed':raise ProtocolError('Brock capture lacks a completed native frame')
    with Image.open(png)as opened:
        if opened.format!='PNG'or opened.size!=(400,240):raise ProtocolError('Brock capture must be a native400x240 PNG')
        image=opened.convert('RGBA');image.load()
    if image.getchannel('A').getextrema()!=(255,255):raise ProtocolError('Brock capture must be opaque')
    if len(set(image.getdata()))<2:raise ProtocolError('Brock capture is blank; semantic success does not qualify presentation')
    report={'method':'native-panel-nonblank-RGBA','kind':kind,'png_sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'tick':state['frame']['tick']}
    if kind=='world':
        player=state.get('player',{})
        if state.get('root')!='overworld'or state.get('overworld')!='explore'or player.get('settled')is not True or any(player.get(k)for k in ['moving','isJumping','pendingEdgeDoor']):raise ProtocolError('Brock world capture requires settled exploration')
        from tools.harness.motion_journey import verify_rendered_poses
        poses=verify_rendered_poses(build,png,state)
        if sum(actor['opaque_pixels_checked']for actor in poses['actors'])<32:raise ProtocolError('Brock world capture lacks visible source actors')
        report.update(poses)
    elif kind=='title':
        if state.get('root')!='title'or state.get('title',{}).get('phase')!='menu':raise ProtocolError('Brock title evidence requires actual title menu')
        menu=state['title'].get('menu',{});options=menu.get('options',[]);selected=state['title'].get('selected')
        if not isinstance(options,list)or options.count('CONTINUE')!=1 or type(selected)is not int or selected!=options.index('CONTINUE')+1:raise ProtocolError('Brock title evidence requires selected real CONTINUE')
    elif kind=='saved-dialog':
        if state.get('root')!='dialog'or state.get('dialog',{}).get('ready')is not True or state.get('pause',{}).get('lastSave',{}).get('ok')is not True:raise ProtocolError('Brock Save evidence requires ready successful save dialog')
    else:raise ProtocolError('unknown bounded Brock capture kind')
    return report

def identify(client,state,label):
    evidence=Path(client.evidence);prefix=f'{client.sequence:05d}'
    request=evidence/(prefix+'-request.json');result=evidence/(prefix+'-result.json')
    q=json.loads(request.read_text());r=json.loads(result.read_text())
    for key in ['build_id','session_id']:
        if q.get(key)!=client.identity[key]or r.get(key)!=client.identity[key]:raise ProtocolError('Brock capture belongs to another '+key)
    if q.get('id')!=r.get('id')or r.get('status')!='ok'or r.get('snapshot')!=state:raise ProtocolError('Brock capture receipt does not match completed shot snapshot')
    if q.get('commands')!=['shot '+label]:raise ProtocolError('Brock capture request is not its identified shot')
    return {'request_id':r['id'],'build_id':r['build_id'],'session_id':r['session_id'],'request_sha256':hashlib.sha256(request.read_bytes()).hexdigest(),'result_sha256':hashlib.sha256(result.read_bytes()).hexdigest(),'request':request.name,'result':result.name}
