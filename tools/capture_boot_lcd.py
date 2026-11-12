#!/usr/bin/env python3
"""Record the LCD from the simulator window until initialize.ready.

A fixed 22s grab ended while the title was still on "Preparing adventure...".
This waits for initialize.ready, holds the menu, and exits with a failure if
ready does not arrive before the timeout.
"""

import argparse
import hashlib
import os
import shutil
import signal
import subprocess
import time
from pathlib import Path

READY_TIMEOUT_S = 90
MENU_HOLD_S = 2.0
LCD_WIDTH = 400
LCD_HEIGHT = 240
WINDOW_WIDTH = 486
WINDOW_HEIGHT = 700
LCD_OFFSET_X = 18
LCD_OFFSET_Y = 45


class BootCaptureFailure(RuntimeError):
    """The boot did not reach the title menu inside the capture window."""


def boot_marks(text):
    title = ready = None
    error = None
    last = None
    for line in text.splitlines():
        parts = line.split('\t')
        if len(parts) < 3 or not parts[0].isdigit():
            continue
        phase = parts[1]
        clock = int(parts[2])
        last = phase
        if phase == 'title.visible':
            title = clock
        elif phase == 'initialize.ready':
            ready = clock
        elif phase.startswith('error.'):
            error = phase
    return {
        'title_visible_ms': title,
        'initialize_ready_ms': ready,
        'error': error,
        'last_phase': last,
    }


def wait_for_ready(trace_path, timeout_s, clock, sleep, tick=None):
    """Block until the trace records initialize.ready, or fail closed."""
    started = clock()
    while True:
        if tick is not None:
            tick()
        text = ''
        if trace_path.exists():
            text = trace_path.read_text(encoding='utf-8', errors='replace')
        marks = boot_marks(text)
        if marks['error']:
            raise BootCaptureFailure(f"boot capture failed: {marks['error']}")
        if marks['initialize_ready_ms'] is not None:
            return marks
        if clock() - started >= timeout_s:
            last = marks['last_phase'] or 'no trace'
            raise BootCaptureFailure(
                'boot capture failed: initialize.ready did not arrive within '
                f'{timeout_s:.0f}s ({last})'
            )
        sleep(0.2)


def _run(command, **kwargs):
    completed = subprocess.run(command, check=False, text=True, capture_output=True, **kwargs)
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or '').strip()
        raise BootCaptureFailure(f"{command[0]} failed: {detail}")
    return completed.stdout


def _window_geometry(window_id):
    text = _run(['xwininfo', '-id', window_id])
    values = {}
    for line in text.splitlines():
        if 'Absolute upper-left X' in line:
            values['x'] = int(line.split()[-1])
        elif 'Absolute upper-left Y' in line:
            values['y'] = int(line.split()[-1])
        elif 'Width:' in line:
            values['width'] = int(line.split()[-1])
        elif 'Height:' in line:
            values['height'] = int(line.split()[-1])
    if set(values) != {'x', 'y', 'width', 'height'}:
        raise BootCaptureFailure('xwininfo did not report the simulator window')
    return values


def _unique_colors(path):
    from PIL import Image
    found = Image.open(path).convert('RGB').getcolors(maxcolors=20000)
    if found is None:
        return None
    return len(found)


