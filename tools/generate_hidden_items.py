"""Import the pinned Blue hidden-item table. Coins stay with Celadon."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POKERED = Path('/home/ubuntu/Developer/Pokemon-PlayDate-env/pokered')
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
EVENT = re.compile(r'hidden_event\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(.+)$')
COORD = re.compile(r'hidden_item\s+([A-Z0-9_]+)\s*,\s*(\d+)\s*,\s*(\d+)')
COIN = re.compile(r'hidden_coin\s+([A-Z0-9_]+)\s*,\s*(\d+)\s*,\s*(\d+)')


def item_ids():
    text = (ROOT / 'Source/data/items.lua').read_text()
    block = text.split('bySymbol = ', 1)[1]
    return dict(re.findall(r'\["([A-Z0-9_]+)"\] = "([A-Za-z0-9]+)"', block))


def hidden_events(path):
    current = None
    ordinal = 0
    rows = []
    for raw in path.read_text().splitlines():
        line = raw.split(';', 1)[0].strip()
        note = raw.split(';', 1)[1].strip() if ';' in raw else ''
        if line.startswith('hidden_events_for '):
            current = line.split()[1]
            ordinal = 0
            continue
        match = EVENT.match(line)
        if not match or current is None:
            continue
        ordinal += 1
        x, y, handler, argument = match.groups()
        rows.append({
            'map': current,
            'ordinal': ordinal,
            'x': int(x),
            'y': int(y),
            'handler': handler,
            'argument': argument.strip(),
            'note': note,
        })
    return rows


def coords(path, pattern):
    rows = []
    for line in path.read_text().splitlines():
        match = pattern.search(line.split(';', 1)[0])
        if match:
            map_name, x, y = match.groups()
            rows.append({'map': map_name, 'x': int(x), 'y': int(y)})
    return rows


def build(pokered=POKERED):
    symbols = item_ids()
    events = hidden_events(pokered / 'data/events/hidden_events.asm')
    items = [row for row in events if row['handler'] == 'HiddenItems']
    if len(items) != 54:
        raise ValueError(f'expected 54 hidden items, found {len(items)}')
    table = coords(pokered / 'data/events/hidden_item_coords.asm', COORD)
    if len(table) != 54:
        raise ValueError(f'expected 54 hidden-item coordinates, found {len(table)}')
    used = set()
    imported = []
    for index, coord in enumerate(table):
        match = None
        for row in items:
            key = (row['map'], row['x'], row['y'])
            if key == (coord['map'], coord['x'], coord['y']) and key not in used:
                match = row
                used.add(key)
                break
        if match is None:
            raise ValueError(f'coordinate {index} has no hidden item event')
        item = symbols.get(match['argument'])
        if not item:
            raise ValueError(f'unknown item {match["argument"]}')
        event_id = f'pokered:{match["map"]}:hidden_events:{match["ordinal"]}'
        imported.append({
            'index': index,
            'map': match['map'],
            'map_id': 'pokered:' + match['map'],
            'x': match['x'],
            'y': match['y'],
            'item': item,
            'symbol': match['argument'],
            'id': event_id,
            'flag': 'PICKUP:' + event_id,
            'inaccessible': 'inaccessible' in match['note'],
        })
    coins = coords(pokered / 'data/events/hidden_coins.asm', COIN)
    if len(coins) != 12:
        raise ValueError(f'expected 12 hidden coins, found {len(coins)}')
    return {
        'schema': 1,
        'source_revision': REVISION,
        'sources': [
            'data/events/hidden_events.asm',
            'data/events/hidden_item_coords.asm',
            'data/events/hidden_coins.asm',
            'engine/events/hidden_items.asm',
            'engine/items/itemfinder.asm',
        ],
        'items': imported,
        'coins': coins,
    }


def main():
    payload = build()
    destination = ROOT / 'Source/data/hiddenItems.json'
    destination.write_text(json.dumps(payload, indent=2) + '\n')
    print(f'hidden items: {len(payload["items"])}; coins: {len(payload["coins"])}')


if __name__ == '__main__':
    main()
