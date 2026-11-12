"""The boot clip waits for initialize.ready and reports a miss."""
import tempfile
import unittest
from pathlib import Path

from tools.capture_boot_lcd import BootCaptureFailure, boot_marks, wait_for_ready

ROOT = Path(__file__).resolve().parents[2]


class Clock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


def trace(*rows):
    lines = ['sequence\tphase\tclock_ms\tsince_yield_ms\tphase_ms\theap_kib\tobserved_peak_kib']
    for sequence, phase, clock in rows:
        lines.append(f'{sequence}\t{phase}\t{clock}\t1\t1\t1000.000\t1000.000')
    return '\n'.join(lines) + '\n'


class CaptureBootLcdTests(unittest.TestCase):
    def test_ready_mark_is_the_end_of_boot(self):
        marks = boot_marks(trace(
            (45, 'title.visible', 972),
            (678, 'initialize.ready', 22758),
        ))
        self.assertEqual(marks['title_visible_ms'], 972)
        self.assertEqual(marks['initialize_ready_ms'], 22758)
        self.assertIsNone(marks['error'])

    def test_wait_returns_when_ready_is_appended(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'boot-trace.tsv'
            path.write_text(trace((45, 'title.visible', 1105)), encoding='utf-8')
            clock = Clock()
            reads = {'count': 0}

            def sleep(seconds):
                clock.sleep(seconds)
                reads['count'] += 1
                if reads['count'] == 2:
                    path.write_text(trace(
                        (45, 'title.visible', 1105),
                        (661, 'initialize.ready', 21479),
                    ), encoding='utf-8')

            marks = wait_for_ready(path, 90, clock, sleep)
        self.assertEqual(marks['initialize_ready_ms'], 21479)

    def test_timeout_names_the_miss(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'boot-trace.tsv'
            path.write_text(trace((70, 'MidgameCatalogExporter.register.begin', 1802)), encoding='utf-8')
            clock = Clock()
            with self.assertRaises(BootCaptureFailure) as caught:
                wait_for_ready(path, 0.5, clock, clock.sleep)
        self.assertIn('initialize.ready did not arrive', str(caught.exception))
        self.assertIn('MidgameCatalogExporter.register.begin', str(caught.exception))

    def test_error_phase_fails_before_the_timeout(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'boot-trace.tsv'
            path.write_text(trace((84, 'error.not enough memory', 3446)), encoding='utf-8')
            clock = Clock()
            with self.assertRaises(BootCaptureFailure) as caught:
                wait_for_ready(path, 90, clock, clock.sleep)
        self.assertIn('error.not enough memory', str(caught.exception))

    def test_exporter_does_not_copy_full_map_definitions(self):
        exporter = (ROOT / 'Source' / 'dev' / 'midgameCatalogExporter.lua').read_text(encoding='utf-8')
        source_maps = (ROOT / 'Source' / 'world' / 'sourceMaps.lua').read_text(encoding='utf-8')
        self.assertNotIn('SourceMaps.definition(', exporter)
        self.assertIn('SourceMaps.record(', exporter)
        self.assertNotIn('function SourceMaps.objectSprites', source_maps)
