"""Argument handling — the one path that must never start a take by accident."""

from __future__ import annotations

import unittest
from unittest import mock

import errors
import main


class TestArguments(unittest.TestCase):
    def test_help_never_records(self):
        with mock.patch.object(main, "record") as record:
            self.assertEqual(main.main(["--help"]), 0)
        record.assert_not_called()

    def test_an_unknown_flag_is_refused_rather_than_recorded(self):
        """A typo must not start a forty-minute take."""
        with mock.patch.object(main, "record") as record:
            self.assertEqual(main.main(["--cheque"]), 2)
        record.assert_not_called()

    def test_a_stray_argument_is_refused(self):
        with mock.patch.object(main, "record") as record:
            self.assertEqual(main.main(["--check", "extra"]), 2)
        record.assert_not_called()

    def test_no_arguments_records(self):
        with mock.patch.object(main, "missing_tools", return_value=[]):
            with mock.patch.object(main, "record", return_value=0) as record:
                self.assertEqual(main.main([]), 0)
        record.assert_called_once()

    def test_missing_tools_stop_it_before_anything_spawns(self):
        """Exit 3, not 1: a missing binary is the machine, not something to fix at the camera."""
        with mock.patch.object(main, "missing_tools", return_value=["wf-recorder"]):
            with mock.patch.object(main, "record") as record:
                self.assertEqual(main.main([]), 3)
        record.assert_not_called()


class TestExitCodes(unittest.TestCase):
    def test_a_fixable_setup_problem_exits_one(self):
        self.assertEqual(main.complain(errors.AudioSourceError("headset is off")), 1)

    def test_a_machine_problem_exits_three(self):
        self.assertEqual(main.complain(errors.ToolUnavailableError("no gphoto2")), 3)


if __name__ == "__main__":
    unittest.main()
