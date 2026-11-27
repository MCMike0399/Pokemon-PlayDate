"""Production boot must stay under the 9 MiB guard through Oak's grass door.

Builds with the dev tree dropped, leaves the memory budget on, and walks
title -> Oak -> the grass north of Pallet with simulator button presses.
"""
import os
from pathlib import Path
import shutil
import subprocess
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
SDK = Path(os.environ.get("PLAYDATE_SDK_PATH", "/home/ubuntu/Developer/PlaydateSDK"))
SIMULATOR = SDK / "bin/PlaydateSimulator"
GUARD_KIB = 9 * 1024
POOL_LINE = "MallocPoolSize=16645684"
LOCK = Path("/tmp/pokemon-playdate-simulator-1000.lock")


def _ini_pool():
    path = Path.home() / ".config/Playdate Simulator/Playdate Simulator.ini"
    return path.read_text().splitlines()[0]


def _trace_rows(path):
    rows = []
    if not path.is_file():
        return rows
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split("\t")
        if len(parts) < 6 or not parts[0].isdigit():
            continue
        try:
            heap = float(parts[5])
        except ValueError:
            continue
        rows.append((parts[1], heap))
    return rows


def _windows(name):
    found = subprocess.run(
        ["xdotool", "search", "--name", name],
        capture_output=True, text=True,
    )
    return [line for line in found.stdout.splitlines() if line.strip()]


def _dismiss_heads_up():
    # The simulator pauses while a modal is up, and S would type into the
    # developer-list field. Close those before any game key.
    for name, key in (("Heads up!", "Return"), ("eList", "Escape"), ("Developer", "Escape")):
        for wid in _windows(name):
            subprocess.run(["xdotool", "windowactivate", "--sync", wid], check=False)
            subprocess.run(["xdotool", "key", key], check=False)
            time.sleep(0.25)


# Fractions of the simulator window, measured from the on-screen d-pad.
DPAD = {
    "Up": (0.194, 0.410),
    "Down": (0.194, 0.559),
    "Left": (0.099, 0.486),
    "Right": (0.300, 0.484),
}


def _key(window, name, gap=0.4):
    _dismiss_heads_up()
    subprocess.run(["xdotool", "windowactivate", "--sync", window], check=True)
    # Hold long enough for a slow frame to observe the edge. S is A, A is B.
    subprocess.run(["xdotool", "keydown", name], check=True)
    time.sleep(0.45)
    subprocess.run(["xdotool", "keyup", name], check=True)
    time.sleep(gap)


def _dialog_page(window):
    # The first A finishes a typewriter page. The page must sit for 10 frames
    # before a new A turns it.
    _key(window, "s", gap=0.45)
    _key(window, "s", gap=0.35)


