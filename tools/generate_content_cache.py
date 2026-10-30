#!/usr/bin/env python3
"""Generate immutable per-record content chunks from checksum-pinned JSON inputs.

No game Lua is executed. --check compares the entire generated file set.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PINS = ROOT / 'tools/references/content-cache.json'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
DESTINATION = ROOT / 'Source/data/contentCache'


def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def item_ids(value):
    found = set()
    if isinstance(value, dict):
        if 'item' in value:
            found.add(value['item'])
        if value.get('op') == 'give-item':
            found.add(value['id'])
        for field in ('items_equal', 'items_min'):
            found.update(value.get(field, {}))
        for child in value.values():
            found.update(item_ids(child))
    elif isinstance(value, list):
        for child in value:
            found.update(item_ids(child))
    return found


def build(source_root=ROOT / 'Source', pins_path=PINS):
    source_root = Path(source_root).resolve()
    pins_bytes = Path(pins_path).read_bytes()
    pins = json.loads(pins_bytes)
    require(pins['schema'] == 1 and pins['source_revision'] == REVISION, 'unverified content pins')
    files = {}

    def read(path):
        location = (source_root / path).resolve()
        require(location.is_relative_to(source_root), 'content path escapes source root')
        raw = location.read_bytes()
        require(hashlib.sha256(raw).hexdigest() == pins['inputs'][path], 'pinned content checksum differs: ' + path)
        data = json.loads(raw)
        require(data['schema'] == 1 and data['source_revision'] == REVISION, 'unverified content revision')
        return data

    def index(records):
        result = {}
        for key, value in sorted(records.items()):
            raw = canonical(value)
            digest = hashlib.sha256(raw).hexdigest()
            files['chunks/' + digest + '.json'] = raw
            result[key] = digest
        return result

    def emit(name, records):
        for values in records.get('events', {}).values():
            for key, event in values.items():
                require(re.fullmatch(r'pokered:[^:]+:(objects|background_events|hidden_events):[0-9]+', key)
                        or name == 'base' and re.fullmatch(r'pokered:[^:]+:(hidden:[0-9]+|script:[a-z-]+)', key),
                        'unstable source event identity')
                require(isinstance(event, dict) and isinstance(event.get('content'), str), 'invalid source descriptor')
        for key, trainer in records.get('trainers', {}).get('trainers', {}).items():
            require(re.fullmatch(r'pokered:[^:]+:objects:[0-9]+', key)
                    and trainer['id'] == key and trainer['map_id'] == ':'.join(key.split(':')[:2]),
                    'unstable source trainer identity')
        data = dict(schema=1, source_revision=REVISION, records={}, items={}, trainer_flags={}, contents={})
        for record, fields in records.items():
            data['records'][record] = {field: index(values) for field, values in fields.items()}
            if record == 'events':
                data['items'] = {field: sorted(item_ids(values)) for field, values in fields.items()}
                data['contents'] = {field: sorted({v['content'] for v in values.values()}) for field, values in fields.items()}
            if record == 'trainers':
                data['trainer_flags'] = {key: value['source_flag'] for key, value in fields['trainers'].items()
                                         if value.get('source_flag')}
        data['ordinary_trainers'] = {key: digest for key, digest in data['records'].get('trainers', {}).get('trainers', {}).items()
                                     if records.get('events', {}).get('events', {}).get(key, {}).get('kind') == 'trainer'}
        data['bespoke_trainers'] = {key: digest for key, digest in data['records'].get('trainers', {}).get('trainers', {}).items()
                                    if records.get('events', {}).get('events', {}).get(key, {}).get('kind') == 'bespoke'}
        files[name + '.json'] = canonical(data)
        # Registration uses the complete index transiently. Runtime lookups
        # need one field, without decoding all dialogue/art/membership again.
        for record, fields in data['records'].items():
            for field, values in fields.items():
                files[f'{name}-{record}-{field}.json'] = canonical(dict(
                    schema=1, source_revision=REVISION, records=values))

    events = read('data/sourceEvents.json')['events']
    trainer_meta = read('data/pewterSlice/trainerNames.json')
    trainers = {}
    for original in read('data/pewterSlice/trainers.json')['trainers']:
        value = dict(original, name=trainer_meta['names'][original['class_source']],
                     sprite_source=trainer_meta['sprites'][original['id']])
        require(value['id'] not in trainers, 'duplicate base trainer')
        trainers[value['id']] = value
    emit('base', {'events': {'events': events}, 'trainers': {'trainers': trainers}})
    catalog = {}
    for number, root in enumerate(sorted(pins['packages']), 1):
        records = {}
        for record, fields in {'dialogue': ['texts'], 'sprites': ['sprites'],
                               'events': ['events', 'signs'], 'trainers': ['trainers', 'rival_classes']}.items():
            data = read(root + record + '.json')
            records[record] = {field: data[field] for field in fields}
        require(not (records['events']['events'].keys() & records['events']['signs'].keys()), 'duplicate package event')
        for key, event in records['events']['events'].items():
            if event['kind'] == 'trainer':
                require(key in records['trainers']['trainers'], 'source package roster missing')
        name = 'package-' + str(number)
        emit(name, records)
        catalog[root] = name
    files['catalog.json'] = canonical(dict(schema=1, source_revision=REVISION, packages=catalog,
                                           pins_sha256=hashlib.sha256(pins_bytes).hexdigest()))
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=DESTINATION)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = build()
    if args.check:
        actual = {str(p.relative_to(args.output_dir)): p.read_bytes() for p in args.output_dir.rglob('*.json')}
        require(actual == files, 'generated content cache differs; regenerate in a review directory')
    else:
        require(not args.output_dir.exists(), 'generation requires a fresh output directory')
        for name, raw in files.items():
            path = args.output_dir / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(f'Checked {len(files)} content cache artifacts' if args.check else f'Generated {len(files)} content cache artifacts')


if __name__ == '__main__':
    main()
