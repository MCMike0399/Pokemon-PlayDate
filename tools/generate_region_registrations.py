"""Build lightweight shipped declarations from exact SDK transform exports."""
import hashlib
import json
import re
from pathlib import Path

from tools.generate_content_cache import canonical, item_ids, require

ROOT = Path(__file__).resolve().parents[1]


def build(project=ROOT, cache_files=None, source_root=None, excluded_sources=()):
    project = Path(project)
    source = Path(source_root) if source_root is not None else project / 'Source'
    reference = project / 'tools/references/content-transforms-108'
    provenance = json.loads((reference / 'provenance.json').read_bytes())
    for name, expected in provenance['dependencies'].items():
        require(hashlib.sha256((project / 'Source' / name).read_bytes()).hexdigest() == expected,
                'transform dependency changed: ' + name)
        copied = source / name
        if not copied.is_file():
            require(any(name == excluded or name.startswith(excluded.rstrip('/') + '/')
                        for excluded in excluded_sources),
                    'staged transform dependency missing: ' + name)
        else:
            require(hashlib.sha256(copied.read_bytes()).hexdigest() == expected,
                    'staged transform dependency changed: ' + name)
    pins = project / 'tools/references/content-cache.json'
    require(hashlib.sha256(pins.read_bytes()).hexdigest() == provenance['content_pins_sha256'],
            'transform content inputs changed')
    owners = {'game/rocketHideoutStory', 'game/towerStory', 'game/snorlaxStory',
              'game/midgameGymStory', 'game/silphStory'}
    imports = [name for name in re.findall(r'import "([^"]+)"', (source / 'main.lua').read_text())
               if name in owners]
    require(imports == provenance['owner_imports'], 'transform owner imports changed')
    files = dict(cache_files or {})
    if not cache_files:
        files = {p.relative_to(source / 'data/contentCache').as_posix(): p.read_bytes()
                 for p in (source / 'data/contentCache').rglob('*.json')}
    catalog = json.loads(files['catalog.json'])['packages']
    result = {}
    for name, root in (('vermilion', 'data/vermilionPreparation/'),
                       ('midgameEast', 'data/midgameEast/'),
                       ('midgameSouth', 'data/midgameSouth/')):
        if root not in catalog:
            continue
        index = json.loads(files[catalog[root] + '.json'])
        events = dict(index['records']['events']['events'])
        events.update(index['records']['events']['signs'])
        trainers = dict(index['ordinary_trainers'])
        flags = dict(index['trainer_flags'])
        items = set(index['items']['events']) | set(index['items']['signs'])
        if name in provenance['exports']:
            raw = (reference / (name + '.json')).read_bytes()
            require(hashlib.sha256(raw).hexdigest() == provenance['exports'][name], 'SDK export changed')
            exported = json.loads(raw)
            require(exported['name'] == name and exported['schema'] == 1, 'transform identity differs')
            for stable, descriptor in exported['events'].items():
                require(descriptor['content'] == name, 'transformed content owner differs')
                encoded = canonical(descriptor)
                digest = hashlib.sha256(encoded).hexdigest()
                result['chunks/' + digest + '.json'] = encoded
                events[stable] = digest
                items.update(item_ids(descriptor))
            trainers = {}
            for stable, definition in exported['trainers'].items():
                if isinstance(definition, str):
                    require('chunks/' + definition + '.json' in files, 'unresolved original roster')
                    trainers[stable] = definition
                else:
                    require(definition['id'] == stable, 'transformed trainer identity differs')
                    encoded = canonical(definition)
                    digest = hashlib.sha256(encoded).hexdigest()
                    result['chunks/' + digest + '.json'] = encoded
                    trainers[stable] = digest
                    if definition.get('source_flag'):
                        flags[stable] = definition['source_flag']
        declaration = dict(schema=1, name=name, root=root, transform_identity=('hideout-tower-' + name + '-v1') if name in provenance['exports'] else False, records=events,
                           trainers=trainers, trainer_flags={key: flags[key] for key in trainers if key in flags},
                           items=sorted(items), chunks={Path(path).stem: True for path in result if path.startswith('chunks/')})
        result[name + '.json'] = canonical(declaration)
    result.update(kanto_declarations(project, source, files))
    return result


KANTO_OWNERS = ('game/kantoScenes', 'game/ceruleanStory', 'game/ceruleanRoutes',
                'game/ceruleanRoutesState', 'game/tutorialEscort')
