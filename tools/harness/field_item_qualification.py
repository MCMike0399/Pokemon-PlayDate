"""Mandatory native Town Map proof, finalized only after producer quiescence.

The raster oracle is independent of the Lua renderer. Source transcription pins
are checked separately; this proof binds its composition to the identified build.
"""
import hashlib
import json
import re
from pathlib import Path

from tools.harness.catalog_qualification import requests_contracts
from tools.harness.protocol import ProtocolError, atomic_json

FEATURE = 'dev/fieldItemContracts.lua'
SUITE = 'brock-field-items'
QUALIFIER = 'field-map-v1'
MAPS = {
    'field-town-map-forest': ('VIRIDIAN_FOREST', 'VIRIDIAN_FOREST'),
    'field-town-map-pallet-selected': ('VIRIDIAN_FOREST', 'PALLET_TOWN'),
    'field-map-before-save': ('PALLET_TOWN', 'PALLET_TOWN'),
    'field-map-route1-selected': ('PALLET_TOWN', 'ROUTE_1'),
    'field-map-after-continue': ('PALLET_TOWN', 'PALLET_TOWN'),
}


def image_dependency():
    try:
        from PIL import Image
    except ImportError as error:
        raise ProtocolError('field-map proof requires Pillow; install tools/requirements-dev.txt') from error
    return Image


def prepare(output, scenario=None, *, launching=False):
    if not (Path(output)/'Source'/FEATURE).is_file():
        return
    if launching and scenario is not None and (requests_contracts(scenario) or 'field-' in json.dumps(scenario)):
        image_dependency()


