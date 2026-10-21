#!/usr/bin/env python3
"""Read completed profile evidence; never launch or contact a Simulator."""
import argparse
import hashlib
import json
from pathlib import Path


def analyze(report_path):
    report_path = Path(report_path)
    raw = report_path.read_bytes()
    report = json.loads(raw)
    samples = report['world_profile']['samples']
    endpoints = [row for row in samples if row['label'].startswith('cycle-') and row['label'].endswith('-retained:post-gc')]
    deltas = [b['lua_heap_kib'] - a['lua_heap_kib'] for a, b in zip(endpoints, endpoints[1:])]
    requests = [json.loads(path.read_text(encoding='utf-8')) for path in sorted(report_path.parent.glob('*-request.json'))]
    identifiers = {request['id'] for request in requests}
    initial = next((row for row in samples if row['label'] == 'initial-fixture:post-gc'), None)
    return {
        'scope': 'offline completed evidence; no native allocation attribution',
        'source_report_sha256': hashlib.sha256(raw).hexdigest(),
        'build_id': report['build_id'],
        'retained_cycle_endpoints': [{key: row[key] for key in ('label', 'lua_heap_kib', 'observer_rows')} for row in endpoints],
        'steady_cycle_delta_kib': deltas,
        'mean_delta_kib': sum(deltas) / len(deltas) if deltas else None,
        'first_cycle_cold_delta_kib': endpoints[0]['lua_heap_kib'] - initial['lua_heap_kib'] if endpoints and initial else None,
        'observer_inventory': {
            'retained_row_tables': len(samples),
            'retained_row_field_slots': sum(len(row) for row in samples),
            'history_array_slots': len(samples),
            'compact_json_payload_bytes': len(json.dumps(samples, separators=(',', ':'), ensure_ascii=False).encode('utf-8')),
            'rows_between_cycle_endpoints': [b['observer_rows'] - a['observer_rows'] for a, b in zip(endpoints, endpoints[1:])],
            'meaning': 'logical ownership/payload counts, NOT Lua allocation sizes',
        },
        'harness_inventory': {
            'published_requests': len(requests),
            'unique_request_ids': len(identifiers),
            'seen_id_string_payload_bytes': sum(len(value.encode('utf-8')) for value in identifiers),
            'meaning': 'runtime replay-ID retention; excludes table/header/interning overhead',
        },
        'simulator_flag_caveat': 'Original native01 rows used ==true incorrectly for SDK numeric1; original evidence remains unchanged. Future observer uses boolean coercion plus type.',
        'conclusion': 'Combined instrumented retained growth includes observer and harness ownership; no game leak or native heap capacity claim.',
        'future_controls': ['matched no-transition request/capture control', 'explicit observer release/GC or fixed-size history', 'Simulator native allocator observation'],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    text = json.dumps(analyze(args.report), indent=2, ensure_ascii=False) + '\n'
    if args.output:
        if args.output.exists():
            parser.error('refusing to overwrite analysis output')
        if args.output.resolve() == args.report.resolve():
            parser.error('analysis must not replace source evidence')
        args.output.write_text(text, encoding='utf-8')
    else:
        print(text, end='')


if __name__ == '__main__':
    main()
