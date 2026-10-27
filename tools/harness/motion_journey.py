"""Supplementary actual-input NPC motion/Save/Continue, inside runner ownership."""
import copy
import hashlib
from pathlib import Path
from tools.harness.journeys import Journey, lookup
from tools.harness.protocol import ProtocolError, atomic_json

LOCATIONS = {
    'south-gate': ('kanto_forest_south_gate', 'pokered:VIRIDIAN_FOREST_SOUTH_GATE', 5, 4, 'left', 2),
    'pewter-city': ('kanto_pewter_city', 'pokered:PEWTER_CITY', 24, 27, 'up', 4),
    'pewter-mart': ('kanto_pewter_mart', 'pokered:PEWTER_MART', 5, 6, 'up', 2),
}


def validate_config(config):
    if not isinstance(config, dict) or set(config)-{'name','location','seed'} or config.get('name') not in {'npc-motion','npc-motion-save','npc-motion-continue'}:
        raise ProtocolError('malformed NPC motion journey')
    if 'seed' in config and (type(config['seed']) is not int or not -2147483648<=config['seed']<=2147483647):
        raise ProtocolError('invalid NPC motion seed')
    if config.get('location','pewter-mart') not in LOCATIONS:
        raise ProtocolError('unknown NPC motion location')
    if config['name']=='npc-motion-continue' and set(config)!={'name'}:
        raise ProtocolError('Continue uses immutable receipt, not new configuration')


def validate_receipt_state(value):
    expected={'zone','zone_id','player','actors','world_rng','rules_rng','native_npcs','session'}
    if not isinstance(value,dict) or set(value)!=expected or not isinstance(value['zone'],str) or not isinstance(value['zone_id'],str):
        raise ProtocolError('malformed NPC motion receipt state')
    if any(not isinstance(value[key],dict) for key in ('player','actors','world_rng','rules_rng','session')) or not isinstance(value['native_npcs'],list) or not value['native_npcs']:
        raise ProtocolError('malformed NPC motion receipt pose/owners')
    if not any(isinstance(npc,dict) and isinstance(npc.get('motion'),dict) and npc['motion'].get('phase')=='moving' for npc in value['native_npcs']):
        raise ProtocolError('NPC motion receipt must contain an actual midstep actor')


def boundary(state):
    """Exact simulation + native pose fields, excluding expected UI/frame changes."""
    motion = state.get('world_motion')
    if not isinstance(motion, dict) or not isinstance(motion.get('live'), dict):
        raise ProtocolError('NPCMotion diagnostics required')
    npcs = state.get('npcs')
    if not isinstance(npcs, list) or not npcs:
        raise ProtocolError('source NPC diagnostics required')
    native = []
    for npc in npcs:
        if not npc.get("source_event_id"):
            if npc.get("motion") is not None: raise ProtocolError("unidentified simulated actor")
            continue  # Explicit non-rendered unresolved source surface blockers.
        fields = ('source_event_id', 'x', 'y', 'pixel_x', 'pixel_y', 'facing', 'motion')
        if any(field not in npc for field in fields):
            raise ProtocolError('native NPC pixel/facing diagnostics required')
        native.append({key: copy.deepcopy(npc[key]) for key in fields})
    if not native: raise ProtocolError("no bound source actor poses")
    return copy.deepcopy({'zone': state['zone'], 'zone_id': state['zone_id'],
        'player': {key: state['player'][key] for key in ('x', 'y', 'facing')},
        'actors': motion['live'], 'world_rng': motion['rng'], 'rules_rng': state['rng'],
        'native_npcs': native, 'session': state['session']})


def receipt_packet(client, state):
    state=boundary(state);validate_receipt_state(state)
    return dict(schema=1, kind='npc-motion-saved', build_id=client.identity['build_id'],
                session_id=client.identity['session_id'], state=state)


