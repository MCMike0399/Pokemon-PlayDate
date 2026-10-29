"""SDK-only extension witness; never changes the shipping source manifest."""
import hashlib
import json
import tempfile
from pathlib import Path
from tools.generate_kanto_maps import Reference, decode_map
from tools.generate_source_map_cache import ROOT, build, canonical


def records(reference_root):
    manifest = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    # Private metadata overrides keep Route22 an independent extension witness
    # even though its shipping definition is now installed. Only SchoolHouse
    # adds an identity; open the controlled west edge only inside this fixture.
    city = manifest['maps']['ViridianCity']
    city['blocked_connections'] = [gate for gate in city.get('blocked_connections', [])
                                   if gate != 'west:ROUTE_22']
    result = {}
    with tempfile.TemporaryDirectory() as temporary:
        source = Path(temporary)
        # Only the decoded maps are needed. Regional descriptors and compact
        # files are deliberately absent from this source root.
        for entry in manifest['maps'].values():
            path = source / entry['path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / 'Source' / entry['path']).read_bytes())
        reference = Reference(reference_root)
        for name in ('Route22', 'ViridianSchoolHouse'):
            definition = decode_map(reference, name)
            data = canonical(definition)
            path = f'dev/source-map-extension/{name}.json'
            (source / path).parent.mkdir(parents=True, exist_ok=True)
            (source / path).write_bytes(data)
            result[path] = definition
            width, height = definition['dimensions']['cells']
            manifest['maps'][name] = {
                'id': definition['id'], 'key': 'fixture_' + name, 'path': path,
                'profile': 'source', 'width': max(13, width), 'height': height,
                'padding': max(0, (13 - width) // 2), 'source_sha256': hashlib.sha256(data).hexdigest(),
                'blocked_events': [], 'spawn': {'x': max(0, (13 - width) // 2), 'y': 0, 'facing': 'down'},
            }
        path = source / 'manifest.json'
        path.write_bytes(canonical(manifest))
        for name, content in build(path, source).items():
            # Overrides exercise raw extension records; runtime projections are
            # independently regenerated and need not duplicate this fixture.
            if name.startswith('runtime-'):
                continue
            result['data/sourceMapCache/' + name] = json.loads(content)
    result['data/sourceMaps.json'] = manifest
    return result
