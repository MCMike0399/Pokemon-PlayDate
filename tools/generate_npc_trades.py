"""Generate only the nine used English Blue trades from immutable local inputs."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from tools.materialize_pokered_packages import reference_root
from tools.check_npc_trade_policy import EXPECTED, REVISION
from tools.generate_cerulean_content import text_recipes

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = reference_root('npc-trades')
OUTPUT = ROOT / 'Source/data/npcTrades/policy.json'


def build(reference=REFERENCE):
    pin = json.loads((reference / 'manifest.json').read_text())
    assert pin['revision'] == REVISION
    sources = {}
    for name, digest in pin['files'].items():
        raw = (reference / name).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == digest, name
        sources[name] = raw.decode()
    rows = re.findall(r'^\s*npctrade\s+(\w+),\s+(\w+),\s+TRADE_DIALOGSET_(\w+),\s+"([^"]+)"', sources['data/events/trades.asm'], re.M)
    assert len(rows) == 10 and rows[2] == ('BUTTERFREE', 'BEEDRILL', 'HAPPY', 'CHIKUCHIKU')
    species = {'MR_MIME': 'mr', 'NIDORAN_M': 'nidoranM', 'NIDORAN_F': 'nidoranF'}
    names = {'MR_MIME': 'MR.MIME', 'NIDORAN_M': 'NIDORAN♂', 'NIDORAN_F': 'NIDORAN♀', 'FARFETCHD': "FARFETCH'D"}
    trades, events = {}, {}
    current = set(json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())['maps'])
    for index, wanted, received, nickname, map_name, actor, dialogue in EXPECTED:
        assert rows[index] == (wanted, received, dialogue, nickname)
        script = sources[f'scripts/{map_name}.asm']
        objects = sources[f'data/maps/objects/{map_name}.asm']
        entry = re.findall(r'^\s*object_event\s+(.+)$', objects, re.M)[actor - 1]
        pointer = next(k for k, v in re.findall(r'dw_const\s+(\w+),\s+(\w+)', script) if v == entry.split(',')[-1].strip())
        assert f'TRADE_FOR_{nickname}' in script.split(pointer + ':', 1)[1].split('\n\n', 1)[0]
        constant = re.search(r'def_warps_to\s+(\w+)', objects)[1]
        source_id = f'pokered:{constant}:objects:{actor}'
        trade = dict(index=index, sourceId=source_id, wanted=species.get(wanted, wanted.lower()),
                     offered=species.get(received, received.lower()), nickname=nickname,
                     wantedName=names.get(wanted, wanted), offeredName=names.get(received, received),
                     dialogue={'CASUAL': 1, 'EVOLUTION': 2, 'HAPPY': 3}[dialogue],
                     flag=f'pokered:trade:TRADE_FOR_{nickname}')
        trades[source_id] = trade
        if map_name in current:
            events[source_id] = dict(kind='bespoke', content='npc-trades', restore_interaction_facing=True)
    recipes = text_recipes(sources['data/text/text_7.asm'])
    labels = ['_ConnectCableText', '_TradedForText'] + [f'_{branch}{i}Text' for i in range(1, 4) for branch in ['WannaTrade', 'NoTrade', 'WrongMon', 'Thanks', 'AfterTrade']]
    texts = {label: dict(source='data/text/text_7.asm', recipe=recipes[label]) for label in labels}
    assert len(trades) == 9 and all(t['index'] != 2 for t in trades.values())
    engine = sources['engine/events/in_game_trades.asm']
    assert engine.index('call RemovePokemon') < engine.index('call AddPartyMon')
    return dict(schema=1, source_revision=REVISION, trades=trades, events=events, texts=texts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    result = json.dumps(build(), ensure_ascii=False, indent=2) + '\n'
    if args.check:
        assert args.output.read_text() == result, 'stale NPC trade data'
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(result)


if __name__ == '__main__':
    main()
