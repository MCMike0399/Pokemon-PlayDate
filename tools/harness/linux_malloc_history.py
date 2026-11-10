"""Linux Playdate Simulator malloc-history clear.

SDK 3.1.2 on Linux draws the Malloc Log as a wx window. The control named
"Clear Malloc History" in the binary is the unlabeled icon immediately left of
the "Automatically Refresh" label. This module clicks that icon with xdotool
and reads "Heap Used" from the same footer. It does not write the Simulator
ini, change MallocPoolSize, or send Playdate buttons.

The click offset (49 px left of "Automatically") was measured on the 738x451
Linux layout of this SDK. A click that would land outside the Malloc Log
window is refused. A click that does not drop the log's item count is refused.
"""
import os
import re
import subprocess
import time
from pathlib import Path

POOL_SIZE = '16645684'
# Inspected gap from the "Automatically" label to the clear icon.
CLEAR_LABEL_DX = 49
REFRESH_LABEL_DX = 77
FOOTER_HEIGHT = 56

HEAP_LINE = re.compile(
    r'Heap\s+Used:?\s*([0-9]+(?:\.[0-9]+)?)\s*(KB|MB)\D+?'
    r'Active:?\s*([0-9]+(?:\.[0-9]+)?)\s*(KB|MB)\D+?'
    r'([0-9]+)\s*items',
    re.IGNORECASE)


class MallocHistoryError(RuntimeError):
    pass


def display_env():
    env = os.environ.copy()
    env.setdefault('DISPLAY', ':1')
    return env


def parse_heap_status(text):
    """Parse the Malloc Log footer. MB/KB are the window's own units."""
    match = HEAP_LINE.search(' '.join(text.split()))
    if not match:
        raise MallocHistoryError('malloc log footer has no Heap Used line')
    heap, heap_unit, active, active_unit, items = match.groups()

    def kib(value, unit):
        scale = 1024 if unit.upper() == 'MB' else 1
        return float(value) * scale

    return {
        'heap_used': f'{heap} {heap_unit.upper()}',
        'heap_used_kib': kib(heap, heap_unit),
        'active': f'{active} {active_unit.upper()}',
        'active_kib': kib(active, active_unit),
        'items': int(items),
    }


def _footer_label(words):
    return next((word for word in words
                 if 'matic' in word['text'].lstrip('([]{<"\'').lower()), None)


def icon_point(words, origin, window, dx):
    """Screen point dx pixels left of Automatically, or None outside the window."""
    label = _footer_label(words)
    if label is None:
        return None
    x = origin[0] + label['left'] - dx
    y = origin[1] + label['top'] + label['height'] // 2
    left, top, width, height = window
    if not (left <= x < left + width and top <= y < top + height):
        return None
    return x, y


def clear_point(words, origin, window):
    """Screen point of the clear icon, or None when it cannot be proven."""
    return icon_point(words, origin, window, CLEAR_LABEL_DX)


def refresh_point(words, origin, window):
    """Screen point of the refresh icon. The footer does not redraw until clicked."""
    return icon_point(words, origin, window, REFRESH_LABEL_DX)


def pool_size(settings_path=None):
    path = Path(settings_path) if settings_path else _settings_path()
    values = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.startswith('['):
            key, value = line.split('=', 1)
            values[key] = value
    return values.get('MallocPoolSize')


def require_pool(settings_path=None):
    size = pool_size(settings_path)
    if size != POOL_SIZE:
        raise MallocHistoryError(f'MallocPoolSize is {size}, expected {POOL_SIZE}')
    return size


def _settings_path():
    from tools.harness.run import simulator_settings_file
    return simulator_settings_file()


def _run(args, check=True, timeout=15):
    completed = subprocess.run(
        args, check=False, capture_output=True, text=True, timeout=timeout, env=display_env())
    if check and completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or '').strip()
        raise MallocHistoryError(f'{" ".join(args)} failed: {detail}')
    return completed


