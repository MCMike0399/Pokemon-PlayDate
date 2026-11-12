"""A boot that misses the title or exhausts the 16 MiB pool fails the budget."""
import unittest
from pathlib import Path

from tools.measure_boot_budget import LUA_PEAK_BUDGET_KIB, POOL_BYTES, evaluate, parse_trace, step_rows

ROOT = Path(__file__).resolve().parents[2]
HEADER = (
    'schema\t1\tbuild\ttest\tplatform\tsimulator\n'
    'sequence\tphase\tclock_ms\tsince_yield_ms\tphase_ms\theap_kib\tobserved_peak_kib\n'
)


def trace(*rows):
    lines = [HEADER]
    for row in rows:
        sequence, phase, clock, heap, peak = row
        lines.append(f'{sequence}\t{phase}\t{clock}\t1\t1\t{heap:.3f}\t{peak:.3f}')
    return parse_trace('\n'.join(lines))


class BootBudgetTests(unittest.TestCase):
    def test_pool_budget_stays_at_16_mib(self):
        self.assertEqual(POOL_BYTES, 16645684)
        self.assertLess(LUA_PEAK_BUDGET_KIB * 1024, POOL_BYTES)

    def test_stopped_boot_fails_even_when_a_title_mark_exists(self):
        rows = trace(
            (43, 'title.visible', 2163, 10873.8, 13206.2),
            (59, 'CeruleanContent.installSigns.end', 2501, 11494.3, 13206.2),
            (84, 'error.not enough memory', 3446, 11388.0, 13792.471),
        )
        problems = evaluate(rows)
        self.assertTrue(any('not enough memory' in problem for problem in problems))
        self.assertTrue(any('initialize.ready' in problem for problem in problems))

    def test_ready_title_under_the_budget_passes(self):
        rows = trace(
            (44, 'title.visible', 1050, 10759.8, 12935.0),
            (62, 'import.regionStories.end', 1200, 11202.7, 12935.0),
            (70, 'VermilionCatalogExporter.register.end', 1800, 11600.0, 13420.557),
            (657, 'initialize.ready', 21709, 12005.3, 13420.557),
        )
        self.assertEqual(evaluate(rows), [])

    def test_ready_boot_over_the_lua_budget_fails(self):
        rows = trace(
            (1, 'title.visible', 1000, 12000.0, 15000.0),
            (2, 'initialize.ready', 2000, 12000.0, 15000.0),
        )
        problems = evaluate(rows)
        self.assertTrue(any('exceeds budget' in problem for problem in problems))

    def test_missing_title_fails(self):
        rows = trace((1, 'initialize.ready', 2000, 8000.0, 8000.0))
        self.assertTrue(any('title never' in problem for problem in evaluate(rows)))

    def test_step_report_keeps_registration_and_drops_yield_heartbeats(self):
        rows = trace(
            (1, 'import.regionStories.begin', 100, 12000.0, 12000.0),
            (2, 'initialize.yield', 110, 13000.0, 13000.0),
            (3, 'import.regionStories.end', 120, 12300.0, 13000.0),
            (4, 'error.alive.30', 200, 12300.0, 13000.0),
        )
        steps = step_rows(rows)
        self.assertEqual([step['phase'] for step in steps], [
            'import.regionStories.begin', 'import.regionStories.end'])
        self.assertAlmostEqual(steps[1]['delta_kib'], 300.0)
        self.assertAlmostEqual(steps[1]['since_peak_kib'], 13000.0)

    def test_error_screen_prints_the_stop_once(self):
        source = (ROOT / 'Source/game/bootstrap.lua').read_text()
        start = source.index('function GameBootstrap.drawError')
        body = source[start:source.index('\nfunction GameBootstrap.fail')]
        self.assertIn('Game stopped safely', body)
        self.assertNotIn('BootTrace.phase', body)
        self.assertEqual(body.count('gfx.drawText'), 2)


if __name__ == '__main__':
    unittest.main()
