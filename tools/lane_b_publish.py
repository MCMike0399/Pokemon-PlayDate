"""Publish an earned save without ever replacing an existing file."""
import json
from pathlib import Path


class SavePublishError(FileExistsError):
    """An earned save file name already exists."""


def fnv(data):
    value = 2166136261
    for byte in data:
        value = ((value ^ byte) * 16777619) & 0xffffffff
    return f'{value:08x}'


def rewrite_sequence(raw, sequence):
    """Change only the envelope sequence and its checksum. The payload stays."""
    if isinstance(raw, str):
        raw = raw.encode()
    text = raw.decode('utf-8')
    value = json.loads(text)
    payload = value['payload']
    if not isinstance(payload, str):
        raise SavePublishError('save payload must stay a string')
    old_sequence = value['sequence']
    old_checksum = value['checksum']
    new_sequence = str(int(sequence))
    if str(int(old_sequence)) != old_sequence or new_sequence != str(sequence):
        raise SavePublishError('sequence must be a canonical decimal')
    new_checksum = fnv(b'1\n' + new_sequence.encode() + b'\n' + payload.encode())
    updated = text.replace(f'"sequence":"{old_sequence}"', f'"sequence":"{new_sequence}"', 1)
    updated = updated.replace(f'"checksum":"{old_checksum}"', f'"checksum":"{new_checksum}"', 1)
    checked = json.loads(updated)
    if checked['payload'] != payload or checked['sequence'] != new_sequence or checked['checksum'] != new_checksum:
        raise SavePublishError('sequence rewrite did not keep the payload')
    if fnv(b'1\n' + new_sequence.encode() + b'\n' + payload.encode()) != new_checksum:
        raise SavePublishError('rewritten checksum does not match the payload')
    return updated.encode()


def highest_sequence(folder):
    folder = Path(folder)
    highest = 0
    if not folder.exists():
        return 0
    for path in folder.glob('*.json'):
        prefix = path.name.split('-', 1)[0]
        if prefix.startswith('seq') and prefix[3:].isdecimal():
            highest = max(highest, int(prefix[3:]))
        try:
            value = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        sequence = value.get('sequence') if isinstance(value, dict) else None
        if isinstance(sequence, str) and sequence.isdecimal():
            highest = max(highest, int(sequence))
    return highest


def publish_save(source, folder, filename):
    """Copy one save to a new file name. An existing name is an error."""
    folder = Path(folder)
    name = Path(filename).name
    if name != filename or not name.endswith('.json') or name in {'.json', '..json'}:
        raise SavePublishError('save file name must be a single json file')
    destination = folder / name
    if destination.exists():
        raise SavePublishError(f'refusing to overwrite {name}')
    data = Path(source).read_bytes() if not isinstance(source, (bytes, bytearray)) else bytes(source)
    folder.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return destination