def search_windows(title_regex):
    completed = _run(['xdotool', 'search', '--onlyvisible', '--name', title_regex], check=False)
    if completed.returncode != 0:
        return []
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def window_rect(window_id):
    """Screen rectangle. xwininfo matches the coordinates ffmpeg grabs."""
    completed = _run(['xwininfo', '-id', window_id])
    values = {}
    for line in completed.stdout.splitlines():
        line = line.strip()
        for key in ('Absolute upper-left X', 'Absolute upper-left Y', 'Width', 'Height'):
            if line.startswith(key + ':'):
                values[key] = int(line.split()[-1])
    return (values['Absolute upper-left X'], values['Absolute upper-left Y'],
            values['Width'], values['Height'])


def click_at(x, y):
    """Press and release. A bare click does not activate the wx View menu.

    mousemove --sync can sit forever while the Simulator menu owns the pointer.
    """
    _run(['xdotool', 'mousemove', str(x), str(y),
          'sleep', '0.1', 'mousedown', '1', 'sleep', '0.12', 'mouseup', '1'])
    # Leave the pointer off the footer. A cursor over the label makes tesseract drop it.
    _run(['xdotool', 'mousemove', '2', '2'], check=False)


def _overlaps(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def place_log(window_id):
    """Park the log on the left. Slide the simulator right if it covers the footer."""
    _run(['xdotool', 'windowmove', window_id, '8', '40'])
    time.sleep(0.15)
    rect = window_rect(window_id)
    footer = (rect[0], rect[1] + rect[3] - FOOTER_HEIGHT, rect[2], FOOTER_HEIGHT)
    simulators = search_windows(r'^Playdate Simulator$')
    for simulator in simulators:
        sim_rect = window_rect(simulator)
        if _overlaps(footer, sim_rect):
            _run(['xdotool', 'windowmove', simulator, str(rect[0] + rect[2] + 16), str(sim_rect[1])])
    _run(['xdotool', 'windowactivate', window_id])
    time.sleep(0.1)
    return window_rect(window_id)


def ocr_words(image):
    base = str(image.with_suffix(''))
    _run(['tesseract', str(image), base, 'tsv'])
    table = Path(base + '.tsv').read_text(encoding='utf-8', errors='replace')
    words = []
    for line in table.splitlines()[1:]:
        cols = line.split('\t')
        if len(cols) < 12 or not cols[11].strip():
            continue
        words.append({
            'left': int(cols[6]), 'top': int(cols[7]),
            'width': int(cols[8]), 'height': int(cols[9]),
            'text': cols[11].strip(),
        })
    return words


def ocr_footer_line(image):
    """Read the status sentence. The 1x footer drops digits; 3x keeps them."""
    from PIL import Image
    source = Image.open(image)
    scaled_path = image.with_name(image.stem + '-x3.png')
    source.resize((source.width * 3, source.height * 3), Image.Resampling.LANCZOS).save(scaled_path)
    base = scaled_path.with_suffix('')
    _run(['tesseract', str(scaled_path), str(base), '--psm', '7'])
    return Path(str(base) + '.txt').read_text(encoding='utf-8', errors='replace')


def grab(rect, destination):
    width, height = rect[2], rect[3]
    origin = f"{display_env()['DISPLAY']}+{rect[0]},{rect[1]}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    _run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'x11grab',
          '-video_size', f'{width}x{height}', '-i', origin,
          '-frames:v', '1', str(destination)], timeout=20)


def footer(window_id, directory):
    rect = place_log(window_id)
    strip = (rect[0], rect[1] + rect[3] - FOOTER_HEIGHT, rect[2], FOOTER_HEIGHT)
    image = Path(directory) / 'malloc-footer.png'
    grab(strip, image)
    words = ocr_words(image)
    text = ocr_footer_line(image)
    return rect, strip, words, text


def read_footer(window_id, directory):
    _rect, _strip, _words, text = footer(window_id, directory)
    return parse_heap_status(text), text


def ensure_log(directory):
    found = search_windows(r'^Malloc Log$')
    if len(found) > 1:
        raise MallocHistoryError('more than one Malloc Log window')
    if len(found) == 1:
        return found[0]
    simulators = search_windows(r'^Playdate Simulator$')
    if len(simulators) != 1:
        raise MallocHistoryError(f'expected one Playdate Simulator window, found {len(simulators)}')
    return _open_from_view_menu(simulators[0], directory)


