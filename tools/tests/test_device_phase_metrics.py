"""The boot budget ends when the title accepts input, not at early artwork."""
import unittest

from tools.device.metrics import phase_report


def phase(name, clock):
    return dict(phase=name, clock_ms=clock, since_yield_ms=10, phase_ms=10)


class DeviceBootMetricTests(unittest.TestCase):
    def test_early_artwork_does_not_hide_slow_input_readiness(self):
        report = phase_report([
            phase('boot.begin', 100), phase('title.start.end', 1100),
            phase('title.visible', 1200), phase('initialize.ready', 25100),
        ], [], [])
        self.assertEqual(report['phase_measurements']['boot_title'], 25000)
        self.assertIn('boot_title', report['phase_failures'])

    def test_ready_title_within_budget_passes_boot_without_artwork_marker(self):
        report = phase_report([
            phase('boot.begin', 100), phase('initialize.ready', 8100),
        ], [], [])
        self.assertEqual(report['phase_measurements']['boot_title'], 8000)
        self.assertNotIn('boot_title', report['phase_failures'])

    def test_artwork_alone_cannot_establish_input_readiness(self):
        report = phase_report([
            phase('boot.begin', 100), phase('title.start.end', 1100),
            phase('title.visible', 1200),
        ], [], [])
        self.assertIsNone(report['phase_measurements']['boot_title'])
        self.assertIn('boot_title', report['phase_failures'])