def raster(data):
    patterns = {'1': [0xBB,0xFF,0xEE,0xFF,0xBB,0xFF,0xEE,0xFF],
                '2': [0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA]}
    def shade(code, x, y):
        if code in '.#':
            return 255 if code == '.' else 0
        return 255 if patterns[code][y%8] >> (7-x%8) & 1 else 0
    pixels = [[shade(data['tiles'][data['cells'][y//8*20+x//8]][y%8][x%8],x,y)
               for x in range(160)] for y in range(144)]
    return pixels, shade


def marker(pixels, grid, point, shade):
    outside = set()
    queue = [(x,y) for x in range(16) for y in range(16) if x in (0,15) or y in (0,15)]
    while queue:
        x,y = queue.pop()
        if not (0<=x<16 and 0<=y<16) or (x,y) in outside or grid[y][x] != '.':
            continue
        outside.add((x,y))
        queue.extend(((x-1,y),(x+1,y),(x,y-1),(x,y+1)))
    for y in range(16):
        for x in range(16):
            if (x,y) not in outside:
                pixels[point['y']*8+8+y][point['x']*8+16+x] = shade(grid[y][x],x,y)


def finalize(output, data, evidence, identity):
    """Normal runner calls this before process images are archived/cleared."""
    output, evidence = Path(output), Path(evidence)
    if not (output/'Source'/FEATURE).is_file():
        return None
    report = dict(schema=1, qualifier=QUALIFIER, ok=False, quiescent=True,
                  build_id=identity['build_id'], session_id=identity['session_id'])
    target = evidence/'field-map-qualification.json'
    try:
        executions, selected, contracts_seen = [], set(), False
        for result_path in sorted(evidence.glob('*-result.json')):
            if not re.fullmatch(r'[0-9]{5}-result.json', result_path.name):
                continue
            request_path = result_path.with_name(result_path.name[:5]+'-request.json')
            if result_path.is_symlink() or request_path.is_symlink() or not request_path.is_file():
                raise ProtocolError('unsafe/missing field proof request')
            request = json.loads(request_path.read_text())
            commands = request.get('commands', [])
            shots = {c.split()[1] for c in commands if isinstance(c,str) and len(c.split())==2 and c.split()[0]=='shot' and c.split()[1] in MAPS}
            contracts = requests_contracts({'commands':commands})
            if not contracts and not shots:
                continue
            packet = json.loads(result_path.read_text())
            if any(packet.get(k)!=identity[k] or request.get(k)!=identity[k] for k in ('protocol','build_id','session_id')) or packet.get('id')!=request.get('id') or packet.get('status')!='ok':
                raise ProtocolError('failed/wrong-build/session/request field execution')
            record = dict(request=request_path.name, result=result_path.name, request_id=packet['id'],
                          request_sha256=hashlib.sha256(request_path.read_bytes()).hexdigest(),
                          result_sha256=hashlib.sha256(result_path.read_bytes()).hexdigest())
            if contracts:
                contracts_seen = True
                matches = []
                for row in packet.get('results', []):
                    if row.get('op')!='contracts':
                        continue
                    native = row.get('contracts', {})
                    suites = native.get('suites')
                    if not isinstance(suites,list) or native.get('ok') is not True:
                        raise ProtocolError('missing/failed field suite metadata')
                    ids = [s.get('id') for s in suites]
                    if len(set(ids))!=len(ids):
                        raise ProtocolError('duplicate field suite metadata')
                    for suite in suites:
                        if suite.get('id')==SUITE:
                            if suite.get('artifact_qualifier')!=QUALIFIER or suite.get('ok') is not True:
                                raise ProtocolError('native field suite did not qualify')
                            matches.append(suite)
                        elif suite.get('artifact_qualifier')==QUALIFIER:
                            raise ProtocolError('field qualifier attached to wrong suite')
                if len(matches)!=1:
                    raise ProtocolError('expected exactly one native field suite')
                record['suite'] = matches[0]
                selected.update(('field-town-map-forest','field-town-map-pallet-selected'))
            selected.update(shots)
            executions.append(record)
        if not executions:
            return None
        if contracts_seen and sum('suite' in e for e in executions)!=1:
            raise ProtocolError('repeated field suite artifacts cannot qualify')
        build = json.loads((output/'build.json').read_text())
        if any(build.get(k)!=identity[k] for k in ('build_id','session_id')):
            raise ProtocolError('field build identity mismatch')
        process_path = evidence/'process.json' if (evidence/'process.json').is_file() else output/'run.json'
        process = json.loads(process_path.read_text())
        pid = process.get('pid',process.get('simulator_pid'))
        if type(pid) is not int or pid<=0:
            raise ProtocolError('field proof missing owned process PID')
        manifest = json.loads((output/'source-manifest.json').read_text())
        source = output/'Source'
        for name in ('data/townMap.json','world/sprites/red.lua'):
            path = source/name
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=manifest.get(name):
                raise ProtocolError('field proof identified source changed')
        town = json.loads((source/'data/townMap.json').read_text())
        red = (source/'world/sprites/red.lua').read_text()
        grid = re.findall(r'"([.#12]{16})"',re.search(r'\bdown\s*=\s*\{([^}]+)',red)[1])
        if len(grid)!=16:
            raise ProtocolError('invalid RED source grid')
        Image = image_dependency()
        records = []
        for name in sorted(selected):
            current, selection = MAPS[name]
            pixels, shade = raster(town)
            marker(pixels,town['cursor'],town['locations'][selection],shade)
            marker(pixels,grid,town['locations'][current],shade)
            expected = [(v,v,v,255) for row in pixels for v in row]
            path = output/'frames'/(name+'.png')
            if path.is_symlink() or not path.is_file():
                raise ProtocolError('missing/unsafe native field image: '+name)
            with Image.open(path) as image:
                if image.format!='PNG' or image.size!=(400,240):
                    raise ProtocolError('wrong native field image format/dimensions')
                actual = list(image.convert('RGBA').crop((12,48,172,192)).getdata())
            changed = sum(a!=b for a,b in zip(actual,expected))
            if len(actual)!=23040 or changed:
                raise ProtocolError(f'{name}: {changed} source-map RGBA pixels differ')
            records.append(dict(path='frames/'+name+'.png', checked_pixels=23040,
                                changed_pixels=0, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        report.update(ok=True, maps=records, executions=executions, process_pid=pid,
                      process_generation=process.get('generation',1),
                      runtime_manifest_sha256=hashlib.sha256(process_path.read_bytes()).hexdigest(),
                      source_sha256=build['source_sha256'], compiled_source_sha256=build['compiled_source_sha256'],
                      sdk_version=build['sdk_version'])
        atomic_json(target,report)
        return report
    except BaseException as error:
        report['error'] = str(error)
        atomic_json(target,report)
        if isinstance(error,ProtocolError):
            raise
        raise ProtocolError('field-map qualification failed: '+str(error)) from error
