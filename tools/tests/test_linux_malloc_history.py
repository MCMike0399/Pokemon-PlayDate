"""Host checks for the Linux malloc-log clear. No Simulator is launched."""
import tempfile
import unittest
from pathlib import Path

from tools.harness.linux_malloc_history import (
    POOL_SIZE, MallocHistoryError, _malloc_menu_word, clear_point, parse_heap_status,
    refresh_point, require_pool)


class LinuxMallocHistoryTests(unittest.TestCase):
    def test_footer_parses_heap_used_active_and_items(self):
        parsed = parse_heap_status('Heap Used: 9.22 MB, Active: 7.81 MB, 78965 items')
        self.assertEqual(parsed['heap_used'], '9.22 MB')
        self.assertEqual(parsed['heap_used_kib'], 9.22 * 1024)
        self.assertEqual(parsed['active'], '7.81 MB')
        self.assertEqual(parsed['items'], 78965)

    def test_footer_accepts_a_cleared_kilobyte_active_line(self):
        parsed = parse_heap_status('Automatically Refresh Heap Used: 9.22 MB, Active: 0.00 KB, 0 items')
        self.assertEqual(parsed['active_kib'], 0)
        self.assertEqual(parsed['items'], 0)
        self.assertEqual(parsed['heap_used_kib'], 9.22 * 1024)

    def test_footer_without_the_heap_line_is_refused(self):
        with self.assertRaisesRegex(MallocHistoryError, 'Heap Used'):
            parse_heap_status('Invert Stack Show Active Only')

    def test_clear_point_is_left_of_automatically_and_inside_the_window(self):
        words = [{'text': 'Automatically', 'left': 101, 'top': 21, 'width': 94, 'height': 14}]
        window = (22, 96, 738, 451)
        origin = (22, 491)
        self.assertEqual(clear_point(words, origin, window), (22 + 101 - 49, 491 + 21 + 7))

    def test_malloc_row_is_the_show_log_line_even_when_ocr_mangles_the_name(self):
        words = [
            {'text': 'Show', 'top': 304, 'left': 213, 'width': 36, 'height': 11},
            {'text': 'Lua', 'top': 304, 'left': 255, 'width': 23, 'height': 11},
            {'text': 'Memory', 'top': 304, 'left': 283, 'width': 56, 'height': 14},
            {'text': 'Show', 'top': 329, 'left': 213, 'width': 36, 'height': 11},
            {'text': 'Maio', 'top': 329, 'left': 255, 'width': 44, 'height': 14},
            {'text': 'Log', 'top': 331, 'left': 305, 'width': 23, 'height': 14},
        ]
        self.assertEqual(_malloc_menu_word(words)['text'], 'Maio')
        self.assertIsNone(_malloc_menu_word([{'text': 'Show', 'top': 10, 'left': 0, 'width': 10, 'height': 10}]))

    def test_refresh_point_is_left_of_the_clear_icon(self):
        words = [{'text': '(Automatically', 'left': 96, 'top': 30, 'width': 94, 'height': 14}]
        window = (8, 40, 738, 451)
        origin = (8, 435)
        self.assertLess(refresh_point(words, origin, window)[0], clear_point(words, origin, window)[0])

    def test_clear_point_accepts_a_parenthesized_automatically_label(self):
        words = [{'text': '(Automatically', 'left': 96, 'top': 30, 'width': 94, 'height': 14}]
        window = (8, 40, 738, 451)
        point = clear_point(words, (8, 435), window)
        self.assertEqual(point, (8 + 96 - 49, 435 + 30 + 7))

    def test_clear_point_refuses_a_footer_with_no_label(self):
        window = (22, 96, 738, 451)
        self.assertIsNone(clear_point([{'text': 'Refresh', 'left': 10, 'top': 10, 'width': 40, 'height': 12}],
                                      (22, 491), window))

    def test_clear_point_refuses_a_click_outside_the_malloc_window(self):
        words = [{'text': 'Automatically', 'left': 10, 'top': 4, 'width': 90, 'height': 12}]
        window = (400, 400, 200, 80)
        self.assertIsNone(clear_point(words, (400, 400), window))

    def test_pool_guard_refuses_any_other_size_and_does_not_write_the_ini(self):
        with tempfile.TemporaryDirectory() as temporary:
            settings = Path(temporary) / 'Playdate Simulator.ini'
            settings.write_text('MallocPoolSize=16645684\nShowPerfWarning=0\n')
            self.assertEqual(require_pool(settings), POOL_SIZE)
            original = settings.read_bytes()
            settings.write_text('MallocPoolSize=0\n')
            with self.assertRaisesRegex(MallocHistoryError, '16645684'):
                require_pool(settings)
            self.assertEqual(settings.read_text(), 'MallocPoolSize=0\n')
            settings.write_bytes(original)
            self.assertEqual(settings.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
