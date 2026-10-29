#!/usr/bin/env python3
"""Generate leader victory/retry descriptors from exact Blue source labels."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
OUTPUT = ROOT / 'Source/data/midgameGymStory'
SPECS = [
    ('CeladonGym', 'CELADON_GYM', 'midgameEast', 'ERIKA', 'RAINBOW', '21', 7,
     ['_CeladonGymErikaPreBattleText', '_CeladonGymErikaReceivedRainbowBadgeText', '_CeladonGymErikaPostBattleAdviceText',
      '_CeladonGymRainbowBadgeInfoText', '_CeladonGymReceivedTM21Text', '_TM21ExplanationText', '_CeladonGymTM21NoRoomText']),
    ('FuchsiaGym', 'FUCHSIA_GYM', 'midgameSouth', 'KOGA', 'SOUL', '06', 6,
     ['_FuchsiaGymKogaBeforeBattleText', '_FuchsiaGymKogaReceivedSoulBadgeText', '_FuchsiaGymKogaPostBattleAdviceText',
      '_FuchsiaGymKogaSoulBadgeInfoText', '_FuchsiaGymKogaReceivedTM06Text', '_FuchsiaGymKogaTM06ExplanationText', '_FuchsiaGymKogaTM06NoRoomText']),
    ('SaffronGym', 'SAFFRON_GYM', 'midgameSaffron', 'SABRINA', 'MARSH', '46', 7,
     ['_SaffronGymSabrinaText', '_SaffronGymSabrinaReceivedMarshBadgeText', '_SaffronGymSabrinaPostBattleAdviceText',
      '_SaffronGymSabrinaMarshBadgeInfoText', '_SaffronGymSabrinaReceivedTM46Text', '_TM46ExplanationText', '_SaffronGymSabrinaTM46NoRoomText']),
]


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def build(reference):
    head = subprocess.check_output(['git', '-C', str(reference), 'rev-parse', 'HEAD'], text=True).strip()
    if head != REVISION:
        raise ValueError('exact pinned Blue reference required')
    sources, pins = {}, {}
    for name in [row[0] for row in SPECS] + ['FightingDojo']:
        path = f'scripts/{name}.asm'
        raw = (reference / path).read_bytes()
        if raw != subprocess.check_output(['git', '-C', str(reference), 'show', f'{REVISION}:{path}']):
            raise ValueError('modified source input: ' + path)
        sources[name] = raw.decode()
        pins[path] = hashlib.sha256(raw).hexdigest()
    events = {}
    for name, constant, content, leader, badge, tm, count, labels in SPECS:
        source = sources[name]
        available = set(re.findall(r'text_far\s+(_\w+)', source))
        assert set(labels) <= available
        assert f'SetEvent EVENT_BEAT_{leader}' in source and f'SetEvent EVENT_GOT_TM{tm}' in source
        actual = re.findall(r'trainer EVENT_BEAT_' + constant + r'_TRAINER_\d+', source)
        assert len(actual) == count
        victory = {f'EVENT_BEAT_{leader}': True, 'BADGE_' + badge: True}
        events[f'pokered:{constant}:objects:1'] = dict(
            kind='trainer', content=content, before=labels[:1], won=labels[1:2], after=labels[2:3],
            victory=dict(flags=victory, guard_flags=list(victory),
                         trainers={f'pokered:{constant}:objects:{index}': True for index in range(2, count + 2)}),
            reward=dict(item='tm' + tm, flag='EVENT_GOT_TM' + tm, before=labels[3:4],
                        success=labels[4:6], full=labels[6:7], full_status='bag-full'))
    dojo = 'pokered:FIGHTING_DOJO:objects:'
    flags = {'EVENT_BEAT_KARATE_MASTER': True}
    events[dojo + '1'] = dict(kind='bespoke', content='midgameSaffron',
        before=['_FightingDojoKarateMasterText'], won=['_FightingDojoKarateMasterDefeatedText'],
        after=['_FightingDojoKarateMasterIWillGiveYouAPokemonText'],
        victory=dict(flags=flags, guard_flags=list(flags),
                     trainers={dojo + str(i): True for i in range(2, 6)}))
    for index, species in ((6, 'hitmonlee'), (7, 'hitmonchan')):
        events[dojo + str(index)] = dict(kind='bespoke', content='midgameSaffron', species=species,
                                         flag='EVENT_GOT_' + species.upper(), level=30,
                                         choice_label='_FightingDojo' + species.title() + 'PokeBallText')
    source = sources['FightingDojo']
    assert 'ld c, 30' in source and 'SetEvents EVENT_GOT_HITMONLEE, EVENT_DEFEATED_FIGHTING_DOJO' in source
    assert 'SetEvents EVENT_GOT_HITMONCHAN, EVENT_DEFEATED_FIGHTING_DOJO' in source
    return {'events.json': encoded(dict(schema=1, source_revision=REVISION, events=events)),
            'provenance.json': encoded(dict(schema=1, source_revision=REVISION, files=pins))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, raw in build(args.reference).items():
        path = OUTPUT / name
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise SystemExit('stale source descriptor: ' + str(path))
        else:
            path.write_bytes(raw)


if __name__ == '__main__':
    main()
