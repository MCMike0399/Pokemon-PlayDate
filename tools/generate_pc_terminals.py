"""Generate Center PC coordinates from the immutable source hidden-event table."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
from tools.generate_kanto_maps import REVISION

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'data/events/hidden_events.asm'

def generate(reference):
    raw = subprocess.check_output(['git', '-C', str(reference), 'show', REVISION + ':' + SOURCE])
    if (reference / SOURCE).read_bytes() != raw:
        raise ValueError('hidden-event source differs from the required revision')
    terminals = {}
    current, index = None, 0
    for line in raw.decode().splitlines():
        text = line.split(';', 1)[0].strip()
        header = re.fullmatch(r'hidden_events_for ([A-Z0-9_]+)', text)
        if header:
            current, index = header[1], 0
        elif current and text.startswith('hidden_event '):
            index += 1
            fields = [value.strip() for value in text[len('hidden_event '):].split(',')]
            if len(fields) >= 4 and fields[2] == 'OpenPokemonCenterPC':
                assert fields[3] == 'SPRITE_FACING_UP'
                map_id = 'pokered:' + current
                terminals[map_id] = dict(id=map_id + ':hidden:' + str(index),
                                         x=int(fields[0]), y=int(fields[1]), facing='up')
    assert len(terminals) >= 10
    return (json.dumps(dict(schema=1, source_revision=REVISION, source=SOURCE,
                           source_sha256=hashlib.sha256(raw).hexdigest(), terminals=terminals),
                       sort_keys=True, separators=(',', ':')) + '\n').encode()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    target = ROOT / 'Source/data/pcTerminals.json'
    data = generate(args.reference)
    if args.check:
        assert target.read_bytes() == data, 'source PC coordinates changed'
    else:
        target.write_bytes(data)
    print('Verified source Center PC coordinates.')
