"""Naming a take, and finding the ones a crash left behind."""

from __future__ import annotations

import datetime as dt
import tempfile
import unittest
from pathlib import Path

import takes


class TestTimestamp(unittest.TestCase):
    def test_uses_the_charted_format(self):
        moment = dt.datetime(2026, 9, 19, 14, 30, 5)
        self.assertEqual(takes.timestamp(moment), "2026-09-19 14-30-05")


class TestDescription(unittest.TestCase):
    def test_keeps_an_ordinary_description(self):
        self.assertEqual(takes.clean_description("Nix flakes part 3"), "Nix flakes part 3")

    def test_drops_path_separators(self):
        self.assertEqual(takes.clean_description("nix/flakes"), "nix flakes")

    def test_collapses_whitespace_and_trims(self):
        self.assertEqual(takes.clean_description("  nix   flakes \n"), "nix flakes")

    def test_empty_description_stays_untitled(self):
        self.assertEqual(takes.clean_description("   "), "UNTITLED")

    def test_drops_control_characters(self):
        self.assertEqual(takes.clean_description("nix\x00flakes"), "nix flakes")


class TestNames(unittest.TestCase):
    def test_a_rolling_take_is_untitled(self):
        self.assertEqual(takes.take_filename("2026-09-19 14-30-05"), "2026-09-19 14-30-05 UNTITLED.mkv")

    def test_renaming_keeps_the_original_timestamp(self):
        path = Path("/takes/2026-09-19 14-30-05 UNTITLED.mkv")
        self.assertEqual(takes.renamed(path, "Nix flakes"), Path("/takes/2026-09-19 14-30-05 Nix flakes.mkv"))

    def test_an_empty_description_leaves_the_name_alone(self):
        path = Path("/takes/2026-09-19 14-30-05 UNTITLED.mkv")
        self.assertEqual(takes.renamed(path, "  "), path)


class TestOrphans(unittest.TestCase):
    def test_finds_only_untitled_takes_oldest_first(self):
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            (directory / "2026-09-19 14-30-05 UNTITLED.mkv").touch()
            (directory / "2026-09-18 09-00-00 UNTITLED.mkv").touch()
            (directory / "2026-09-17 08-00-00 Nix flakes.mkv").touch()
            self.assertEqual(
                [p.name for p in takes.find_orphans(directory)],
                ["2026-09-18 09-00-00 UNTITLED.mkv", "2026-09-19 14-30-05 UNTITLED.mkv"],
            )

    def test_a_missing_directory_has_no_orphans(self):
        self.assertEqual(takes.find_orphans(Path("/nonexistent-take-directory")), [])

    def test_the_take_still_rolling_is_not_an_orphan(self):
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            current = directory / "2026-09-19 14-30-05 UNTITLED.mkv"
            current.touch()
            self.assertEqual(takes.find_orphans(directory, exclude=current), [])


class TestUniqueDestination(unittest.TestCase):
    def test_a_taken_name_gets_a_counter(self):
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            (directory / "2026-09-19 14-30-05 Nix flakes.mkv").touch()
            path = directory / "2026-09-19 14-30-05 UNTITLED.mkv"
            self.assertEqual(
                takes.unique(takes.renamed(path, "Nix flakes")).name,
                "2026-09-19 14-30-05 Nix flakes 2.mkv",
            )


if __name__ == "__main__":
    unittest.main()
