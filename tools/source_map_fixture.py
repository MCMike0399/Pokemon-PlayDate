"""SDK-only extension witness; never changes the shipping source manifest."""
import hashlib
import json
import tempfile
from pathlib import Path
from tools.generate_kanto_maps import Reference, decode_map
from tools.generate_source_map_cache import ROOT, build, canonical


def records(reference_root):
    manifest = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    # Private metadata overrides keep Route 22 and the school house as
    # independent extension witnesses. Both shipping definitions are installed.
    # Open the controlled west edge only inside this fixture.
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
        if 'SilphCo3F' in manifest['maps'] and 'SilphCo11F' in manifest['maps']:
            path = source / 'data/silphStory/tiles.json'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / 'Source/data/silphStory/tiles.json').read_bytes())
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


def disk_patch(full):
    """SDK fixture overlay. Unchanged maps and tile rows stay in the live cache."""
    live_manifest = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())
    live_compact = json.loads((ROOT / 'Source/data/sourceMapCache/compact.json').read_bytes())
    live_grids = json.loads((ROOT / 'Source/data/sourceMapCache/tile-grids.json').read_bytes())
    fixture_compact = full['data/sourceMapCache/compact.json']
    fixture_grids = full['data/sourceMapCache/tile-grids.json']
    if fixture_compact['tiles'] != live_compact['tiles']:
        raise ValueError('fixture tile catalogue differs from the live cache')
    if fixture_compact['door_tiles'] != live_compact['door_tiles']:
        raise ValueError('fixture door tiles differ from the live cache')
    # The live atlas may gain tiles the extension witness never places.
    # Every tile the witness does name must still be the live grid.
    for key, grid in fixture_grids['tiles'].items():
        if live_grids['tiles'].get(key) != grid:
            raise ValueError('fixture tile grid differs from the live cache: ' + key)
    manifest = {}
    for name, entry in full['data/sourceMaps.json']['maps'].items():
        if entry != live_manifest['maps'][name]:
            manifest[name] = entry
    compact = {}
    for name, descriptor in fixture_compact['maps'].items():
        live = live_compact['maps'][name]
        fields = {key: value for key, value in descriptor.items() if value != live[key]}
        if fields:
            compact[name] = fields
    extensions = {path: value for path, value in full.items() if path.startswith('dev/')}
    return {
        'schema': 2,
        'source_revision': full['data/sourceMaps.json']['source_revision'],
        'manifest': manifest,
        'compact': compact,
        'extensions': extensions,
    }
