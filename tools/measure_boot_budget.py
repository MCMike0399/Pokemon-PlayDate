#!/usr/bin/env python3
"""Measure a boot trace and fail if it misses the title or exhausts the pool.

The Playdate pool stays 16645684 bytes. Sampled Lua heap is not the whole
pool: the 2026-11-12 stop recorded 13792 KiB and the next allocation still
failed. A trace passes only when the title is visible, initialize.ready is
reached, no error phase was recorded, and the sampled peak stays at or under
14000 KiB.
"""
import argparse
import sys
from pathlib import Path

POOL_BYTES = 16645684
LUA_PEAK_BUDGET_KIB = 14000


def parse_trace(text):
    rows = []
    for line in text.splitlines():
        parts = line.split('\t')
        if not parts or not parts[0].isdigit() or len(parts) < 7:
            continue
        rows.append({
            'sequence': int(parts[0]),
            'phase': parts[1],
            'clock_ms': int(parts[2]),
            'heap_kib': float(parts[5]),
            'peak_kib': float(parts[6]),
        })
    return rows


def step_rows(rows):
    """Named startup samples. Yield heartbeats stay out of the table, but their peak does not."""
    steps = []
    previous = None
    pending = []
    for row in rows:
        phase = row['phase']
        if phase == 'initialize.yield' or phase.startswith('error.alive'):
            pending.append(row)
            continue
        window_peak = max(item['heap_kib'] for item in pending + [row])
        delta = None if previous is None else row['heap_kib'] - previous
        steps.append({**row, 'delta_kib': delta, 'since_peak_kib': window_peak})
        previous = row['heap_kib']
        pending = []
    return steps


def evaluate(rows, peak_budget_kib=LUA_PEAK_BUDGET_KIB, pool_bytes=POOL_BYTES):
    if not rows:
        return ['boot trace has no samples']
    problems = []
    errors = [row for row in rows if row['phase'].startswith('error.') and not row['phase'].startswith('error.alive')]
    title = next((row for row in rows if row['phase'] == 'title.visible'), None)
    ready = next((row for row in rows if row['phase'] == 'initialize.ready'), None)
    peak = max(row['peak_kib'] for row in rows)
    if title is None:
        problems.append('title never became visible')
    if errors:
        problems.append('boot stopped: ' + errors[0]['phase'])
    if title is not None and errors and errors[0]['sequence'] < title['sequence']:
        problems.append('error was recorded before the title')
    if ready is None:
        problems.append('boot did not reach initialize.ready')
    elif title is not None and ready['sequence'] < title['sequence']:
        problems.append('initialize.ready was recorded before the title')
    if peak > peak_budget_kib:
        problems.append(f'lua peak {peak:.3f} KiB exceeds budget {peak_budget_kib} KiB')
    if peak * 1024 > pool_bytes:
        problems.append(f'lua peak exceeds the {pool_bytes} byte pool')
    return problems


def format_report(rows):
    lines = ['sequence\tclock_ms\theap_kib\tdelta_kib\tsince_peak_kib\tphase']
    for row in step_rows(rows):
        delta = '' if row['delta_kib'] is None else f'{row["delta_kib"]:.1f}'
        lines.append(
            f'{row["sequence"]}\t{row["clock_ms"]}\t{row["heap_kib"]:.1f}\t{delta}\t{row["since_peak_kib"]:.1f}\t{row["phase"]}')
    if rows:
        lines.append(f'peak\t{max(row["peak_kib"] for row in rows):.3f}')
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace', type=Path)
    parser.add_argument('--peak-kib', type=float, default=LUA_PEAK_BUDGET_KIB)
    args = parser.parse_args(argv)
    rows = parse_trace(args.trace.read_text())
    problems = evaluate(rows, peak_budget_kib=args.peak_kib)
    print(format_report(rows))
    if problems:
        for problem in problems:
            print('BUDGET FAIL:', problem)
        return 1
    print('BUDGET PASS: title visible, initialize.ready, peak within', args.peak_kib, 'KiB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
