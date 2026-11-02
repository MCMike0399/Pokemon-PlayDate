#!/usr/bin/env python3
"""Host geometry for exact prepared C Git data; reads stopped save evidence only, never a runtime.

Reuses the existing source decoder and Audit. Exit 1 retains every blocked
route/capability rather than aborting at the first unavailable waypoint.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))
from tools.harness import preflight_midgame as host
from tools.harness.midgame_journey import MidgameJourney, validate_scenario
from tools.harness.protocol import ProtocolError

C = '548ba47d'  # immutable wired/qualified C candidate; no campaign acceptance
COPYCAT = '8a4a8e4acc17b52f5adcc5ea01a89212dbd99c42'
DATA = Path(__file__).parent


def preflight(output):
    host.MidgameJourney = MidgameJourney
    with tempfile.TemporaryDirectory(prefix='checkpoint-c-host-') as directory:
        audit = host.Audit(C, 'prepared-5.5c', directory)
        audit.load()
        scenes = audit.read('data/silphStory/scenes.json')['scenes']
        compact = audit.read('data/sourceMapCache/compact.json')
        script_bytes = (DATA / 'silph-fixed-routes.json').read_bytes()
        scripts = json.loads(script_bytes)
        script_hash = hashlib.sha256(script_bytes).hexdigest()

        def check(name, action, **conditions):
            try:
                detail = action()
                audit.record(name, 'C-route', detail=detail, conditions=conditions)
                return detail
            except (ProtocolError, KeyError, StopIteration, ValueError, OSError) as error:
                audit.record(name, 'C-route', 'blocked', error=str(error), conditions=conditions)

        def open_door(flag):
            door = next(d for rows in scenes['doors'].values() for d in rows if d['flag'] == flag)
            model = audit.model(door['map'])
            cells = [dict(x=door['x'] * 2 + i % 2, y=door['y'] * 2 + i // 2, after=key)
                     for i, key in enumerate(door['open_keys'])]
            audit.replace_cells(model, cells, compact['tiles'], flag)
            audit.rows[-1]['requires'] = 'actual Card Key A interaction and committed ' + flag

        # Reconciliation closes every unearned door on entry. Check that exact
        # projection too; raw map terrain alone cannot establish a working door.
        for rows in scenes['doors'].values():
            for door in rows:
                def closed(door=door):
                    missing = [key for key in door['closed_keys'] + door['open_keys']
                               if key not in compact['tiles']]
                    if missing:
                        raise ProtocolError('Silph reconciliation atlas keys absent: ' + str(sorted(set(missing))))
                    model = audit.model(door['map'])
                    cells = [dict(x=door['x'] * 2 + i % 2, y=door['y'] * 2 + i // 2, after=key)
                             for i, key in enumerate(door['closed_keys'])]
                    audit.replace_cells(model, cells, compact['tiles'], door['flag'] + '/closed')
                check(door['flag'] + '/reconciliation', closed)
        for interaction in scripts['card_key_interactions']:
            name, point, facing = interaction['map'], interaction['point'], interaction['facing']
            def facing_door(name=name, point=point, facing=facing):
                model = audit.model(name)
                dx, dy = host.cj.DIRECTIONS[facing]
                target = (point[0] + model.padding + dx, point[1] + dy)
                tile = model.feet[target[1]][target[0]]
                allowed = {0x18, 0x24} | ({0x5e} if name == 'SilphCo11F' else set())
                if tile not in allowed:
                    raise ProtocolError('fixed Card Key facing tile ' + hex(tile) + ' is rejected by SilphStory.facingDoor')
                return dict(target=target, foot_tile=tile)
            check(name + '/Card Key dispatch', facing_door,
                  owner='exact prepared SilphStory.facingDoor checks 0x18/0x24 and 11F 0x5e')

        # These are declared host models only. No Source or fixture is rewritten.
        opened = set()

        for label, route in scripts['routes'].items():
            for flag in route.get('requires_doors', []):
                if flag not in opened:
                    check(flag, lambda flag=flag: open_door(flag))
                    opened.add(flag)
            model = audit.model(route['map'])
            inert_points = set()
            if route.get('requires_inert_warps'):
                model = copy.deepcopy(model)
                for id in route['requires_inert_warps']:
                    inert = next(e for e in scenes['inert_warps'] if e['id'] == id)
                    tile = compact['tiles'][inert['key']]
                    point = audit.point(model, [inert['x'], inert['y']])
                    assert tile['terrain']['foot_tile'] == 0x1f and not tile['terrain']['warp_tile']
                    assert tile['collision'] == 0
                    model.collision[point[1]][point[0]] = tile['collision']
                    inert_points.add(point)
            position = audit.point(model, route['start'])
            for number, step in enumerate(route['steps']):
                target = audit.point(model, step['to'])
                actual = model.terrain_step(position, step['direction'])
                actors = [e['id'] for e in model.events['objects'] if (e['x'], e['y']) == target]
                errors = []
                if actual is None or actual.destination != target:
                    errors.append('declared input differs from source terrain')
                if target in model.warps and target not in inert_points:
                    errors.append('unintended warp inside fixed walking leg')
                audit.record(label + '/' + str(number + 1), 'fixed-step',
                    'blocked' if errors else 'pass', map=route['map'], start=position,
                    goal=target, errors=errors, script_sha256=script_hash,
                    conditions=dict(actors_requiring_live_clearance=actors,
                        doors=route.get('requires_doors', []),
                        flags=route.get('requires_flags', []),
                        inert_warp_owner=route.get('requires_inert_warps', []),
                        trainer_sight='real battle and source departure must finish; no actor removed by this audit'))
                position = target

        # Execute the exact pads and Sabrina scripts in the host source model.
        for route in (
            dict(name='Card Key pad out', map='SilphCo5F', start=[9, 14], warps=[5]),
            dict(name='Card Key pad back', map='SilphCo9F', start=[17, 15], warps=[5]),
            dict(name='Rival pad', map='SilphCo3F', start=[11, 10], warps=[9]),
            dict(name='Giovanni pad', map='SilphCo7F', start=[5, 6], warps=[4]),
            dict(name='Sabrina in', map='SaffronGym', start=[8, 16], warps=scripts['saffron_gym_in']),
            dict(name='Sabrina out', map='SaffronGym', start=[9, 8], warps=scripts['saffron_gym_out']),
        ):
            check(route['name'], lambda route=route: audit.chain(route),
                  actors='live occupancy and source trainer receipts required',
                  rival='protected pad requires Silph rival script owner')

        def approach(name, start, index):
            model = audit.model(name)
            actor = next(e for e in model.events['objects'] if e['source_index'] == index)
            hidden = set(scenes['toggles']['hide']) if name == 'SilphCo11F' else set()
            occupied = {(e['x'], e['y']) for e in model.events['objects'] if e['id'] not in hidden}
            point = (actor['x'], actor['y'])
            path = model.path(audit.point(model, start), set(model.approaches(point)), occupied)
            return dict(event=actor['id'], steps=len(path), origin=start,
                        destination=path[-1].destination if path else audit.point(model, start),
                        conditional_hidden_actors=sorted(hidden))

        for name, start, index in (
            ('SilphCo5F', [20, 16], 8), ('SilphCo7F', [3, 2], 1),
            ('SilphCo11F', [6, 12], 1), ('FightingDojo', [4, 3], 1),
            ('FightingDojo', [4, 3], 6), ('Route16FlyHouse', [2, 7], 1),
            ('CopycatsHouse2F', [7, 7], 1),
        ):
            check(name + '/object/' + str(index), lambda name=name, start=start, index=index: approach(name, start, index),
                  capacity='party < 6 or selected PC box < 20 for gifts; actual quantities/flags checked by driver',
                  actors='fixed source poses only; moving actors remain runtime conditions')

        # Preserve the actual shared-owner failure above. Independently check
        # pinned source topology, conditional on root binding the inert surface.
        # The event and Beauty remain; no alternate warp destination is added.
        def president_source_topology():
            inert = scenes['inert_warps'][0]
            model = copy.deepcopy(audit.model(inert['map']))
            point = audit.point(model, [inert['x'], inert['y']])
            event = next(e for e in model.events['warps'] if e['id'] == inert['id'])
            tile = compact['tiles'][inert['key']]
            if ((event['x'], event['y']) != point or tile['terrain']['foot_tile'] != 0x1f
                    or tile['terrain']['warp_tile'] or tile['collision'] != 0):
                raise ProtocolError('pinned inert Silph surface proof differs')
            model.collision[point[1]][point[0]] = tile['collision']
            hidden = set(scenes['toggles']['hide'])
            occupied = {(e['x'], e['y']) for e in model.events['objects'] if e['id'] not in hidden}
            president = next(e for e in model.events['objects'] if e['source_index'] == 1)
            path = model.path(audit.point(model, [6, 12]),
                set(model.approaches((president['x'], president['y']))), occupied, {point})
            return dict(steps=len(path), path=[step.destination for step in path],
                retained_inert_event=inert['id'], retained_beauty='pokered:SILPH_CO_11F:objects:2',
                source_foot_tile=tile['terrain']['foot_tile'])
        check('President/source topology after inert binding', president_source_topology,
              owner='conditional: shared map owners must retain source warp as inert, not solid or traversable warp',
              story='actual earned door and confirmed Rocket departures required')

        # Rival approach is explicit, with actors at source positions before the
        # script and absent only after the real confirmed departure.
        model = audit.model('SilphCo7F')
        audit.qualified.add('Silph rival approach/exit')
        for start, goal in (([5, 3], [4, 3]), ([4, 3], [4, 2]), ([4, 2], [3, 2]), ([3, 2], [5, 6])):
            audit.path('Silph rival approach/exit', model, audit.point(model, start), audit.point(model, goal),
                       requires=['real rival counter-pick, battle receipt and SILPH_STORY_V1_RIVAL_LEFT'])
        for floor in (3, 5):
            row = next(row for row in scenes['elevator'] if row['floor'] == floor)
            model = audit.models[row['map_id']]
            point = (row['destination']['x'] + model.padding, row['destination']['y'])
            def elevator(model=model, point=point):
                if not audit.clear(model, point):
                    raise ProtocolError('compact arrival barrier requires live SilphStoryWorld.elevatorBindings before map build: ' + str(point))
                return dict(arrival=point, walkable=True)
            check('elevator selected floor ' + str(floor), elevator,
                  field='real Silph floor menu; selected cabin exit resolver, not raw UNUSED_MAP',
                  registration='SilphStory/World/controller and Saffron content required')

        # Guard and city routes retain actor visibility conditions explicitly.
        audit.chain(dict(name='Route7 guard to Saffron', map='Route7Gate', start=[0, 4], warps=[3]))
        check('Saffron story actor gates', lambda: scenes['toggles'],
              before='Silph entrance requires Tower Fuji rescue; Sabrina entrance blocked until Giovanni defeat',
              after='real liberation reconciliation hides Rockets and shows residents')
        check('guard payment', lambda: audit.read('data/saffronGuards/guards.json')['flag'],
              field='one real Fresh Water purchase; guard consumes one priority drink; shared access flag persists')

        model = audit.model('Route16')
        entries = [e for e in model.events['warps'] if e['destination'].get('map') == 'ROUTE_16_FLY_HOUSE']
        # Upper gate corridor is a distinct component from Cycling Road.
        audit.chain(dict(name='Fly upper gate corridor', map='Route16Gate1F', start=[7, 2], warps=[5, 9]))
        audit.qualified.add('Route16 east to upper gate')
        event = next(e for e in model.events['warps'] if e['source_index'] == 7)
        def earned_cut():
            field = audit.read('data/fieldMoves.json')
            sites = field['maps'].get(model.name, {}).get('sites', [])
            if len(sites) != 1:
                raise ProtocolError('Route16 must have its one pinned Cut site')
            return audit.cut(dict(name='Route16 earned Cut projection', map='Route16',
                                  cell=[sites[0]['targets'][0]['x'], sites[0]['targets'][0]['y']],
                                  requires=['real Cut user, Cascade Badge and successful field commit']))
        check('Route16 earned Cut geometry', earned_cut)
        audit.path('Route16 east to upper gate', model, audit.point(model, [39, 10]),
                   (event['x'], event['y']), {(event['x'], event['y'])},
                   requires=['conditional on real Cut; disposable model uses exact accepted pinned cells'])
        audit.qualified.add('Route16 west upper gate to Fly house')
        for event in entries:
            audit.path('Route16 west upper gate to Fly house', model, audit.point(model, [17, 4]),
                       (event['x'], event['y']), {(event['x'], event['y'])},
                       requires=['actual Cut, restored on map reload; no terrain mutation fabricated'])
        def cut_site():
            index = audit.read('data/fieldMoveIndex.json')
            if model.name not in index['maps']:
                raise ProtocolError('exact C fieldMoveIndex.json has no Route16 map; pinned Cut capability missing')
            field = audit.read('data/fieldMoves.json')
            sites = field['maps'].get(model.name, {}).get('sites', [])
            if not sites:
                raise ProtocolError('exact C fieldMoves.json has no Route16 Cut site; Fly house access capability missing')
            return sites
        check('Route16 Cut capability', cut_site)
        check('Fly visited-only history', lambda: audit.read('data/fieldTravel.json')['fly'],
              field='actual HM02 teaching, Thunder Badge, outdoor Party Fly, earned compatible user',
              history='Celadon and Saffron must be present in actual visited list; PP and history unchanged by flights')
        copycat = json.loads(host.git('show', COPYCAT + ':Source/data/copycatService/service.json'))
        check('Copycat optional', lambda: dict(commit=COPYCAT, flag=copycat['flag'],
              service_sha256=host.sha(host.git('show', COPYCAT + ':Source/data/copycatService/service.json'))),
              registration='separate Copycat hook required only by Bulbasaur optional route',
              inventory='buy real Doll, require reward capacity before Doll removal, no duplicate TM31')
        for starter in ('bulbasaur', 'charmander', 'squirtle'):
            check('C scenario ' + starter, lambda starter=starter: validate_scenario(
                json.loads((DATA / ('restart-55c-' + starter + '.json')).read_bytes())))
        from tools.harness.restarting import accepted_midgame_boundary
        chain = json.loads((ROOT / 'docs/validation/chain-saves.json').read_bytes())
        for starter in ('bulbasaur', 'charmander', 'squirtle'):
            record = next(row for row in chain['saves'] if row['from_milestone'] == '5.5b' and row['starter'] == starter)
            check('accepted B binding ' + starter,
                  lambda record=record: accepted_midgame_boundary(record, ROOT),
                  authority='docs/validation/midgame-b-acceptance-20261102.json; no slots rewritten')
        def declarations():
            from tools.generate_region_registrations import build
            build(ROOT)
        check('qualified C region declarations', declarations,
              requires='real SDK Saffron transform export and refreshed qualification through existing owners; never fabricated')
        # Rows produced by reused Audit retain geometry failures; none are dropped.
        blocked = [row for row in audit.rows if row['status'] in {'blocked', 'unreachable', 'gap'}]
        owner_paths = ('game/silphStory.lua', 'game/silphStoryWorld.lua',
                       'game/rocketHideoutStoryWorld.lua', 'game/midgameGymStory.lua',
                       'domain/fieldMoves.lua', 'domain/fieldTravel.lua', 'game/saffronGuards.lua')
        owners = {path: host.sha(host.git('show', C + ':Source/' + path)) for path in owner_paths}
        report = dict(schema=1, preparation_only=True, prepared_commit=C, copycat_commit=COPYCAT,
                      driver_sha256=host.sha((ROOT / 'tools/harness/midgame_journey.py').read_bytes()),
                      script_sha256=script_hash, sources=audit.files, owner_sources=owners, checks=audit.rows, blockers=blocked,
                      conditions='Host terrain only. No runtime, actor movement, resources or runtime locks accessed; stopped save bytes verified read-only.')
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(dict(checks=len(audit.rows), blockers=len(blocked), output=str(output))))
        return bool(blocked)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(preflight(args.output))
