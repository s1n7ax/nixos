"""Stopping the take without losing it."""

from __future__ import annotations

import signal
import unittest

import supervisor


class FakeProcess:
    """A child that ignores every signal until the one at `dies_on`."""

    def __init__(self, dies_on: int | None, code: int = 0):
        self.dies_on = dies_on
        self.code = code
        self.sent: list[int] = []
        self.alive = True

    def send(self, number: int) -> None:
        self.sent.append(number)
        if number == self.dies_on:
            self.alive = False

    def wait(self, _timeout: float) -> int | None:
        return None if self.alive else self.code


class TestLadder(unittest.TestCase):
    def test_a_well_behaved_ffmpeg_stops_on_sigint(self):
        child = FakeProcess(dies_on=signal.SIGINT)
        self.assertEqual(supervisor.stop(child.send, child.wait), 0)
        self.assertEqual(child.sent, [signal.SIGINT])

    def test_a_wedged_ffmpeg_escalates_to_sigterm(self):
        child = FakeProcess(dies_on=signal.SIGTERM)
        supervisor.stop(child.send, child.wait)
        self.assertEqual(child.sent, [signal.SIGINT, signal.SIGTERM])

    def test_the_last_rung_is_sigkill(self):
        """Only acceptable because mkv survives it: 3439 of 3442 frames recovered."""
        child = FakeProcess(dies_on=signal.SIGKILL)
        supervisor.stop(child.send, child.wait)
        self.assertEqual(child.sent, [signal.SIGINT, signal.SIGTERM, signal.SIGKILL])

    def test_the_graces_are_the_charted_ones(self):
        waits: list[float] = []
        child = FakeProcess(dies_on=signal.SIGKILL)
        supervisor.stop(child.send, lambda timeout: waits.append(timeout) or child.wait(timeout))
        self.assertEqual(waits[:2], [10.0, 3.0])

    def test_an_already_dead_child_is_not_signalled_twice(self):
        child = FakeProcess(dies_on=None)
        child.alive = False
        self.assertEqual(supervisor.stop(child.send, child.wait), 0)
        self.assertEqual(child.sent, [signal.SIGINT])


class TestElapsed(unittest.TestCase):
    def test_reads_as_a_wall_clock(self):
        self.assertEqual(supervisor.elapsed(0), "00:00:00")
        self.assertEqual(supervisor.elapsed(862), "00:14:22")
        self.assertEqual(supervisor.elapsed(3661), "01:01:01")


if __name__ == "__main__":
    unittest.main()
