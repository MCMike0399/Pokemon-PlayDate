"""Build lightweight shipped declarations from exact SDK transform exports."""
import hashlib
import json
import re
from pathlib import Path

from tools.generate_content_cache import canonical, item_ids, require

ROOT = Path(__file__).resolve().parents[1]


def build(project=ROOT, cache_files=None):
    project = Path(project)
    source = project / 'Source'
    reference = project / 'tools/references/content-transforms-108'
    provenance = json.loads((reference / 'provenance.json').read_bytes())
    for name, expected in provenance['dependencies'].items():
        require(hashlib.sha256((source / name).read_bytes()).hexdigest() == expected,
                'transform dependency changed: ' + name)
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
    return result