class MotionJourney(Journey):
    def __init__(self, client, evidence, config, capture_dir=None, build_evidence=None):
        super().__init__(client, evidence, config)
        if capture_dir is not None: self.frames_dir = Path(capture_dir)
        self.summary['supplementary'] = True
        self.build_evidence=Path(build_evidence or evidence)

    def freeze_step(self):
        key = self.config.get('location', 'pewter-mart')
        if key not in LOCATIONS: raise ProtocolError('unknown motion location')
        zone, stable, x, y, facing, source_index = LOCATIONS[key]
        self.reset(seed=self.config.get('seed', 42), opening=False, intro='skip', zone=zone,
                   entry={'x': x, 'y': y, 'facing': facing})
        self.require(root='overworld', zone_id=stable)
        actor_id=stable+':objects:'+str(source_index)
        indices=[i for i,npc in enumerate(self.state.get('npcs',[]),1) if npc.get('source_event_id')==actor_id]
        if len(indices)!=1: raise ProtocolError('exact source walker missing or duplicate: '+actor_id)
        index=indices[0]
        self.summary['walker_id']=actor_id
        self.send('record motion-initial 48', 'wait 48')
        # tick1 is tested before update; that frame advances to2, following B
        # frame advances to3 before input pauses. No host polling gap is involved.
        self.send({'op': 'await', 'path': f'npcs.{index}.motion.tick', 'equals': 1, 'frames': 900},
                  'press b')
        self.require(root='pause', **{'world_motion.paused': True,
            f'npcs.{index}.motion.phase': 'moving', f'npcs.{index}.motion.tick': 3})
        self.summary['walker_index'] = index
        frozen = boundary(self.state)
        self.send('record motion-paused 48', 'wait 48')
        if boundary(self.state) != frozen:
            raise ProtocolError('paused native actor pose/timers or world/rules RNG changed')
        self.summary['frozen_boundary'] = frozen
        return frozen

    def select_pause(self, option):
        options = lookup(self.state, 'pause.menu.options')
        if not isinstance(options, list) or options.count(option) != 1:
            raise ProtocolError('pause must expose exactly one ' + option)
        target = options.index(option) + 1
        for _ in range(len(options)):
            selected = lookup(self.state, 'pause.menu.selected')
            if selected == target: return
            self.send('press down')
        raise ProtocolError('pause selection did not converge')

    def save_midstep(self):
        frozen = self.freeze_step()
        self.select_pause('SAVE');self.send('press a')
        self.require(root='pause', **{'pause.phase': 'save'})
        self.select_pause('YES');self.send('press a')
        self.require(root='dialog', **{'pause.lastSave.ok': True, 'world_motion.paused': True})
        if boundary(self.state) != frozen:
            raise ProtocolError('Save changed frozen native actor/stream state')
        if self.state['world_motion']['captured'] != frozen['actors']:
            raise ProtocolError('Save failed to capture exact midstep actors')
        # Keep saved-message overlay alive. Dismissing it would admit field ticks.
        self.send('record motion-saved 48', 'wait 48')
        if boundary(self.state) != frozen: raise ProtocolError('saved-message overlay advanced world')
        self.write_receipt()

    def write_receipt(self):
        path = self.evidence / 'journey-receipt.json'
        atomic_json(path, receipt_packet(self.client, self.state))
        self.summary['receipt'] = {'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

    def resume(self, before):
        self.send('record motion-resumed 96', 'press b', 'wait 96')
        self.require(root='overworld', **{'world_motion.paused': False})
        after = boundary(self.state)
        if after['actors'] == before['actors']: raise ProtocolError('resumed actor clock did not advance')
        if after['rules_rng'] != before['rules_rng']: raise ProtocolError('idle motion consumed rules RNG')
        self.summary['resumed_boundary'] = after

    def continue_midstep(self, prior):
        if not isinstance(prior, dict) or prior.get('kind') != 'npc-motion-saved' or prior.get('schema') != 1 or any(
            prior.get(key) != self.client.identity[key] for key in ('build_id', 'session_id')):
            raise ProtocolError('missing or wrong-build NPC motion receipt')
        self.send('snapshot');self.require(root='title', **{'title.phase': 'menu'})
        options = lookup(self.state, 'title.menu.options')
        if not isinstance(options, list) or options.count('CONTINUE') != 1:
            raise ProtocolError('title must expose exactly one CONTINUE')
        # CONTINUE is first by the production TitleState contract. Fail if not.
        if lookup(self.state, 'title.menu.selected') != options.index('CONTINUE') + 1:
            raise ProtocolError('Continue initial selection changed')
        installed,rendered=self.continue_frames()
        self.state=installed
        self.require(root='overworld', **{'overworld': 'explore'})
        restored = boundary(self.state)
        if restored != prior['state']:
            raise ProtocolError('Continue install boundary differs in native pose/actors/streams/session')
        self.summary['continued_boundary'] = restored
        self.summary['first_rendered_world']={'snapshot':installed,'png':'motion-continue-boundary-02.png',
            'pose_proof':verify_rendered_poses(self.build_evidence,self.frames_dir/'motion-continue-boundary-02.png',installed)}
        self.write_receipt()
        self.state=rendered
        validate_first_world_update(installed,rendered)
        self.summary['first_updated_world']={'snapshot':rendered,'png':'motion-continue-boundary-03.png',
            'pose_proof':verify_rendered_poses(self.build_evidence,self.frames_dir/'motion-continue-boundary-03.png',rendered)}
        # Later requests are live-resume evidence, never the original midstep.
        self.send('record motion-continued-resume 96', 'wait 96')
        self.require(root='overworld')
        now = boundary(self.state)
        if now['actors'] == restored['actors'] or now['rules_rng'] != restored['rules_rng']:
            raise ProtocolError('Continue resume failed or consumed rules RNG')

    def continue_frames(self):
        # Keep install and first eligible world update in one request, so host
        # response/poll latency cannot move the first-render observation boundary.
        result=self.client.send(['record motion-continue-boundary 3','press a','snapshot'],timeout=60,max_frames=1800)
        entries=result.get('results')
        if not isinstance(entries,list)or len(entries)!=3 or any(entry.get('command')!=i or entry.get('status')!='ok' for i,entry in enumerate(entries,1)):
            raise ProtocolError('Continue boundary requires three exact completed command snapshots')
        if [entry.get('op')for entry in entries]!=['record','press','snapshot']:
            raise ProtocolError('Continue boundary command identity changed')
        for i in range(1,4):
            if not (self.frames_dir/f'motion-continue-boundary-{i:02d}.png').is_file():
                raise ProtocolError('missing Continue transition/first-world PNG')
        self.recordings.append({'name':'motion-continue-boundary','frames':3})
        return entries[1]['snapshot'],entries[2]['snapshot']


def validate_first_world_update(installed,rendered):
    if rendered.get('root')!='overworld'or rendered.get('overworld')!='explore' or lookup(rendered,'world_motion.paused') is not False:
        raise ProtocolError('first rendered world must be eligible exploration')
    if lookup(rendered,'frame.tick')!=lookup(installed,'frame.tick')+1:
        raise ProtocolError('first rendered world is not exactly one frame after install')
    before=boundary(installed);after=boundary(rendered)
    for key in ('zone','zone_id','player','rules_rng','session'):
        if after[key]!=before[key]:raise ProtocolError('first world update changed '+key)
    actors={value['id']:value for value in after['actors']['actors']}
    moving=0
    for old in before['actors']['actors']:
        if old['phase']=='moving':
            moving+=1;value=actors.get(old['id'])
            if old['tick']>=7 or not value or value['phase']!='moving' or value['tick']!=old['tick']+1:
                raise ProtocolError('first rendered world failed exact midstep tick advance')
    if not moving:raise ProtocolError('saved moving actor missing at first world update')


def visual_preflight(scenario):
    groups=scenario.get('processes',[scenario])
    if any(group.get('journey',{}).get('name')=='npc-motion-continue' for group in groups):
        try:from PIL import Image
        except ImportError as error:raise ProtocolError('NPC motion Continue pose qualification requires Pillow; install tools/requirements-dev.txt')from error


def verify_rendered_poses(build_evidence,png,state):
    """Exact opaque source-sprite pixels at the observed rendered positions."""
    from PIL import Image
    from tools.visual.event_art import raster
    import math,json
    build_evidence=Path(build_evidence)
    hashes=json.loads((build_evidence/'source-manifest.json').read_text())
    def source(relative):
        path = (build_evidence / 'Source' / relative).resolve()
        if not path.is_relative_to((build_evidence / 'Source').resolve()) or relative not in hashes:
            raise ProtocolError('missing/unsafe rendered pose source input: ' + relative)
        try:
            raw = path.read_bytes()
        except OSError as error:
            raise ProtocolError('missing rendered pose source input: ' + relative) from error
        if hashlib.sha256(raw).hexdigest()!=hashes.get(relative):raise ProtocolError('rendered pose source input drift: '+relative)
        return json.loads(raw)
    from tools.generate_source_map_cache import REVISION

    def qualified(relative):
        data = source(relative)
        if data.get('schema') != 1 or data.get('source_revision') != REVISION:
            raise ProtocolError('unverified rendered pose source record: ' + relative)
        return data

    manifest = qualified('data/sourceMaps.json')['maps']
    names = [name for name, entry in manifest.items() if entry['id'] == state['zone_id']]
    if len(names) != 1:
        raise ProtocolError('unidentified first-world source map')
    name = names[0]
    entry = manifest[name]
    profile = entry['profile']
    if profile not in ('pewter', 'source', 'viridian'):
        raise ProtocolError('unsupported rendered pose source profile: ' + str(profile))
    if state.get('zone', entry['key']) != entry['key']:
        raise ProtocolError('first-world source map runtime identity differs')
    definition = qualified(entry['path'])
    if (hashes[entry['path']] != entry['source_sha256']
            or definition.get('name') != name or definition.get('id') != entry['id']):
        raise ProtocolError('first-world decoded source map identity/pin differs')
    events = {}
    for event in definition['events']['objects']:
        if event['id'] in events or event['id'] != entry['id'] + ':objects:' + str(event['source_index']):
            raise ProtocolError('first-world decoded source object identity differs')
        events[event['id']] = event
    # These are immutable content packages, not regional map-name inventories.
    # Duplicate art must agree, as in the production immutable package resolver.
    packages = ['data/sourceSlice/sprites.json', 'data/vermilionPreparation/sprites.json'] if profile == 'source' else [
        'data/' + ('pewterSlice' if profile == 'pewter' else 'viridianSlice') + '/sprites.json']
    sprites = [qualified(packages[0])]
    for path in packages[1:]:
        if path in hashes or (build_evidence / 'Source' / path).exists():
            sprites.append(qualified(path))
    with Image.open(png)as opened:
        if opened.size!=(400,240)or opened.format!='PNG':raise ProtocolError('invalid first-world PNG')
        image=opened.convert('RGBA')
    cx,cy=math.floor(state['camera']['x']),math.floor(state['camera']['y'])
    proofs=[]
    for npc in state['npcs']:
        motion=npc.get('motion');identity=npc.get('source_event_id')
        if not identity:
            if motion is not None:
                raise ProtocolError('first-world actor source identity missing')
            continue
        if not isinstance(motion,dict)or identity not in events:raise ProtocolError('first-world actor source identity missing')
        sprite = events[identity]['sprite']
        strip = None
        for package in sprites:
            if profile == 'pewter':
                binding = package['mapping'].get(sprite)
                if binding is not None:
                    strip = package['sprites'][binding['name']]
            else:
                key = sprite.removeprefix('SPRITE_').lower() if profile == 'viridian' else sprite
                candidate = package['sprites'].get(key)
                if strip is not None and candidate is not None and strip != candidate:
                    raise ProtocolError('conflicting immutable source sprite: ' + sprite)
                strip = strip if strip is not None else candidate
        if strip is None:
            raise ProtocolError('missing first-world source sprite: ' + sprite)
        direction = npc['facing']
        tick = motion['tick']
        if direction not in ('up', 'down', 'left', 'right') or type(tick) is not int or (
                motion['phase'] == 'moving' and not 1 <= tick <= 8):
            raise ProtocolError('invalid first-world source pose phase/facing: ' + identity)
        phase = (tick // 2) % 4 if motion['phase'] == 'moving' else 0
        pose = 'walk' if phase == 1 else 'alternate' if phase == 3 else 'stand'
        if profile == 'source' and sprite == 'SPRITE_BLUE':
            # Raw faithful grids are NOT production BLUE: protected standing and
            # greyhair strides use the SDK's legacy omitted dither phase. This
            # helper has no protected native phase witness to qualify it against.
            raise ProtocolError('unqualified source pose policy: SPRITE_BLUE ' + pose +
                                ' ' + direction + ' (protected greyhair/legacy-omitted) in ' + identity)
        fixed = strip['fixed'] and pose == 'stand'
        lookup_direction = 'down' if fixed else 'left' if direction == 'right' else direction
        try:
            frame = strip['standing' if pose == 'stand' else 'walking'][lookup_direction]
            grid = strip['frames'][str(frame)]
            if len(grid) != 16 or any(len(row) != 16 or set(row) - set('.12#') for row in grid):
                raise ValueError('invalid grid')
            expected = raster(grid)
        except (KeyError, ValueError) as error:
            raise ProtocolError('unqualified source pose frame: ' + identity + ' ' + pose + ' ' + direction) from error
        flip = not fixed and (direction == 'right' or pose == 'alternate' and direction in ('up', 'down'))
        if flip:expected=expected.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        left,top=round(npc['pixel_x'])-cx,round(npc['pixel_y'])-cy;checked=0
        for y in range(32):
            for x in range(32):
                pixel=expected.getpixel((x,y));sx,sy=left+x,top+y
                if pixel[3]==255 and 0<=sx<400 and 0<=sy<240:
                    if image.getpixel((sx,sy))!=pixel:raise ProtocolError('first-world PNG source pose mismatch: '+identity+' at '+str((sx,sy)))
                    checked+=1
        if motion['phase']=='moving'and checked<32:raise ProtocolError('moving source actor is not sufficiently visible for exact pose proof')
        proofs.append({'id':identity,'source_sprite':events[identity]['sprite'],'source_frame':frame,'flip_x':bool(flip),'pose':pose,'native_tick':tick,'opaque_pixels_checked':checked})
    if not proofs:raise ProtocolError('no actual source poses qualified in first-world PNG')
    return {'method':'exact-source-opaque-RGBA','actors':proofs,'png_sha256':hashlib.sha256(Path(png).read_bytes()).hexdigest()}


def run(client, scenario, evidence, build_evidence=None, prior_receipt=None, capture_dir=None):
    config = scenario['journey'];validate_config(config);j = MotionJourney(client, evidence, config, capture_dir, build_evidence)
    try:
        name = config['name']
        if name == 'npc-motion': j.resume(j.freeze_step())
        elif name == 'npc-motion-save': j.save_midstep()
        elif name == 'npc-motion-continue': j.continue_midstep(prior_receipt)
        else: raise ProtocolError('unknown motion journey')
        j.summary.update(ok=True, last_snapshot=j.state)
    except BaseException as error:
        j.summary.update(ok=False, error=str(error), last_snapshot=j.state)
        atomic_json(Path(evidence)/'journey-summary.json', j.summary);raise
    return j.summary
