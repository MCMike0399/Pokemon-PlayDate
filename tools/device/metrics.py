"""Read-only phase attribution shared by device and Simulator reports."""
import math


def spans(phases, begin, end):
    start, result = None, []
    for row in phases:
        if row['phase'] == begin:
            start = row['clock_ms']
        elif row['phase'] == end and start is not None:
            result.append((start, row['clock_ms']))
            start = None
    return result


def gc_windows(phases):
    result = []
    prefixes = {row['phase'][:-10] for row in phases if row['phase'].endswith('.before_gc')}
    for prefix in sorted(prefixes):
        result.extend(dict(phase=prefix, start_ms=a, end_ms=b, wall_ms=b-a)
                      for a, b in spans(phases, prefix + '.before_gc', prefix + '.after_gc'))
    for window in result:
        end = next(r for r in phases if r['clock_ms'] == window['end_ms']
                   and r['phase'] == window['phase'] + '.after_gc')
        window['raw_phase_ms'] = end.get('phase_ms')
    result.sort(key=lambda w: w['start_ms'])
    return result


def overlaps(frame, windows):
    start = frame.get('start_ms')
    return start is not None and any(start <= w['end_ms'] and
        start + frame['active_ms'] >= w['start_ms'] for w in windows)


def ordinary_frames(frames, phases):
    # Exclude the entire update, including segments beside the forced collection.
    windows = gc_windows(phases)
    updates = {f['update'] for f in frames if overlaps(f, windows)}
    return [f for f in frames if not f['loading'] and f['update'] not in updates]


def percentile95(values):
    return sorted(values)[math.ceil(.95 * len(values)) - 1] if values else None


def interval(name, begin, end, frames, windows, boundary):
    timed = all(f.get('start_ms') is not None for f in frames) and bool(frames)
    # Union prevents overlapping segments/GC marks from being counted twice.
    def covered(intervals):
        total, last = 0, begin
        for a, b in sorted(intervals):
            a, b = max(a, begin, last), min(b, end)
            if b > a:
                total += b-a
                last = b
        return total
    active = covered((f['start_ms'], f['start_ms'] + f['active_ms']) for f in frames) if timed else None
    gc = covered((w['start_ms'], w['end_ms']) for w in windows)
    return dict(phase=name, boundary=boundary, start_ms=begin, end_ms=end,
                wall_ms=end-begin, measured_active_ms=active,
                residual_wall_ms=end-begin-active if active is not None else None,
                diagnostic_gc_wall_ms=gc,
                diagnostic_gc_raw_phase_ms=sum(w['raw_phase_ms'] for w in windows
                    if begin <= w['start_ms'] and w['end_ms'] <= end
                    and w.get('raw_phase_ms') is not None))


def walking(frames, responses, phases):
    """Scripted press + wait moving-to-settled windows, never physical player FPS."""
    done = {r.get('seq'): r for r in responses if r.get('status') == 'done'}
    accepted = {r.get('seq'): r for r in responses if r.get('status') == 'accepted'}
    ordinary = ordinary_frames(frames, phases)
    result = []
    for seq, press in sorted(accepted.items()):
        if press.get('value') != 'press' or seq not in done:
            continue
        moving = done[seq].get('value', {})
        zone = moving.get('zone')
        if zone not in {'pokered:ROUTE_2', 'pokered:DIGLETTS_CAVE'} or moving.get('state') != 'overworld' or moving.get('overworld') != 'explore' or moving.get('player', {}).get('moving') is not True:
            continue
        wait, settled = accepted.get(seq+1, {}), done.get(seq+1, {})
        state = settled.get('value', {})
        if wait.get('value') != 'wait' or state.get('zone') != zone or state.get('state') != 'overworld' or state.get('overworld') != 'explore' or state.get('player', {}).get('moving') is not False:
            continue
        if type(press.get('tick')) is not int or type(settled.get('tick')) is not int:
            continue
        first, last = press['tick']+2, settled['tick']+1
        starts = {f['update']: f['start_ms'] for f in ordinary
                  if f.get('start_ms') is not None and f['segment'] == 1}
        periods = [starts[u+1]-starts[u] for u in range(first, last+1)
                   if u in starts and u+1 in starts]
        result.append(dict(zone=zone, press_seq=seq, wait_seq=seq+1,
                           first_update=first, last_update=last,
                           update_intervals_ms=periods,
                           p95_ms=percentile95(periods)))
    return result


