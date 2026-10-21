#!/usr/bin/env python3
"""Required cache-backed primary qualification; never substitutes synthetic inputs."""
import argparse
import json
import re
import sys
from pathlib import Path
import generate_specimen_data as gen
from generate_items import load as load_items, collect as collect_items


def qualify(cache, items_cache, data, fetch=False):
    raw = gen.load(cache, fetch)
    item_rows = collect_items(load_items(items_cache, fetch))[0]
    species, natures, names, held = gen.collect(raw, item_rows)
    assert len(species) == 151 and len(names) == 111, 'original151/GenV ability inventory drift'
    for dex, expected in {1:[65,65,34],4:[66,66,94],7:[67,67,44],11:[61,61,61],
                          12:[14,14,110],74:[69,5,8],94:[26,26,26],133:[50,91,107]}.items():
        assert species[dex-1] == expected, f'literal GenV ability vector {dex}'
    assert len(natures) == 25 and sum(not any(row[1]) for row in natures) == 5, 'nature inventory drift'
    oracle = {}
    for key, body in re.findall(r'^\t(\w+): \{(.*?)\n\t\}', raw['data_natures.ts'].decode(), re.M | re.S):
        plus = re.search(r"plus: '(\w+)'", body); minus = re.search(r"minus: '(\w+)'", body)
        oracle[key] = (plus[1] if plus else None, minus[1] if minus else None)
    assert len(oracle) == 25, 'independent Showdown nature schema drift'
    for name, signs in natures:
        stats = ['atk','def','spa','spd','spe']
        expected = (next((stats[i] for i,x in enumerate(signs) if x == 1), None),
                    next((stats[i] for i,x in enumerate(signs) if x == -1), None))
        assert oracle[name.lower()] == expected, f'independent nature mismatch {name}'
    assert len(item_rows) == 124 and len(held) == 124, 'Blue catalog holdability coverage drift'
    assert sum(value is not False for value in held.values()) == 49, 'holdability inventory drift'
    assert held['potion'] == 17 and held['pokeBall'] == 4 and held['moonStone'] == 81
    assert all(held[key] is False for key in ('townMap','tm01','hm01','expAll'))
    assert Path(data).read_text() == gen.render(raw, item_rows), 'generated specimen data drift'
    return {'ok':True,'pinned_inputs':len(raw),'species':151,'ability_ids':111,
            'literal_species_vectors':8,'independent_nature_comparisons':25,
            'catalog_items':124,'holdable':49,'nonholdable':75,'generated_data_matches':True}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, required=True, help='explicit immutable specimen reference cache')
    parser.add_argument('--items-cache', type=Path, required=True, help='explicit immutable original item source cache')
    parser.add_argument('--data', type=Path, default=Path(__file__).resolve().parents[1]/'Source/data/specimenData.lua')
    parser.add_argument('--fetch', action='store_true', help='fetch only missing pinned inputs; never overwrite corrupt cache')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args(argv)
    try:
        result = qualify(args.cache, args.items_cache, args.data, args.fetch)
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
