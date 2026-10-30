#!/usr/bin/env python3
"""Host-only geometry audit. Never imports a runner or opens a runtime.

Reads immutable git objects into disposable host staging for the existing
source_models decoder. A successful geometric check is conditional on the
reported occupancy; it is not journey acceptance. Exit 1 means blockers/gaps.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.harness import cerulean_journey as cj
import types
from tools.harness import vermilion_journey as vj
from tools.harness.protocol import ProtocolError
from tools.harness.parcel_journey import NAMES as PARCEL_NAMES

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = 'baaf6368c57e3c9db2863cfc3b7c530d1bae1d88'
BASE = 'b676f3051b7475ae7f1bd5d12ad27650f2e66ab0'
PREPARED = '0406bf301ce0d3d4792fc152429f3cbec990ac2d'
DATA = Path(__file__).with_name('scenarios') / 'midgame'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Audit:
    def __init__(self, ref, scope, directory):
        self.ref, self.scope = ref, scope
        self.rows, self.sources = [], {}
        self.build = Path(directory)
        self.files = {}
        self.models = {}
        self.owner = None

    def record(self, name, kind, status='pass', **details):
        self.rows.append(dict(name=name, kind=kind, status=status, scope=self.scope, **details))

    def read(self, relative):
        if relative not in self.files:
            content = git('show', self.ref + ':Source/' + relative)
            target = self.build / 'Source' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            self.files[relative] = sha(content)
        return json.loads((self.build / 'Source' / relative).read_bytes())

    def load(self):
        manifest = self.read('data/sourceMaps.json')
        self.read('data/sourceMapCache/compact.json')
        authored = json.loads((Path(__file__).with_name('parcel_authored.json')).read_bytes())
        paths = {e['path'] for e in manifest['maps'].values()}
        paths |= {'data/viridianSlice/' + n + '.json' for n in PARCEL_NAMES}
        paths.add(authored['source_file'])
        for relative in sorted(paths):
            try:
                # The authored dependency is Lua, unlike the decoded map records.
                if relative.endswith('.lua'):
                    target = self.build / 'Source' / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    content = git('show', self.ref + ':Source/' + relative)
                    target.write_bytes(content)
                    self.files[relative] = sha(content)
                else:
                    self.read(relative)
            except (subprocess.CalledProcessError, ValueError) as error:
                self.record(relative, 'input', 'gap', error=str(error))
        self.read('data/rocketHideoutStory/scenes.json')
        (self.build / 'source-manifest.json').write_text(json.dumps(self.files))
        self.models, self.manifest, doors = cj.source_models(cj.StagedSource(self.build))
        self.owner = MidgameJourney.__new__(MidgameJourney)
        self.owner.models, self.owner.map_manifest, self.owner.doors = self.models, self.manifest, doors
        self.owner.build_evidence = self.build
        self.sources = dict(self.files)
        self.record('source-map inventory', 'input', count=len(self.manifest['maps']), commit=self.ref)

    def model(self, name):
        return self.models[self.manifest['maps'][name]['id']]

    def point(self, model, source):
        return (source[0] + model.padding, source[1])

    def clear(self, model, point):
        return model.inside(point) and not model.collision[point[1]][point[0]]

    def path(self, name, model, start, goal, allow=(), requires=None):
        row = dict(map=model.source_data['name'], start=start, goal=goal,
                   source_sha256=model.descriptor['source_sha256'])
        if requires:
            row['requires'] = requires
            row['impact'] = 'requires-earned-mutation-or-capability'
        try:
            if not self.clear(model, start) or not self.clear(model, goal):
                raise ProtocolError('endpoint blocked or outside source geometry')
            steps = model.path(start, {goal}, (), allow)
            self.record(name, 'segment', 'gap' if requires and self.scope != 'current-5.5a' else 'pass',
                        steps=len(steps), conditional=bool(requires), **row)
        except ProtocolError as error:
            self.record(name, 'segment', 'unreachable', error=str(error), **row)

    def portal(self, model, event, name):
        row = dict(map=model.source_data['name'], source_index=event['source_index'],
                   trigger=(event['x'], event['y']), declared=event['destination'],
                   source_sha256=model.descriptor['source_sha256'])
        try:
            point = (event['x'], event['y'])
            if not self.clear(model, point):
                raise ProtocolError('portal trigger blocked')
            target, arrival = self.owner.project_warp(model, event)
            other = self.models[target]
            if not self.clear(other, arrival):
                raise ProtocolError('projected portal arrival blocked')
            approaches = [p for p in model.approaches(point)
                          if model.terrain_step(p, model.approaches(point)[p]) is not None
                          and model.terrain_step(p, model.approaches(point)[p]).destination == point]
            if not approaches:
                raise ProtocolError('portal has no legal adjacent arrival step')
            self.record(name, 'portal', destination=other.source_data['name'], arrival=arrival,
                        destination_sha256=other.descriptor['source_sha256'], approaches=approaches, **row)
            return other, arrival
        except (ProtocolError, KeyError, IndexError) as error:
            self.record(name, 'portal', 'gap', error=str(error), **row)
            return None

    def chain(self, route):
        model = self.model(route['map'])
        position = self.point(model, route['start'])
        for number, index in enumerate(route['warps']):
            name = route['name'] + '/' + str(number + 1)
            event = next((e for e in model.events['warps'] if e['source_index'] == index), None)
            if event is None:
                self.record(name, 'portal', 'gap', map=model.source_data['name'], missing_warp=index)
                continue
            point = (event['x'], event['y'])
            self.path(name, model, position, point, {point})
            projected = self.portal(model, event, name)
            if projected:
                model, position = projected
            else:
                self.record(name + '/continuation', 'segment', 'gap', error='arrival unknown; remaining chain cannot be certified')
                break

    def fixed(self, filename, destinations=None):
        content = git('show', BASE + ':tools/harness/scenarios/midgame/' + filename)
        packet = json.loads(content)
        routes = packet['routes']
        for label, route in (enumerate(routes) if isinstance(routes, list) else routes.items()):
            model = self.model(route['map'])
            destination = destinations[label] if destinations else route.get('destination')
            position = self.point(model, route['start'])
            spinners = {s['id']: s for s in self.read('data/rocketHideoutStory/scenes.json')['scenes']['spinners'].get(model.name, [])}
            for number, step in enumerate(route['steps']):
                name = filename + '/' + str(label) + '/' + str(number + 1)
                expected = self.point(model, step.get('to_cell', step.get('to')))
                origin = self.point(model, step.get('from_cell', [position[0] - model.padding, position[1]]))
                result = model.terrain_step(position, step['direction'])
                row = dict(map=route['map'], start=position, declared_origin=origin,
                           goal=expected, packet_sha256=sha(content), source_sha256=model.descriptor['source_sha256'])
                errors = []
                if origin != position:
                    errors.append('fixed from_cell discontinuity')
                if not self.clear(model, position) or result is None or result.destination != expected:
                    errors.append('walk/ledge differs from source movement')
                spinner = next((s for s in spinners.values() if self.point(model, (s['x'], s['y'])) == expected), None)
                stop = self.point(model, step.get('stop_cell', step.get('to_cell', step.get('to'))))
                if spinner:
                    cursor = expected
                    for direction in spinner['path']:
                        move = model.terrain_step(cursor, direction)
                        if move is None:
                            errors.append('spinner forced path hits source collision at ' + str(cursor))
                            break
                        cursor = move.destination
                    if cursor != stop:
                        errors.append('spinner stop differs: ' + str(cursor))
                    row['spinner'] = spinner['id']
                    row['forced_steps'] = len(spinner['path'])
                elif stop != expected:
                    errors.append('stop_cell has no matching source spinner')
                if expected in model.warps:
                    events = [e for e in model.events['warps'] if (e['x'], e['y']) == expected]
                    row['portal_indices'] = [e['source_index'] for e in events]
                    if number != len(route['steps']) - 1:
                        errors.append('unintended intermediate portal')
                    for event in events:
                        projection = self.portal(model, event, name + '/portal')
                        if projection and destination and destination != route['map'] and projection[0].source_data['name'] != destination:
                            errors.append('fixed destination differs from projected source portal')
                self.record(name, 'fixed-step', 'unreachable' if errors else 'pass', errors=errors, **row)
                # Continue from the declared cell after failure so every later
                # segment is checked; this is a host audit, never a state setter.
                position = stop
            goal = self.point(model, route['goal'])
            self.record(filename + '/' + str(label) + '/endpoint', 'endpoint',
                        'pass' if position == goal else 'unreachable', map=route['map'], goal=goal, actual=position)

    def inventory(self, names):
        for name in names:
            if name not in self.manifest['maps']:
                self.record(name, 'input', 'gap', error='map absent from this revision')
                continue
            model = self.model(name)
            allowed = {e['id'] for _, kind, e in self.owner.portals(model) if kind == 'warp'}
            for event in model.events['warps']:
                label = name + '/warp/' + str(event['source_index'])
                if event['id'] not in allowed and self.clear(model, (event['x'], event['y'])):
                    self.record(label, 'portal-exclusion', 'excluded', map=name,
                                trigger=(event['x'], event['y']), declared=event['destination'],
                                reason='existing MidgameJourney portal policy excludes ordinary store elevator travel',
                                source_sha256=model.descriptor['source_sha256'])
                else:
                    self.portal(model, event, label)
                    self.rows[-1]['coverage_role'] = 'map inventory; not necessarily a planned journey portal'
            # Enumerate connections, including every rejected edge input. A
            # missing destination is a gap; a wall is simply not an edge portal.
            for direction, (dx, dy) in cj.DIRECTIONS.items():
                edge = ([(x, 0 if dy < 0 else model.height - 1) for x in range(model.width)] if dy
                        else [(0 if dx < 0 else model.width - 1, y) for y in range(model.height)])
                for point in edge:
                    if not self.clear(model, point):
                        continue
                    if not any(h['direction'] == {'up':'north','down':'south','left':'west','right':'east'}[direction]
                               for h in model.source_data['connections']):
                        continue
                    try:
                        target, arrival = cj.connection_projection(self.models, model, point, direction)
                        self.record(name + '/edge/' + direction + '/' + str(point), 'connection',
                                    trigger=point, destination=target, arrival=arrival,
                                    source_sha256=model.descriptor['source_sha256'])
                    except ProtocolError as error:
                        self.record(name + '/edge/' + direction + '/' + str(point), 'connection',
                                    'excluded' if str(error) == 'source connection has no passable edge arrival' else 'gap',
                                    trigger=point, error=str(error), impact='boundary-outside-active-geometry'
                                    if str(error) == 'source connection target is not staged' else 'not-a-valid-edge-portal',
                                    source_sha256=model.descriptor['source_sha256'])


    def replace_cells(self, model, cells, tiles, name):
        """Apply declared source replacements only to a disposable host model."""
        changes = []
        for cell in cells:
            x, y = self.point(model, (cell['x'], cell['y']))
            tile = tiles[cell['after']]
            changes.append(dict(cell=(x, y), before=model.collision[y][x],
                                after=tile['collision'], key=cell['after']))
            model.collision[y][x] = tile['collision']
            model.feet[y][x] = tile['terrain']['foot_tile']
            model.grass[y][x] = tile['terrain']['grass']
        self.record(name, 'mutation', changes=changes,
                    condition='declared earned event must execute; host model only',
                    map=model.source_data['name'], source_sha256=model.descriptor['source_sha256'])

    def cut(self, mutation):
        model = self.model(mutation['map'])
        data = self.read('data/fieldMoves.json')
        cell = mutation['cell']
        site = next(s for s in data['maps'][model.name]['sites']
                    if any([p['x'], p['y']] == cell for p in s['targets']))
        target = self.point(model, cell)
        approaches = model.approaches(target)
        if not approaches:
            raise ProtocolError('Cut has no adjacent land approach')
        self.replace_cells(model, site['cells'], data['tiles'], mutation['name'])
        self.rows[-1].update(approaches=list(approaches), requires=mutation['requires'],
                             packet_sha256=self.files['data/fieldMoves.json'])

    def gate(self, key):
        terrain = self.read('data/rocketHideoutStory/scenes.json')['scenes']['terrain'][key]
        model = self.model(terrain['map'])
        tiles = self.read('data/sourceMapCache/compact.json')['tiles']
        cells = [dict(x=terrain['x'] * 2 + i % 2, y=terrain['y'] * 2 + i // 2, after=k)
                 for i, k in enumerate(terrain['keys'])]
        self.replace_cells(model, cells, tiles, key)

    def selected_lift_exits(self):
        cabin = self.model('RocketHideoutElevator')
        for floor in self.read('data/rocketHideoutStory/scenes.json')['scenes']['elevator']:
            if floor['floor'] not in ('B2F', 'B4F'):
                continue
            target = self.models[floor['map_id']]
            arrival = self.point(target, (floor['destination']['x'], floor['destination']['y']))
            for event in cabin.events['warps']:
                status = 'pass' if self.clear(target, arrival) else 'gap'
                self.record('Lift selected ' + floor['floor'] + '/' + str(event['source_index']),
                            'selected-portal', status, trigger=(event['x'], event['y']),
                            destination=target.source_data['name'], arrival=arrival,
                            source_sha256=target.descriptor['source_sha256'],
                            requires='Actual Lift Key/menu selection persists the destination flag; resolveDoor uses the declared floor destination, not the raw cabin warp destination.')

    def access(self, route):
        """Check explicitly declared origins/targets; no control-flow evaluator."""
        model = self.model(route['map'])
        origins = [self.point(model, route['start'])]
        for number, target in enumerate(route['targets']):
            label = route['name'] + '/' + str(number + 1)
            row = dict(map=route['map'], source_sha256=model.descriptor['source_sha256'],
                       origins=origins, declaration=target,
                       occupancy='terrain only; live NPC occupancy/trainer outcomes remain runtime dependencies')
            try:
                if isinstance(target, str):
                    event = next(e for entries in model.events.values() for e in entries if e['id'] == target)
                    goals = set(model.approaches((event['x'], event['y'])))
                    allow = ()
                else:
                    goals = {self.point(model, target)}
                    allow = goals & model.warps
                if not goals:
                    raise ProtocolError('no legal source interaction approach')
                paths = []
                for origin in origins:
                    if not self.clear(model, origin):
                        raise ProtocolError('declared origin blocked')
                    steps = model.path(origin, goals, (), allow)
                    paths.append(dict(origin=origin, goal=steps[-1].destination if steps else origin,
                                      steps=len(steps)))
                # Every candidate ending pose that a static approach can select
                # must be able to continue to the next target.
                reachable = set()
                for goal in goals:
                    for origin in origins:
                        try:
                            model.path(origin, {goal}, (), allow)
                            reachable.add(goal)
                            break
                        except ProtocolError:
                            pass
                origins = sorted(reachable)
                self.record(label, 'access', paths=paths, **row)
            except (StopIteration, KeyError, ProtocolError) as error:
                self.record(label, 'access', 'gap', error=str(error), **row)
                break

    def travel_checks(self, routes):
        # Reuse the driver's existing bounded route solver. This adds no
        # planning behavior to either driver or preflight.
        for route in routes:
            self.owner.state = dict(zone_id=self.model(route['map']).name,
                                    player=dict(zip(('x', 'y'), self.point(self.model(route['map']), route['start']))))
            self.owner.occupied = lambda: set()
            for destination in route['destinations']:
                label = route['name'] + '/' + destination
                target = self.model(destination).name
                origin = [self.owner.state['zone_id'], self.owner.position()]
                itinerary = []
                try:
                    for _ in range(64):
                        portal = self.owner.route_portal(target)
                        if portal is None:
                            break
                        point, kind, detail, arrival = portal
                        itinerary.append(dict(trigger=point, kind=kind, destination=arrival))
                        self.owner.state = dict(zone_id=arrival[0], player=dict(zip(('x', 'y'), arrival[1])))
                    else:
                        raise ProtocolError('existing travel transition bound exhausted')
                    self.record(label, 'travel', origin=origin, destination=destination, itinerary=itinerary,
                                occupancy='no actors; earned prior story flags and runtime replanning required')
                except ProtocolError as error:
                    self.record(label, 'travel', 'gap', origin=origin, destination=destination, error=str(error))
                    break


def call_inventory():
    """Exact unresolved call sites, deliberately no AST evaluation or planner."""
    content = git('show', BASE + ':tools/harness/midgame_journey.py').decode()
    method = ''
    rows = []
    pattern = re.compile(r'self\.(source_waypoint|navigate|warp|fixed_warp|cross|travel|mansion_step_warp|visit_event|background|pickup|fight|celadon_service|field_cut|wake_snorlax|fixed_leg|fixed_hideout|use_field|use_item)\(')
    for line, text in enumerate(content.splitlines(), 1):
        match = re.match(r'    def (\w+)\(', text)
        if match:
            method = match[1]
        if pattern.search(text) or re.search(r"self\.send\(.*press (?:up|down|left|right|'|\")", text):
            scope = ('inactive-prepared-5.5b' if method in {'route_tower', 'route_fuchsia', 'wake_snorlax'}
                     else 'outside-5.5a-5.5b' if method in {'route_saffron', 'silph_floor', 'route_fly'}
                     else 'current-or-shared-driver')
            rows.append(dict(file='tools/harness/midgame_journey.py', line=line, method=method,
                             call=text.strip(), scope=scope, status='gap',
                             reason='call-site inputs/origin/occupancy depend on runtime or control flow; named manifest checks do not certify this call'))
    return rows


def classify_calls(report):
    """Explicit review of the pinned 169 sites, not a Python flow evaluator."""
    current = report['audits'][0]['checks']
    groups = {
        'retrieve_hm_user': ('PC retrieval',),
        'route_lavender': ('Accepted return', 'Inherited ', 'Route2 Cut', 'Cerulean Cut', 'Route9 ', 'Tunnel entry', 'Rock Tunnel', 'Lavender optional'),
        'background': ('Game Corner guard', 'Lift panel', 'Roof drinks', 'Abra prize'),
        'source_waypoint': ('Route9 ', 'Game Corner guard', 'Hideout cabin', 'B1 explicit'),
        'fixed_hideout': ('hideout-fixed-routes.json/',),
        'pickup': ('B4 key', 'B4 guards Giovanni', 'TM18 counter', 'Coin Case'),
        'event_offer': ('Lavender optional',),
        'leave_party_slot': ('PC retrieval',),
        'restock': ('Restock or sell', 'Lavender to Celadon services'),
        'leader': ('Cut Celadon', 'Celadon Cut', 'Celadon gym exit', 'Gym Erika'),
        'route_celadon': ('Lavender to Celadon services',),
        'prepare_squirtle_ice_beam': ('Roof drinks', 'Store stairs', 'Lavender to Celadon services'),
        'exit_hideout_lift': ('Hideout cabin', 'Lift panel', 'Lift selected'),
        'route_hideout': ('Game Corner guard', 'Hideout entrance', 'hideout-fixed-routes.json/', 'B4 key', 'B4 guards Giovanni', 'Lift panel', 'b4-open', 'entrance-open', 'Lift selected'),
        'leave_hideout': ('Hideout cabin', 'Lift panel', 'hideout-fixed-routes.json/', 'Hideout return', 'B1 explicit', 'Lift selected'),
        'fixed_warp': ('B1 explicit', 'Hideout return'),
        'sell_old_item': ('Restock or sell', 'Lavender to Celadon services'),
        'mansion_step_warp': ('Mansion rear stairs',),
        'celadon_service': ('Roof drinks', 'Eevee room', 'Coin gifts', 'Abra prize'),
        'celadon_services_a': ('TM18 counter', 'Roof drinks', 'Store stairs', 'Mansion rear stairs', 'Eevee room', 'Coin Case', 'Coin gifts', 'Abra prize', 'Lavender to Celadon services'),
    }
    outside = {'ride_silph', 'key_door', 'route_saffron', 'route_fly', 'route_full',
               'supplemental_services', 'optional_content', 'leave_party_slot'}
    prepared = {'route_tower', 'route_fuchsia', 'wake_snorlax', 'fixed_leg', 'event_offer'}
    ui = {427: 'Flash changes darkness only; party/confirmation UI has no walking geometry.',
          1208: 'Fly destination picker DOWN is a menu selection, not walking.',
          1216: 'FieldTravel YES confirmation DOWN is a menu selection, not walking.',
          1304: 'Shop sell list DOWN is a menu selection, not walking.',
          1311: 'Shop quantity UP is a menu selection, not walking.'}
    rows = report.pop('uncheckable_driver_calls')
    for row in rows:
        method = row['method']
        if row['line'] in ui:
            row.update(status='excluded', category='ui-only', reason=ui[row['line']])
        elif method in outside:
            row.update(status='excluded', category='unreachable-future-packet',
                       scope='outside-current-packets',
                       reason='validate_config accepts lavender/5.5a only; natural invokes route_lavender/route_a. ' + method + ' is reachable only via dormant full/5.5c orchestration; even its reused Celadon or rod calls are not current coverage.')
        elif method in prepared:
            row.update(status='inactive', category='planned-5.5b-geometry', scope='inactive-prepared-5.5b',
                       reason='planned geometry or field relocation in dormant 5.5b method; named Tower/Safari/shore checks do not certify every dynamic call or earned field capability.',
                       evidence_prefixes=['Tower', 'Safari', 'safari-fixed-routes.json/', 'Route12', 'Route16', 'Warden', 'Fuchsia', 'candidate'])
        elif method in groups:
            matches = [c for c in current if c['name'].startswith(groups[method])]
            failures = [c['name'] for c in matches if c['status'] in {'gap', 'unreachable'}]
            row.update(status='gap' if not matches or failures else 'conditional-geometry',
                       category='reachable-5.5a-geometry', scope='current-5.5a',
                       reason='Pinned call inputs expanded by the declared routes and source event approaches below. Source terrain is checked; actual start pose, live actor occupancy, earned actions and UI success are rechecked by the existing driver.',
                       evidence_checks=[c['name'] for c in matches], failures=failures)
        else:
            row.update(status='gap', category='unclassified', reason='unreviewed call; fail closed')
    report['driver_calls'] = rows
    report['uncheckable_driver_calls'] = [r for r in rows if r['status'] == 'gap']
    report['driver_call_counts'] = {status: sum(r['status'] == status for r in rows)
                                    for status in sorted({r['status'] for r in rows})}


def prior_evidence(path, audits):
    raw = path.read_bytes()
    old = json.loads(raw)
    counts = {s: sum(r['status'] == s for r in old['findings']) for s in ('gap', 'unreachable')}
    result = dict(path=str(path), sha256=sha(raw), unresolved_calls=old['uncheckable_call_count'],
                  findings=counts, original_checks=old['check_count'],
                  current_geometry_changes=[])
    previous = next(a for a in old['audits'] if a['scope'] == 'current-5.5a')['source_hashes']
    now = audits[0]['source_hashes']
    result['current_geometry_changes'] = [f for f, digest in previous.items() if now.get(f) != digest]
    if old['driver_sha256'] != sha(git('show', BASE + ':tools/harness/midgame_journey.py')):
        raise ProtocolError('driver changed since original call inventory; reclassify every site')
    if result['unresolved_calls'] != 169 or counts != {'gap': 55, 'unreachable': 2}:
        raise ProtocolError('prior evidence does not match the requested original report')
    if result['current_geometry_changes']:
        raise ProtocolError('source geometry changed since original report: ' + str(result['current_geometry_changes']))
    checks = [r for a in audits for r in a['checks']]
    resolutions = []
    for finding in old['findings']:
        name = finding['name']
        if name == 'B4 guards to Giovanni closed gate':
            name = 'B4 guards to actual Giovanni approach after reload'
        matches = [r for r in checks if r['scope'] == finding['scope'] and r['name'] == name]
        if len(matches) != 1:
            raise ProtocolError('original finding lacks exact resolution: ' + finding['name'])
        resolution = matches[0]
        resolutions.append(dict(original_name=finding['name'], original_status=finding['status'],
                                scope=finding['scope'], current_name=name, status=resolution['status'],
                                reason=resolution.get('reason', resolution.get('requires',
                                    'declared source replacement and corrected source endpoint; conditional static geometry only'))))
    result['finding_resolutions'] = resolutions
    return result


def earned_evidence(root, source_hashes):
    """Supplemental observations only. No future or unobserved coverage."""
    result = []
    for case in sorted(root.glob('*-midgame--restart-*')):
        if not (case / 'source-manifest.json').is_file():
            continue
        manifest = json.loads((case / 'source-manifest.json').read_bytes())
        for process in sorted((case / 'processes').iterdir()):
            trace = process / 'trace.jsonl'
            if not trace.exists():
                continue
            zones, mansion_points = set(), {}
            for line in trace.open():
                snapshot = json.loads(line).get('snapshot', {})
                zone = snapshot.get('zone_id')
                zones.add(zone)
                if 'CELADON_MANSION' in str(zone):
                    player = snapshot.get('player', {})
                    if player.get('settled'):
                        mansion_points.setdefault(zone, set()).add((player['x'], player['y']))
            matched = {f: digest for f, digest in source_hashes.items()
                       if f in manifest and manifest[f] == digest}
            if len(matched) != len(source_hashes):
                raise ProtocolError('earned source manifest differs from preflight geometry: ' + str(case))
            for relative, digest in matched.items():
                if sha((case / 'Source' / relative).read_bytes()) != digest:
                    raise ProtocolError('earned source file differs: ' + relative)
            receipt = process / 'journey-receipt.json'
            item = dict(trace=str(trace), trace_sha256=sha(trace.read_bytes()),
                        source_manifest_sha256=sha((case / 'source-manifest.json').read_bytes()),
                        matching_source_hashes=matched, observed_zones=sorted(z for z in zones if z),
                        mansion_settled_points={z: sorted(points) for z, points in mansion_points.items()},
                        scope='only recorded traversal and earned Save/Continue; failed Charmander prize interaction is not a pass')
            if receipt.exists():
                item['receipt_sha256'] = sha(receipt.read_bytes())
                item['saved_receipt_kind'] = json.loads(receipt.read_bytes())['kind']
            partial = process / 'partial-save.json'
            if partial.exists():
                state = json.loads(partial.read_bytes())['state']
                item['partial_save_sha256'] = sha(partial.read_bytes())
                item['saved_completed_steps'] = state['completed_steps']
                item['saved_eevee_flag'] = state['codec']['questFlags'].get('CELADON_SERVICES_V1_EEVEE_TAKEN', False)
            if receipt.exists() and process.name == '0002':
                prior = process.parent / '0001/journey-receipt.json'
                item['save_continue_state_equal'] = json.loads(prior.read_bytes())['state'] == json.loads(receipt.read_bytes())['state']
                if not item['save_continue_state_equal']:
                    raise ProtocolError('earned Save/Continue receipt states differ: ' + str(case))
            result.append(item)
    if not result:
        raise ProtocolError('requested earned trace directory has no traces')
    return result


def load_helpers():
    global MidgameJourney, cj, vj
    # Load trusted immutable host helpers, never a runner, runtime or working
    # driver's file. Main's older warp projection predates the Mansion repair.
    for name in ('cerulean_journey', 'vermilion_journey', 'midgame_journey'):
        qualified = 'tools.harness.' + name
        module = types.ModuleType(qualified)
        module.__file__ = str(ROOT / 'tools/harness' / (name + '.py'))
        sys.modules[qualified] = module
        import tools.harness
        setattr(tools.harness, name, module)
        exec(compile(git('show', BASE + ':tools/harness/' + name + '.py'),
                     module.__file__, 'exec'), module.__dict__)
        if name == 'cerulean_journey':
            cj = module
        elif name == 'vermilion_journey':
            vj = module
        else:
            MidgameJourney = module.MidgameJourney


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='one JSON report outside Git')
    environment = Path.home() / 'Developer/Pokemon-PlayDate-env/evidence'
    parser.add_argument('--prior-report', type=Path, default=environment / 'midgame-host-preflight-baaf6368/report.json')
    parser.add_argument('--earned-evidence', type=Path, default=environment / 'm55a-arrival-restart-resumed-20261029-01')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error('report must be outside the repository')
    load_helpers()
    plan = json.loads((DATA / 'preflight-routes.json').read_bytes())
    report = dict(schema=2, kind='host geometry only; no journey evidence changed',
                  base_commit=BASE, original_geometry_commit=ORIGINAL, prepared_commit=PREPARED,
                  manifest_sha256=sha((DATA / 'preflight-routes.json').read_bytes()),
                  driver_sha256=sha(git('show', BASE + ':tools/harness/midgame_journey.py')),
                  assumptions=plan['assumptions'], audits=[], uncheckable_driver_calls=call_inventory())
    for ref, scope in [(BASE, 'current-5.5a'), (PREPARED, 'inactive-prepared-5.5b')]:
        with tempfile.TemporaryDirectory(prefix='midgame-host-') as directory:
            audit = Audit(ref, scope, directory)
            try:
                audit.load()
                section = plan['5.5a' if ref == BASE else '5.5b']
                audit.inventory(section['maps'])
                if scope == 'current-5.5a':
                    for mutation in section.get('mutations', []):
                        try:
                            audit.cut(mutation)
                        except (KeyError, StopIteration, ProtocolError) as error:
                            audit.record(mutation['name'], 'mutation', 'gap', error=str(error))
                    for closed in ('b1-closed', 'b4-closed', 'entrance-closed'):
                        audit.gate(closed)
                    audit.gate('entrance-open')
                    audit.gate('b4-open')
                    audit.selected_lift_exits()
                else:
                    for mutation in section.get('mutations', []):
                        audit.record(mutation['name'], 'mutation', 'gap',
                                     declaration=mutation,
                                     reason='inactive actor/field-mode mutation; terrain cannot establish occupancy or execution')
                for route in section['chains']:
                    try:
                        audit.chain(route)
                    except (KeyError, ProtocolError) as error:
                        audit.record(route['name'], 'segment', 'gap', error=str(error))
                for leg in section['segments']:
                    try:
                        model = audit.model(leg['map'])
                        audit.path(leg['name'], model, audit.point(model, leg['start']), audit.point(model, leg['goal']),
                                   {audit.point(model, leg['goal'])} if leg.get('allow_portal') else (), leg.get('requires'))
                    except (KeyError, ProtocolError) as error:
                        audit.record(leg['name'], 'segment', 'gap', error=str(error))
                for filename in section['fixed']:
                    try:
                        audit.fixed(filename, section.get('fixed_destinations', {}).get(filename))
                    except (KeyError, ValueError, ProtocolError, subprocess.CalledProcessError) as error:
                        audit.record(filename, 'input', 'gap', error=str(error))
                for route in section.get('access', []):
                    audit.access(route)
                audit.travel_checks(section.get('travel', []))
                # These are map inventory cells, never selected route portals.
                # Keeping an explicit exclusion must not hide a declared failure.
                for row in audit.rows:
                    if row['status'] == 'gap' and row.get('impact') == 'boundary-outside-active-geometry':
                        row.update(status='excluded', reason='connection leads beyond this checkpoint staged map inventory; no active route calls this boundary')
                    if (row['status'] == 'gap' and row.get('coverage_role')
                            and row.get('error') == 'portal trigger blocked'):
                        row.update(status='excluded', reason='source warp is embedded in collision; existing portals() never offers it, and no declared route selects it')
                if scope == 'inactive-prepared-5.5b':
                    for correction in plan['inactive_corrections']:
                        model = audit.model(correction['map'])
                        audit.path('candidate correction ' + correction['map'], model,
                                   audit.point(model, correction['start']), audit.point(model, correction['candidate']))
                        target = audit.point(model, correction['target'])
                        if correction['map'] == 'FuchsiaCity':
                            rules = audit.read('data/fieldTravel.json')
                            tileset = model.source_data['tileset']['constant']
                            if tileset not in rules['water_tilesets'] or model.feet[target[1]][target[0]] != 0x14:
                                raise ProtocolError('candidate does not face supported source water')
                            origin = audit.point(model, correction['candidate'])
                            if any(p['tileset'] == tileset and
                                   {p['a'], p['b']} == {model.feet[origin[1]][origin[0]], 0x14}
                                   for p in rules['water_pairs']):
                                raise ProtocolError('candidate shore/water pair is prohibited')
                        else:
                            ghost = audit.read('data/towerStory/scenes.json')['scenes']['ghost']
                            if correction['target'] != [ghost['x'], ghost['y']]:
                                raise ProtocolError('candidate does not enter actual ghost trigger')
                        audit.record('candidate target ' + correction['map'], 'correction-evidence',
                                     declaration=correction, target_collision=model.collision[target[1]][target[0]],
                                     target_foot_tile=model.feet[target[1]][target[0]],
                                     source_sha256=model.descriptor['source_sha256'],
                                     status='excluded', reason='unapplied inactive driver correction; field/battle execution unverified')
            except (KeyError, ValueError, ProtocolError, subprocess.CalledProcessError) as error:
                audit.record('source decoding', 'input', 'gap', error=str(error))
            counts = {status: sum(r['status'] == status for r in audit.rows)
                      for status in ('pass', 'unreachable', 'gap', 'excluded')}
            report['audits'].append(dict(scope=scope, commit=ref, source_hashes=audit.files,
                                         counts=counts, counts_by_kind={kind: sum(r['kind'] == kind for r in audit.rows)
                                                                      for kind in sorted({r['kind'] for r in audit.rows})},
                                         checks=audit.rows))
    classify_calls(report)
    report['historical_manifest_corrections'] = plan['historical_manifest_corrections']
    report['evidence_errors'] = []
    try:
        report['original_report'] = prior_evidence(args.prior_report, report['audits'])
        report['supplemental_earned_evidence'] = earned_evidence(args.earned_evidence, report['audits'][0]['source_hashes'])
    except (OSError, ValueError, KeyError, ProtocolError) as error:
        report['evidence_errors'].append(str(error))
    report['findings'] = [row for a in report['audits']
                          for row in a['checks'] if row['status'] in {'gap', 'unreachable'}]
    report['coverage'] = 'conditional static geometry only; 5.5b inactive; actor occupancy, rewards, menus, field modes and new journeys are not acceptance'
    report['unsupported_modes'] = ['Surf water collision/movement is not modelled by SourceGeometry',
                                   'Strength actor pushes/occupancy are not terrain',
                                   'Bicycle forced admission/motion is not walking geometry',
                                   'Safari admission, balls/steps and battle mode require the actual runtime']
    report['remaining_blockers'] = dict(current_5_5a=[r for r in report['findings'] if r['scope'] == 'current-5.5a'],
                                        inactive_5_5b=[r for r in report['findings'] if r['scope'] == 'inactive-prepared-5.5b'],
                                        inactive_driver_sites=[dict(method=r['method'], line=r['line'], call=r['call']) for r in report['driver_calls'] if r['status'] == 'inactive'],
                                        unsupported_modes=report['unsupported_modes'], evidence_errors=report['evidence_errors'])
    report['check_count'] = sum(len(a['checks']) for a in report['audits'])
    report['uncheckable_call_count'] = len(report['uncheckable_driver_calls'])
    report['current_5_5a_geometry_blockers'] = [r for r in report['findings'] if r['scope'] == 'current-5.5a'] + report['uncheckable_driver_calls']
    output.parent.mkdir(parents=True, exist_ok=True)
    report['host_helper_sha256'] = {n: sha(git('show', BASE + ':tools/harness/' + n + '.py'))
                                    for n in ('cerulean_journey', 'vermilion_journey', 'midgame_journey')}
    report['shared_geometry_helper_sha256'] = {n: sha((ROOT / 'tools/harness' / (n + '.py')).read_bytes())
                                              for n in ('brock_journey', 'parcel_journey', 'journeys')}
    report['implementation_source_sha256'] = {n: sha(git('show', BASE + ':Source/' + n))
                                             for n in ('game/rocketHideoutStoryWorld.lua', 'game/rocketHideoutStory.lua', 'domain/fieldTravel.lua')}
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(report=str(output), checks=report['check_count'],
                          audits=[dict(scope=a['scope'], **a['counts']) for a in report['audits']],
                          driver_call_counts=report['driver_call_counts'],
                          current_5_5a_geometry_blockers=len(report['current_5_5a_geometry_blockers']),
                          remaining_findings=[dict(scope=r['scope'], name=r['name'], status=r['status']) for r in report['findings']],
                          inactive_geometry_calls=sum(r['status'] == 'inactive' for r in report['driver_calls']),
                          unsupported_modes=report['unsupported_modes'],
                          evidence_errors=report['evidence_errors'])))
    return 1 if report['findings'] or report['uncheckable_driver_calls'] or report['evidence_errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
