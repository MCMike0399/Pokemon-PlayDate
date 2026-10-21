import unittest

from tools.harness.journeys import Journey
from tools.harness.protocol import ProtocolError


def dialog(instance, line=1, ready=True):
    return {"root": "dialog", "dialog": {"instance": instance, "line": line, "ready": ready}}


class DialogJourneyTests(unittest.TestCase):
    def driver(self, initial, following):
        driver = object.__new__(Journey)
        driver.state = initial
        driver.presses = []
        states = iter(following)

        def send(command):
            driver.presses.append(command)
            driver.state = next(states)

        driver.send = send
        return driver

    def test_ready_callback_can_open_new_dialog_at_same_line(self):
        driver = self.driver(dialog(8), [dialog(9, ready=False), dialog(9), {"root": "event"}])
        driver.dialog()
        self.assertEqual(driver.presses, ["press a"] * 3)
        self.assertEqual(driver.state["root"], "event")

    def test_ready_same_instance_and_line_still_fails(self):
        driver = self.driver(dialog(8), [dialog(8)])
        with self.assertRaisesRegex(ProtocolError, "failed to advance"):
            driver.dialog()

    def test_same_instance_next_line_is_progress(self):
        driver = self.driver(dialog(8), [dialog(8, line=2), {"root": "overworld"}])
        driver.dialog()
        self.assertEqual(driver.presses, ["press a"] * 2)
