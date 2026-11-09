from __future__ import annotations

import pytest

from core.vehicles import is_parked_vehicle


@pytest.mark.parametrize("label", ["car", "motorcycle"])
def test_a_still_vehicle_is_parked(label):
    assert is_parked_vehicle({"label": label, "stationary": True})


@pytest.mark.parametrize("label", ["car", "motorcycle"])
def test_a_moving_vehicle_is_not_parked(label):
    assert not is_parked_vehicle({"label": label, "stationary": False})


def test_a_still_person_is_not_a_parked_vehicle():
    assert not is_parked_vehicle({"label": "person", "stationary": True})


def test_missing_stationary_is_not_parked():
    assert not is_parked_vehicle({"label": "car"})
