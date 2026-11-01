#!/usr/bin/env python3
"""Read collected evidence only. Missing/partial runs never receive coverage."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from prepare import PACKET, check_inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--attempt', type=Path, required=True)
    args = parser.parse_args()
    build = json.loads((args.stage / 'build.json').read_text())
    run = args.attempt
    data = run / 'after/Data' / build['bundle_id']
    failures = []
    entries, samples, battles = [], [], []
    try:
        check_inputs()  # Also recheck untouched canonical earned/provenance bytes.
        rows = [json.loads(line) for line in (data / 'long-traversal.jsonl').read_text().splitlines()]
        assert rows and rows[0]['kind'] == 'start' and rows[0]['platform'] == 'device'
        assert [r['seq'] for r in rows] == list(range(1, len(rows) + 1))
        assert all(r['build'] == build['build_id'] for r in rows)
        serial = (run / 'serial.raw').read_text(errors='replace')
        console = [json.JSONDecoder().raw_decode(line.split('LTR1 ', 1)[1])[0]
                   for line in serial.splitlines() if 'LTR1 ' in line]
        assert console == rows, 'console/file diagnostic receipts differ'
        # Ignore JSON field names such as error:null, but surface native/runtime
        # diagnostics verbatim alongside complete retained error/crash logs.
        native = [line for line in serial.splitlines() if re.search(
            r'out of memory|allocation fail|malloc.*fail|BOOTERROR|drawFaded.*(?:nil|error)|panic|fatal',
            line, re.I)]
        if native:
            failures.extend(native)
        entries = [r for r in rows if r['kind'] == 'entry']
        samples = [r for r in rows if r['kind'] == 'sample']
        battles = [r for r in rows if r['kind'] == 'battle']
        assert [r['entry'] for r in entries] == list(range(1, len(entries) + 1))
        assert [r['entry'] for r in samples] == [r['entry'] for r in entries]
        assert [r['battle'] for r in battles] == list(range(1, len(battles) + 1))
        for entry, sample in zip(entries, samples):
            assert all(sample[k] == entry[k] for k in ('entry', 'zone', 'x', 'y', 'doors', 'maps'))
            # SDK JSON omits Lua nil for Continue/battle-return entries.
            # Only explicit true is a door; preserve agreement on both records.
            assert entry.get('door', False) is sample.get('door', False)
            assert type(entry.get('door', False)) is bool
            assert 0 <= sample['after_kib'] <= 6144 and 0 <= sample['before_kib'] < 9216
        doors = sum(r.get('door', False) is True for r in entries)
        maps = {r['zone'] for r in entries}
        itinerary = json.loads((PACKET / 'route.json').read_text())
        assert {row['id'] for row in itinerary['maps'].values()} <= maps, 'fixed itinerary incomplete'
        assert 110 <= doors <= 160 and len(maps) >= 30 and 20 <= len(battles) <= 48
        finish = json.loads((run / 'long-traversal-finish.json').read_text())
        assert finish['long_traversal']['doors'] == doors
        assert finish['long_traversal']['battles'] == len(battles)
        assert finish['long_traversal']['maps'] == len(maps)
        assert finish['loaded'] == 1 and finish['saved'] == 0
        responses = json.loads((run / 'device-responses.json').read_text())
        assert all(r['build'] == build['build_id'] and r['status'] != 'error' for r in responses)
        assert all(r.get('value', {}).get('saved', 0) == 0 for r in responses if isinstance(r.get('value'), dict))
        earned = json.loads((args.stage / 'earned-save.json').read_text())
        for row in earned['files']:
            assert hashlib.sha256((data / row['file']).read_bytes()).hexdigest() == row['sha256'], 'private Data slot changed'
            assert hashlib.sha256((Path(earned['directory']) / row['file']).read_bytes()).hexdigest() == row['sha256'], 'private immutable seed changed'
        before = json.loads((run / 'before/logs.json').read_text())
        after = json.loads((run / 'after/logs.json').read_text())
        for name, record in after.items():
            if name.endswith(('errorlog.txt', 'crashlog.txt')) and record != before.get(name):
                assert 'sha256' not in record or (run / 'after' / name).stat().st_size == 0, name
        assert json.loads((run / 'outcome.json').read_text())['ok'] is True
        # Existing owner supplies raw peak, including GC updates, and trace errors.
        smoke = json.loads((run / 'device-smoke.json').read_text())
        assert smoke['measurements']['heap_peak_bytes'] <= 9 * 1024**2
    except (AssertionError, KeyError, ValueError, OSError, TypeError) as error:
        failures.append(str(error) or 'coverage/identity/memory assertion failed')
    result = {'classification': 'physical long traversal evidence; root review still required',
              'hardware_accepted': False, 'complete': not failures,
              'build_id': build['build_id'], 'pdx_sha256': build['pdx_sha256'],
              'actual_doors': sum(r.get('door', False) is True for r in entries),
              'distinct_maps': sorted({r['zone'] for r in entries}),
              'actual_battle_starts': len(battles), 'entry_samples': samples,
              'failures': failures,
              'limits': 'Lua samples exclude native allocations and unsampled peaks. No new native headroom proof.'}
    (run / 'long-traversal-summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in {'entry_samples', 'distinct_maps'}}, indent=2))
    return 0 if not failures else 1


if __name__ == '__main__':
    raise SystemExit(main())
