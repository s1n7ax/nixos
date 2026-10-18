from __future__ import annotations

from core.burst import BurstWindow

WINDOW = 600.0


def test_first_ring_is_not_recent():
    assert not BurstWindow(WINDOW).rang_recently("person", 0.0)


def test_window_per_type():
    burst = BurstWindow(WINDOW)
    burst.record("person", 100.0)
    assert burst.rang_recently("person", 100.0)
    assert burst.rang_recently("person", 100.0 + WINDOW - 1)
    assert not burst.rang_recently("person", 100.0 + WINDOW)
    assert not burst.rang_recently("car", 101.0)


def test_record_restarts_the_window():
    burst = BurstWindow(WINDOW)
    burst.record("person", 0.0)
    burst.record("person", WINDOW + 5)
    assert burst.rang_recently("person", WINDOW + 10)


def test_clock_going_back_is_not_recent():
    burst = BurstWindow(WINDOW, {"person": 1000.0})
    assert not burst.rang_recently("person", 900.0)


def test_round_trip():
    burst = BurstWindow(WINDOW, {"person": 5.0})
    assert BurstWindow(WINDOW, burst.as_dict()).rang_recently("person", 6.0)