KANTO_DEPENDENCIES = (
    'game/kantoScenes.lua', 'game/ceruleanStory.lua', 'game/ceruleanRoutes.lua',
    'game/ceruleanRoutesState.lua', 'game/sourceEvents.lua', 'game/sourceEventHandlers.lua',
    'data/ceruleanContent.lua', 'world/sourceMaps.lua',
    'domain/gameSession.lua', 'domain/party.lua', 'data/sourceMaps.json',
    'data/ceruleanStory/events.json', 'data/ceruleanStory/trainers.json',
    'data/ceruleanStory/dialogue.json', 'data/ceruleanStory/scenes.json',
    'data/ceruleanRoutes/scenes.json',
)


def kanto_declarations(project, source, cache_files):
    """Absent exact SDK evidence leaves both installers on their deep fallback."""
    reference = project / 'tools/integration/kanto-first-entry/qualified'
    if not (reference / 'provenance.json').is_file():
        return {}
    provenance = json.loads((reference / 'provenance.json').read_bytes())
    require(provenance['schema'] == 1 and set(provenance['dependencies']) == set(KANTO_DEPENDENCIES),
            'Kanto dependency set differs')
    for name, expected in provenance['dependencies'].items():
        for tree in (project / 'Source', source):
            require(hashlib.sha256((tree / name).read_bytes()).hexdigest() == expected,
                    'Kanto transform dependency changed: ' + name)
    require(hashlib.sha256((project / 'tools/references/content-cache.json').read_bytes()).hexdigest()
            == provenance['content_pins_sha256'], 'Kanto content pins changed')
    require({name: hashlib.sha256(raw).hexdigest() for name, raw in cache_files.items()}
            == provenance['content_cache'], 'Kanto copied content cache differs from SDK export')
    imports = [name for name in re.findall(r'import "([^"]+)"', (source / 'main.lua').read_text())
               if name in KANTO_OWNERS]
    require(imports == provenance['owner_imports'], 'Kanto copied owner imports changed')
    raw = (reference / 'export.json').read_bytes()
    require(hashlib.sha256(raw).hexdigest() == provenance['export_sha256'], 'Kanto SDK export changed')
    exported = json.loads(raw)
    require(provenance['sdk_version'] == '3.1.2'
            and exported['schema'] == 1 and exported['simulator'] is True
            and exported['build_id'] == provenance['build_id'], 'Kanto SDK producer differs')
    require(set(exported['sources']) == {'ceruleanStory', 'ceruleanRoutes'}, 'Kanto source set differs')
    result, namespaces, trainer_ids = {}, set(), set()
    for name, packet in exported['sources'].items():
        records, trainers, flags, bespoke, items, chunks = {}, {}, {}, {}, set(), {}
        for stable, descriptor in packet['events'].items():
            require(stable not in namespaces and descriptor['content'] == name,
                    'Kanto event namespace differs')
            namespaces.add(stable)
            encoded = canonical(descriptor)
            digest = hashlib.sha256(encoded).hexdigest()
            result['chunks/' + digest + '.json'] = encoded
            records[stable] = digest
            chunks[digest] = True
            items.update(item_ids(descriptor))
            if descriptor['kind'] == 'bespoke':
                bespoke[stable] = True
        # SDK JSON may encode an empty Lua table as an empty array. Story's
        # trainers are already shared, so its newly registered set can be empty.
        definitions = packet['trainers']
        if definitions == []:
            definitions = {}
        require(isinstance(definitions, dict), 'Kanto trainer object required')
        for stable, definition in definitions.items():
            require(stable not in trainer_ids and definition['id'] == stable,
                    'Kanto trainer namespace differs')
            trainer_ids.add(stable)
            encoded = canonical(definition)
            digest = hashlib.sha256(encoded).hexdigest()
            result['chunks/' + digest + '.json'] = encoded
            trainers[stable] = digest
            chunks[digest] = True
            if definition.get('source_flag'):
                flags[stable] = definition['source_flag']
        # The export ran the existing deep installers, including shared roster
        # comparisons and collision checks, against these pinned dependency bytes.
        result[name + '.json'] = canonical(dict(
            schema=1, name=name, root='data/' + name + '/', transform_identity='kanto-first-entry-v1',
            records=records, trainers=trainers, trainer_flags=flags, items=sorted(items),
            chunks=chunks, bespoke=bespoke, required_trainers=packet['required_trainers']))
    return result
