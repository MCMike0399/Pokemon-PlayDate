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
from tools.harness.midgame_journey import MidgameJourney
from tools.harness.protocol import ProtocolError
from tools.harness.parcel_journey import NAMES as PARCEL_NAMES

ROOT = Path(__file__).resolve().parents[2]
BASE = 'baaf6368c57e3c9db2863cfc3b7c530d1bae1d88'
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
            self.record(name, 'segment', 'gap' if requires else 'pass', steps=len(steps), **row)
        except ProtocolError as error:
            self.record(name, 'segment', 'gap' if requires else 'unreachable', error=str(error), **row)

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='one JSON report outside Git')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error('report must be outside the repository')
    plan = json.loads((DATA / 'preflight-routes.json').read_bytes())
    report = dict(schema=1, kind='host geometry only; no journey evidence changed',
                  base_commit=BASE, prepared_commit=PREPARED,
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
                for mutation in section.get('mutations', []):
                    model = audit.model(mutation['map'])
                    point = audit.point(model, mutation['cell'])
                    audit.record(mutation['name'], 'mutation', 'gap', map=mutation['map'],
                                 cell=point, source_sha256=model.descriptor['source_sha256'],
                                 collision_before=model.collision[point[1]][point[0]],
                                 requires=mutation['requires'], impact='requires-earned-mutation-or-capability')
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
            except (KeyError, ValueError, ProtocolError, subprocess.CalledProcessError) as error:
                audit.record('source decoding', 'input', 'gap', error=str(error))
            counts = {status: sum(r['status'] == status for r in audit.rows)
                      for status in ('pass', 'unreachable', 'gap', 'excluded')}
            report['audits'].append(dict(scope=scope, commit=ref, source_hashes=audit.sources,
                                         counts=counts, counts_by_kind={kind: sum(r['kind'] == kind for r in audit.rows)
                                                                      for kind in sorted({r['kind'] for r in audit.rows})},
                                         checks=audit.rows))
    report['findings'] = [row for a in report['audits']
                          for row in a['checks'] if row['status'] in {'gap', 'unreachable'}]
    report['coverage'] = 'incomplete until every uncheckable_driver_call has a shared declarative origin and occupancy; fail closed'
    report['check_count'] = sum(len(a['checks']) for a in report['audits'])
    report['uncheckable_call_count'] = len(report['uncheckable_driver_calls'])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(report=str(output), checks=report['check_count'],
                          audits=[dict(scope=a['scope'], **a['counts']) for a in report['audits']],
                          uncheckable_driver_calls=report['uncheckable_call_count'])))
    return 1 if report['uncheckable_driver_calls'] or any(a['counts']['unreachable'] or a['counts']['gap'] for a in report['audits']) else 0


if __name__ == '__main__':
    raise SystemExit(main())
