"""Verify pinned Blue Day Care rules and emit its narrow event descriptor."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/daycare'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
PREPARATION = ROOT / 'Source/data/vermilionPreparation'


def sources(reference=REFERENCE):
    pin = json.loads((reference / 'manifest.json').read_text())
    assert pin['revision'] == REVISION
    result = {}
    for name, digest in pin['files'].items():
        raw = (reference / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('unverified Day Care source: ' + name)
        result[name] = raw.decode()
    return result


def build(reference=REFERENCE):
    src = sources(reference)
    script = src['scripts/Daycare.asm']
    assert script.index('callfar KnowsHMMove') < script.index('ld a, PARTY_TO_DAYCARE')
    assert 'ld a, [wPartyCount]\n\tdec a' in script
    assert 'cp PARTY_LENGTH' in script and 'ld a, $1' in script
    assert 'ld a, [wDayCareNumLevelsGrown]\n\tinc a' in script
    assert '.leaveMonInDayCare\n' in script and 'ld [wDayCareMonBoxLevel], a' in script
    assert 'call HasEnoughMoney' in script and 'predef SubBCDPredef' in script
    assert 'predef WriteMonMoves' in script and '; set mon\'s HP to max' in script
    assert 'call IncrementDayCareMonExp' in src['engine/events/poison.asm']
    assert 'ld hl, wDayCareMonExp + 2\n\tinc [hl]' in src['engine/overworld/daycare_exp.asm']
    learning = src['engine/pokemon/evos_moves.asm']
    assert 'jr nc, .nextMove2 ; min level >= move level' in learning
    assert 'shift all moves one up (deleting move 1)' in learning
    assert 'shift PP as well if learning moves from day care' in learning
    assert 'ld a, $99' in src['engine/math/bcd.asm']
    assert '; returning mon to party, compute level and stats' in src['engine/pokemon/add_mon.asm']
    hm = src['data/moves/hm_moves.asm']
    assert [line.strip().split()[1] for line in hm.splitlines() if line.strip().startswith('db ')][:-1] == ['CUT', 'FLY', 'SURF', 'STRENGTH', 'FLASH']
    prepared = json.loads((PREPARATION / 'Daycare.json').read_text())
    actor = prepared['events']['objects'][0]
    assert actor['id'] == 'pokered:DAYCARE:objects:1'
    ordinary = json.loads((PREPARATION / 'events.json').read_text())['events']
    assert actor['id'] not in ordinary
    texts = json.loads((PREPARATION / 'dialogue.json').read_text())['texts']
    labels = sorted(label for label in texts if label.startswith('_DaycareGentleman'))
    assert len(labels) == 15
    out = dict(schema=1, source_revision=REVISION,
               events={actor['id']: dict(kind='bespoke', content='daycare', service='daycare')},
               labels=labels, base_fee=100, per_level_fee=100, fee_limit=9999, xp_per_step=1,
               hm_moves=['cut', 'fly', 'surf', 'strength', 'flash'])
    return (json.dumps(out, indent=2, sort_keys=True) + '\n').encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    raw = build()
    target = args.output or ROOT / 'Source/data/daycare/policy.json'
    if args.check:
        assert target.read_bytes() == raw, 'stale Day Care artifact'
    else:
        assert args.output, 'explicit output file required'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)


if __name__ == '__main__':
    main()