def phase_report(phases, frames, responses):
    windows = gc_windows(phases)
    table = []
    definitions = [('boot_title', 'boot.begin', 'title.start.end'),
                   ('Continue', 'Continue.begin', 'Continue.end'),
                   ('Save', 'Save.begin', 'Save.publish.end'),
                   ('door', 'door.map.begin', 'door.map.end'),
                   ('battle', 'battle.start.begin', 'battle.start.end')]
    for name, begin, end in definitions:
        for a, b in spans(phases, begin, end):
            table.append(interval(name, a, b, frames, windows, begin + ' -> ' + end))
    # Reviewer boot endpoint includes checkpoint/trace work before the forced GC.
    for a, b in spans(phases, 'boot.begin', 'title.live.before_gc'):
        table.append(interval('boot_before_diagnostic_gc', a, b, frames, windows,
                              'boot.begin -> title.live.before_gc (reviewer endpoint)'))
    for w in windows:
        table.append(interval('diagnostic_gc.' + w['phase'], w['start_ms'], w['end_ms'],
                              frames, windows, w['phase'] + '.before_gc -> .after_gc'))
    walk = walking(frames, responses, phases)
    for a, b in spans(phases, 'boot.begin', 'Continue.end'):
        table.append(interval('boot_to_walk_ready', a, b, frames, windows,
            'boot.begin -> Continue.end; app-clock readiness proxy, includes title input wait; physical power-on unmeasured'))
    boot = next((r['clock_ms'] for r in phases if r['phase'] == 'boot.begin'), None)
    first_walk = next((w for w in walk if w['update_intervals_ms']), None)
    if boot is not None and first_walk:
        end = next((f['start_ms'] for f in frames if f['update'] == first_walk['first_update']), None)
        if end is not None:
            table.append(interval('power_on_to_walking', boot, end, frames, windows,
                'boot.begin -> first accepted scripted walking update; app clock, excludes OS/power-on before boot.begin; includes title input wait'))
    for zone in ('pokered:ROUTE_2', 'pokered:DIGLETTS_CAVE'):
        selected = [w for w in walk if w['zone'] == zone]
        updates = {u for w in selected for u in range(w['first_update'], w['last_update']+1)}
        starts = {f['update']: f['start_ms'] for f in ordinary_frames(frames, phases)
                  if f['segment'] == 1 and f.get('start_ms') is not None}
        pieces = [interval(zone, starts[u], starts[u+1], frames, windows, '')
                  for u in sorted(updates) if u in starts and u+1 in starts]
        if pieces:
            table.append(dict(phase='walking.' + zone,
                boundary='union of scripted settled press/wait windows; wrapper update=tick+1, sampled accepted.tick+2..wait.done.tick+1',
                start_ms=pieces[0]['start_ms'], end_ms=pieces[-1]['end_ms'],
                **{key: sum(p[key] for p in pieces) for key in
                   ('wall_ms', 'measured_active_ms', 'residual_wall_ms', 'diagnostic_gc_wall_ms', 'diagnostic_gc_raw_phase_ms')},
                p95_ms=percentile95([p['wall_ms'] for p in pieces]), samples=len(pieces)))
    values = {name: max((r['wall_ms'] for r in table if r['phase'] == name), default=None)
              for name, _, _ in definitions}
    boot_end = next((r['end_ms'] for r in table if r['phase'] == 'boot_title'), None)
    values['boot_slice'] = max([r['since_yield_ms'] for r in phases if boot_end is not None and r['clock_ms'] <= boot_end] +
                              [f['active_ms'] for f in frames if f.get('start_ms') is not None and boot_end is not None and f['start_ms'] <= boot_end], default=None)
    values['cave_walking_p95'] = next((r['p95_ms'] for r in table
        if r['phase'] == 'walking.pokered:DIGLETTS_CAVE'), None)
    limits = dict(boot_title=10000, boot_slice=1000, Continue=4000, Save=2000, door=1500, battle=1000, cave_walking_p95=50)
    failures = [name for name, limit in limits.items() if values[name] is None or values[name] > limit]
    if not any(r['phase'] == 'power_on_to_walking' for r in table):
        failures.append('missing-power-on-to-walking-app-clock-proxy')
    return dict(phase_table=table, phase_measurements=values, phase_limits=limits,
                phase_failures=failures, diagnostic_gc_windows=windows,
                walking_windows=walk, walking_basis='scripted settled windows; nearest-rank p95 of consecutive wrapper update starts; not physical player FPS',
                timing_basis='Measured active elapsed and residual wall time, not pure CPU. Residual includes waits, pacing and uninstrumented/observer work. Raw frames and diagnostic full-GC windows retained. Native memory and unsampled peaks unmeasured.')


def phase_table_text(report):
    lines = ['| Phase / explicit boundary | Wall ms | Measured active ms | Residual wall ms | Diagnostic GC wall ms | Raw GC phase ms | p95 ms / samples |',
             '| --- | ---: | ---: | ---: | ---: | ---: | ---: |']
    for row in report.get('phase_table', []):
        def number(key):
            value = row[key]
            return 'unmeasured' if value is None else f'{value:.2f}'
        lines.append(f"| {row['phase']}: {row['boundary']} | " + ' | '.join(number(k) for k in
            ('wall_ms', 'measured_active_ms', 'residual_wall_ms', 'diagnostic_gc_wall_ms', 'diagnostic_gc_raw_phase_ms')) +
            (f" | {row['p95_ms']:.2f} / {row['samples']} |" if 'p95_ms' in row else ' | — |'))
    if not report.get('phase_table'):
        lines.append('| Required phases missing | unmeasured | unmeasured | unmeasured | unmeasured | unmeasured | — |')
    lines.append('\n' + report.get('timing_basis', 'No valid timing evidence.'))
    lines.append('Failures: ' + ', '.join(report.get('failures', report.get('phase_failures', []))))
    return '\n'.join(lines) + '\n'