def _stop_ffmpeg(process):
    if process.poll() is not None:
        return
    process.send_signal(signal.SIGINT)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def capture(project, output_dir, destination, note_path, ready_timeout):
    output_dir = Path(output_dir)
    destination = Path(destination)
    note_path = Path(note_path)
    if output_dir.exists():
        raise BootCaptureFailure(f'boot output already exists: {output_dir}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    trace_path = output_dir / 'runtime-data' / 'boot-trace.tsv'
    log_path = output_dir.with_suffix('.log')
    raw_path = destination.with_suffix('.raw.mp4')
    env = os.environ.copy()
    env['DISPLAY'] = env.get('DISPLAY') or ':1'
    harness = subprocess.Popen(
        ['python3', 'tools/harness/run.py', '--output', str(output_dir),
         '--ready-timeout', str(ready_timeout), '--timeout', str(ready_timeout), 'gamestate'],
        cwd=project, env=env, stdout=log_path.open('w'), stderr=subprocess.STDOUT,
    )
    window_id = None
    try:
        for _ in range(240):
            if harness.poll() is not None:
                raise BootCaptureFailure(f'harness exited {harness.returncode} before the simulator window opened')
            found = subprocess.run(
                ['xdotool', 'search', '--onlyvisible', '--name', '^Playdate Simulator$'],
                check=False, text=True, capture_output=True,
            )
            if found.returncode not in (0, 1):
                raise BootCaptureFailure(found.stderr.strip() or 'xdotool search failed')
            window_id = next((line.strip() for line in found.stdout.splitlines() if line.strip()), None)
            if window_id:
                break
            time.sleep(0.25)
        if not window_id:
            raise BootCaptureFailure('boot capture failed: Playdate Simulator window did not open')
        _run(['xdotool', 'windowmove', window_id, '718', '292'])
        _run(['xdotool', 'mousemove', '2', '2'])
        time.sleep(0.15)
        geometry = _window_geometry(window_id)
        if (geometry['width'], geometry['height']) != (WINDOW_WIDTH, WINDOW_HEIGHT):
            raise BootCaptureFailure(
                f"unexpected simulator window {geometry['width']}x{geometry['height']}"
            )
        origin_x = geometry['x'] + LCD_OFFSET_X
        origin_y = geometry['y'] + LCD_OFFSET_Y

        def pin():
            if harness.poll() is not None and not trace_path.exists():
                raise BootCaptureFailure(f'harness exited {harness.returncode} before initialize.ready')
            subprocess.run(['xdotool', 'windowmove', window_id, '718', '292'], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(['xdotool', 'mousemove', '2', '2'], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        ffmpeg = subprocess.Popen(
            ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'x11grab',
             '-video_size', f'{LCD_WIDTH}x{LCD_HEIGHT}', '-framerate', '30',
             '-i', f"{env['DISPLAY']}.0+{origin_x},{origin_y}",
             '-t', str(int(ready_timeout + MENU_HOLD_S + 2)), '-an', str(raw_path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            marks = wait_for_ready(trace_path, ready_timeout, time.monotonic, time.sleep, pin)
            # The harness closes the simulator soon after ready. Keep pinning
            # only while that window is still the LCD, then trim any desktop tail.
            hold_deadline = time.monotonic() + MENU_HOLD_S
            while time.monotonic() < hold_deadline:
                still = subprocess.run(
                    ['xdotool', 'search', '--onlyvisible', '--name', '^Playdate Simulator$'],
                    check=False, text=True, capture_output=True,
                )
                if window_id not in still.stdout.split():
                    break
                pin()
                time.sleep(0.1)
        finally:
            _stop_ffmpeg(ffmpeg)
        if not raw_path.exists() or raw_path.stat().st_size == 0:
            raise BootCaptureFailure('boot capture failed: ffmpeg wrote no frames')
        duration = float(_run([
            'ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(raw_path),
        ]).strip())
        sample_dir = raw_path.with_suffix('')
        sample_dir.mkdir(parents=True, exist_ok=True)
        samples = []
        cursor = 0.0
        while cursor < duration:
            png = sample_dir / f'{cursor:.2f}.png'
            completed = subprocess.run(
                ['ffmpeg', '-y', '-loglevel', 'error', '-ss', f'{cursor:.3f}', '-i', str(raw_path),
                 '-frames:v', '1', str(png)],
                check=False, capture_output=True,
            )
            if completed.returncode == 0 and png.exists():
                samples.append((cursor, _unique_colors(png), png))
            cursor += 0.1
        lcd = [(stamp, colors, png) for stamp, colors, png in samples if colors is not None and colors <= 400]
        if not lcd:
            raise BootCaptureFailure('boot capture failed: no LCD frame in the grab')
        drawn = [sample for sample in lcd if sample[1] > 1]
        if not drawn:
            raise BootCaptureFailure('boot capture failed: LCD never drew the title')
        start, end = drawn[0][0], drawn[-1][0]
        if end - start < 0.4:
            raise BootCaptureFailure('boot capture failed: LCD was on screen for less than half a second')
        destination.parent.mkdir(parents=True, exist_ok=True)
        length = max(0.3, (end + 0.15) - start)
        _run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', f'{start:.3f}', '-i', str(raw_path),
              '-t', f'{length:.3f}', '-an', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', str(destination)])
        first = sample_dir / 'first.png'
        last = sample_dir / 'last.png'
        drawn[0][2].replace(first)
        drawn[-1][2].replace(last)
        first_colors, last_colors = drawn[0][1], drawn[-1][1]
        if first_colors > 400 or last_colors > 400:
            destination.unlink(missing_ok=True)
            raise BootCaptureFailure(
                f'boot capture failed: frame left the LCD ({first_colors}, {last_colors} colors)'
            )
        shutil.rmtree(sample_dir, ignore_errors=True)
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        note_path.write_text(
            'Boot capture waited for initialize.ready.\n'
            f"title.visible_ms\t{marks['title_visible_ms']}\n"
            f"initialize.ready_ms\t{marks['initialize_ready_ms']}\n"
            f'clip\t{destination}\n'
            f'sha256\t{digest}\n'
            'menu\tNEW GAME / OPTIONS is the frame after initialize.ready\n',
            encoding='utf-8',
        )
        print(destination)
        print(note_path)
        return marks
    finally:
        if harness.poll() is None:
            try:
                harness.wait(timeout=ready_timeout)
            except subprocess.TimeoutExpired:
                harness.kill()
                harness.wait(timeout=5)
        raw_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--note', type=Path, required=True)
    parser.add_argument('--ready-timeout', type=float, default=READY_TIMEOUT_S)
    args = parser.parse_args()
    try:
        capture(args.project, args.output, args.destination, args.note, args.ready_timeout)
    except BootCaptureFailure as failure:
        print(failure)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