class ProductionDoorBudgetTests(unittest.TestCase):
    def test_oak_grass_door_stays_under_the_guard(self):
        self.assertEqual(_ini_pool(), POOL_LINE)
        guard = (ROOT / "Source/game/bootTrace.lua").read_text()
        self.assertIn("if heap >= 9 * 1024 then", guard)
        if not SIMULATOR.is_file():
            self.skipTest("Playdate Simulator is not installed")
        stage = Path("/tmp/prod-door-budget")
        if stage.exists():
            shutil.rmtree(stage)
        source = stage / "Source"
        shutil.copytree(ROOT / "Source", source, ignore=shutil.ignore_patterns("dev"))
        info = (source / "pdxinfo").read_text().replace(
            "bundleID=com.poc.pokemon", "bundleID=com.poc.pokemon.doorbudget")
        (source / "pdxinfo").write_text(info)
        bundle = stage / "Game.pdx"
        subprocess.run(
            [str(SDK / "bin/pdc"), "-q", str(source), str(bundle)],
            check=True,
        )
        self.assertFalse((bundle / "dev").exists())
        data = SDK / "Disk/Data/com.poc.pokemon.doorbudget"
        if data.exists():
            shutil.rmtree(data)
        lock = LOCK.open("a+")
        import fcntl
        fcntl.flock(lock, fcntl.LOCK_EX)
        env = os.environ.copy()
        env["DISPLAY"] = ":1"
        proc = subprocess.Popen(
            [str(SIMULATOR), str(bundle)],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            self._walk(proc, data / "boot-trace.tsv")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
            fcntl.flock(lock, fcntl.LOCK_UN)
            lock.close()

    def _walk(self, proc, trace):
        deadline = time.time() + 20
        while time.time() < deadline and not trace.is_file():
            if proc.poll() is not None:
                self.fail("simulator exited before the boot trace")
            time.sleep(0.2)
        self.assertTrue(trace.is_file(), "production boot wrote no trace")
        window = self._window()
        self._skip_movie(window)  # main menu is open
        time.sleep(2.0)  # the menu ignores A for 20 frames
        _key(window, "s", gap=1.0)     # NEW GAME
        _key(window, "Down", gap=0.7)
        _key(window, "s", gap=1.6)     # YES, then Oak
        self._until(window, self._is_preset, 16, "player presets")
        self._choose_preset(window)
        self._until(window, self._is_preset, 16, "rival presets")
        self._choose_preset(window)
        self._until(window, self._is_overworld, 16, "bedroom")
        self._steps(window, "Right", 4)
        self._steps(window, "Up", 3)
        self._wait_door(trace, 1)
        self._steps(window, "Down", 1)
        self._steps_until_blocked(window, "Left")
        self._steps(window, "Right", 2)
        self._steps(window, "Down", 8)
        self._wait_door(trace, 2)
        self._steps(window, "Left", 3)
        self._steps(window, "Up", 6)
        for _ in range(16):
            if len(self._doors(trace)) >= 3:
                break
            _key(window, "s", gap=0.45)
        time.sleep(1.5)
        self._shot(window, "/tmp/door-budget-end.png")
        rows = _trace_rows(trace)
        text = trace.read_text(errors="replace")
        doors = [heap for phase, heap in rows if phase == "door.map.end"]
        self.assertNotIn("device-test memory guard", text)
        self.assertGreaterEqual(len(doors), 3, "walk did not reach the grass door")
        for heap in doors:
            self.assertLess(heap, GUARD_KIB, "door.map.end %.3f KiB" % heap)
        print("door.map.end KiB:", ", ".join("%.3f" % heap for heap in doors))

    def _doors(self, trace):
        return [heap for phase, heap in _trace_rows(trace) if phase == "door.map.end"]

    def _dark_fraction(self, window, box):
        from PIL import ImageGrab
        image = ImageGrab.grab(bbox=self._rect(window)).convert("L")
        width, height = image.size
        crop = image.crop((
            int(width * box[0]), int(height * box[1]),
            max(int(width * box[0]) + 1, int(width * box[2])),
            max(int(height * box[1]) + 1, int(height * box[3])),
        ))
        pixels = list(crop.get_flattened_data()) if hasattr(crop, "get_flattened_data") else list(crop.getdata())
        return sum(pixel < 100 for pixel in pixels) / len(pixels)

    def _is_preset(self, window):
        # The name list is a box in the LCD's top left. The right side of that
        # screen is empty. Oak's picture and the keyboard both ink the right side,
        # and Oak leaves the top-left corner empty.
        left = self._dark_fraction(window, (0.05, 0.08, 0.24, 0.42))
        right = self._dark_fraction(window, (0.58, 0.12, 0.78, 0.58))
        return left > 0.05 and right < 0.008

    def _is_overworld(self, window):
        # The bedroom floor is dithered. Speech and the name list stay mostly white.
        return self._dark_fraction(window, (0.08, 0.10, 0.80, 0.72)) > 0.18

    def _until(self, window, predicate, limit, what):
        for _ in range(limit):
            if predicate(window):
                return
            _key(window, "s", gap=0.35)
        self._shot(window, "/tmp/door-budget-stuck.png")
        left = self._dark_fraction(window, (0.05, 0.08, 0.24, 0.42))
        right = self._dark_fraction(window, (0.58, 0.12, 0.78, 0.58))
        whole = self._dark_fraction(window, (0.08, 0.10, 0.80, 0.72))
        self.fail("never saw %s (left %.3f right %.3f whole %.3f)" % (what, left, right, whole))

    def _choose_preset(self, window):
        box = (0.0, 0.02, 0.48, 0.62)
        before = self._sig(window, box)
        for _ in range(6):
            _key(window, "Down", gap=0.35)
            if self._sig(window, box) != before:
                _key(window, "s", gap=0.5)
                return
        self._shot(window, "/tmp/door-budget-stuck.png")
        self.fail("preset cursor did not move")

    def _step(self, window, key):
        before = self._sig(window, (0.0, 0.0, 1.0, 1.0))
        _dismiss_heads_up()
        subprocess.run(["xdotool", "windowactivate", "--sync", window], check=True)
        subprocess.run(["xdotool", "keydown", key], check=True)
        time.sleep(0.12)
        subprocess.run(["xdotool", "keyup", key], check=True)
        deadline = time.time() + 2.2
        while time.time() < deadline:
            time.sleep(0.15)
            if self._sig(window, (0.0, 0.0, 1.0, 1.0)) != before:
                time.sleep(0.25)
                return True
        return False

    def _steps(self, window, key, count):
        for _ in range(count):
            self._step(window, key)

    def _steps_until_blocked(self, window, key):
        for _ in range(12):
            if not self._step(window, key):
                return

    def _wait_door(self, trace, count):
        deadline = time.time() + 6
        while time.time() < deadline:
            if len(self._doors(trace)) >= count:
                time.sleep(1.2)
                return
            time.sleep(0.2)

    def _sig(self, window, box):
        from PIL import ImageGrab
        image = ImageGrab.grab(bbox=self._rect(window)).convert("L")
        width, height = image.size
        crop = image.crop((
            int(width * box[0]), int(height * box[1]),
            max(int(width * box[0]) + 1, int(width * box[2])),
            max(int(height * box[1]) + 1, int(height * box[3])),
        ))
        # Count dark pixels per cell. A full line of text sets every
        # any-dark bit, so the letters themselves have to change the count.
        pixels = crop.load()
        crop_w, crop_h = crop.size
        cols, rows = 32, 8
        counts = []
        for row in range(rows):
            y0 = row * crop_h // rows
            y1 = max(y0 + 1, (row + 1) * crop_h // rows)
            for col in range(cols):
                x0 = col * crop_w // cols
                x1 = max(x0 + 1, (col + 1) * crop_w // cols)
                dark = 0
                for y in range(y0, y1):
                    for x in range(x0, x1):
                        if pixels[x, y] < 100:
                            dark += 1
                counts.append(dark)
        return tuple(counts)

    def _advance(self, window, key, box=(0.12, 0.68, 0.75, 0.84), tries=4, required=True, minimum=8):
        before = self._sig(window, box)
        best = 0
        for _ in range(tries):
            _key(window, key, gap=0.3)
            # One press, then wait for that press to draw. Sending the next
            # press before the draw queues a page skip.
            deadline = time.time() + 2.5
            while time.time() < deadline:
                time.sleep(0.3)
                after = self._sig(window, box)
                changed = sum(a != b for a, b in zip(after, before))
                best = max(best, changed)
                if changed >= minimum and after == self._sig(window, box):
                    return True
        if required:
            self._shot(window, "/tmp/door-budget-stuck.png")
            self.fail("screen did not change after %s (moved %d)" % (key, best))
        return False

    def _stable(self, window, box, wait=0.4):
        first = self._sig(window, box)
        time.sleep(wait)
        return first == self._sig(window, box)

    def _skip_movie(self, window):
        # Copyright ignores A. The star accepts one A and drops into the
        # letterboxed fight, which one more A ends. The title then opens a
        # static menu. A moving scene must not count as that menu.
        whole = (0.0, 0.0, 1.0, 1.0)
        deadline = time.time() + 40
        while time.time() < deadline:
            if self._letterbox(window):
                _key(window, "s", gap=0.35)
                continue
            _key(window, "s", gap=0.35)
            time.sleep(0.3)
            if self._letterbox(window):
                continue
            if self._stable(window, whole, 0.45):
                return
        self._shot(window, "/tmp/door-budget-title.png")
        self.fail("intro movie did not reach the title menu")

    def _reach_title(self, window):
        # Copyright and the bars ignore A. One A during the fight ends it.
        deadline = time.time() + 20
        while time.time() < deadline:
            if self._letterbox(window):
                _key(window, "s", gap=0.45)
                continue
            return
        self._shot(window, "/tmp/door-budget-title.png")
        self.fail("intro movie did not reach the title")

    def _letterbox(self, window):
        from PIL import ImageGrab
        rect = self._rect(window)
        image = ImageGrab.grab(bbox=rect).convert("L")
        width, height = image.size
        # Copyright and the fight keep a black band across the top of the LCD.
        # The title logo is dark ink on a light field, so its mean stays higher.
        crop = image.crop((int(width * 0.10), int(height * 0.02), int(width * 0.70), int(height * 0.18)))
        pixels = list(crop.get_flattened_data()) if hasattr(crop, "get_flattened_data") else list(crop.getdata())
        return (sum(pixels) / len(pixels)) < 90

    def _rect(self, window):
        geo = subprocess.run(
            ["xdotool", "getwindowgeometry", "--shell", window],
            capture_output=True, text=True, check=True,
        )
        vals = {}
        for line in geo.stdout.splitlines():
            key, value = line.split("=")
            vals[key] = int(value)
        return (vals["X"], vals["Y"], vals["X"] + vals["WIDTH"], vals["Y"] + int(vals["HEIGHT"] * 0.45))

    def _shot(self, window, path):
        from PIL import ImageGrab
        ImageGrab.grab(bbox=self._rect(window)).save(path)

    def _window(self):
        deadline = time.time() + 15
        while time.time() < deadline:
            _dismiss_heads_up()
            ids = _windows("Playdate Simulator")
            if ids:
                return ids[-1]
            time.sleep(0.2)
        self.fail("Playdate Simulator window did not appear")


if __name__ == "__main__":
    unittest.main()