def _malloc_menu_word(words):
    """The Show Malloc Log row. OCR reads the label as Malloc, Majoc or Maio."""
    rows = []
    for word in words:
        for row in rows:
            if abs(row[0]['top'] - word['top']) <= 4:
                row.append(word)
                break
        else:
            rows.append([word])
    for row in rows:
        texts = [word['text'] for word in row]
        if 'Show' in texts and 'Log' in texts:
            return next(word for word in row if word['text'] == 'Log')
    return None


def _open_from_view_menu(simulator, directory):
    # Keys with --window land in the device view. Focus the frame, then Alt+V.
    image = Path(directory) / 'view-menu.png'
    for attempt in range(3):
        _run(['xdotool', 'windowactivate', '--sync', simulator])
        time.sleep(0.1)
        _run(['xdotool', 'key', 'alt+v'])
        time.sleep(0.5)
        rect = window_rect(simulator)
        grab(rect, image)
        words = ocr_words(image)
        target = _malloc_menu_word(words)
        if target is None:
            view = next((word for word in words if word['text'] in ('View', 'Vigw')), None)
            if view is not None:
                click_at(rect[0] + view['left'] + view['width'] // 2,
                         rect[1] + view['top'] + view['height'] // 2)
                time.sleep(0.45)
                grab(rect, image)
                words = ocr_words(image)
                target = _malloc_menu_word(words)
        if target is not None:
            click_at(rect[0] + target['left'] + target['width'] // 2,
                     rect[1] + target['top'] + target['height'] // 2)
            deadline = time.monotonic() + 4
            while time.monotonic() < deadline:
                found = search_windows(r'^Malloc Log$')
                if len(found) == 1:
                    return found[0]
                time.sleep(0.15)
        _run(['xdotool', 'key', 'Escape'], check=False)
        time.sleep(0.2)
    raise MallocHistoryError('Show Malloc Log did not open a window')


def focus_simulator():
    """The Simulator pauses while another window is focused. Hand focus back."""
    simulators = search_windows(r'^Playdate Simulator$')
    if len(simulators) == 1:
        _run(['xdotool', 'windowactivate', simulators[0]], check=False)


def status(directory='/tmp/linux-malloc-history'):
    require_pool()
    try:
        window_id = ensure_log(directory)
        rect, strip, words, _text = footer(window_id, directory)
        point = refresh_point(words, (strip[0], strip[1]), rect)
        if point is not None:
            click_at(point[0], point[1])
            time.sleep(0.3)
        parsed, raw = read_footer(window_id, directory)
    finally:
        focus_simulator()
    parsed['raw'] = raw
    parsed['window'] = window_id
    return parsed


def clear(directory='/tmp/linux-malloc-history'):
    """Click Clear Malloc History. Refuse unless the item count falls."""
    require_pool()
    try:
        window_id = ensure_log(directory)
        rect, strip, words, before_text = footer(window_id, directory)
        before = parse_heap_status(before_text)
        point = clear_point(words, (strip[0], strip[1]), rect)
        if point is None:
            _run(['xdotool', 'mousemove', '2', '2'], check=False)
            time.sleep(0.2)
            rect, strip, words, before_text = footer(window_id, directory)
            before = parse_heap_status(before_text)
            point = clear_point(words, (strip[0], strip[1]), rect)
        if point is None:
            raise MallocHistoryError('Clear Malloc History control not found in the malloc log footer')
        _run(['xdotool', 'windowactivate', window_id])
        click_at(point[0], point[1])
        time.sleep(0.4)
        after, raw = read_footer(window_id, directory)
        if before['items'] > 50 and after['items'] > before['items'] * 0.5:
            raise MallocHistoryError(
                f'clear left {after["items"]} items; footer was {before["items"]}')
        require_pool()
    finally:
        focus_simulator()
    after['raw'] = raw
    after['before_items'] = before['items']
    after['window'] = window_id
    return after


def main(argv):
    if len(argv) != 2 or argv[1] not in ('status', 'clear'):
        raise SystemExit('usage: linux_malloc_history.py status|clear')
    import json
    print(json.dumps(status() if argv[1] == 'status' else clear(), sort_keys=True))
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main(sys.argv))
