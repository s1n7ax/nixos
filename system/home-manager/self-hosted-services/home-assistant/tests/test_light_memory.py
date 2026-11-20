from __future__ import annotations

import json

import pytest

from memory import fill, setting

WARM = {"brightness": 127, "color_temp_kelvin": 4000}


@pytest.mark.parametrize(
    ("attributes", "expected"),
    [
        (
            {"brightness": 127, "color_mode": "color_temp", "color_temp_kelvin": 4000},
            WARM,
        ),
        (
            {"brightness": 200, "color_mode": "xy", "xy_color": (0.38, 0.37), "hs_color": (30, 50)},
            {"brightness": 200, "xy_color": [0.38, 0.37]},
        ),
        ({"brightness": 90.0, "color_mode": "brightness"}, {"brightness": 90}),
        ({"color_mode": "color_temp", "color_temp_kelvin": 2700}, {"color_temp_kelvin": 2700}),
        ({"brightness": None, "color_mode": None}, None),
        ({}, None),
    ],
)
def test_setting_takes_brightness_and_the_colour_of_the_current_mode(attributes, expected):
    assert setting(attributes) == expected


def test_setting_survives_json():
    remembered = setting({"brightness": 1, "color_mode": "xy", "xy_color": (0.1, 0.2)})
    assert json.loads(json.dumps(remembered)) == remembered


def test_plain_turn_on_gets_the_remembered_setting():
    assert fill({}, WARM) == WARM


def test_xy_comes_back_as_a_tuple():
    assert fill({}, {"brightness": 5, "xy_color": [0.3, 0.4]}) == {
        "brightness": 5,
        "xy_color": (0.3, 0.4),
    }


def test_asked_brightness_wins_and_keeps_the_remembered_colour():
    assert fill({"brightness": 255}, WARM) == {"brightness": 255, "color_temp_kelvin": 4000}


@pytest.mark.parametrize(
    "color",
    [
        {"color_temp_kelvin": 2700},
        {"xy_color": (0.5, 0.4)},
        {"hs_color": (10, 100)},
        {"rgb_color": (255, 0, 0)},
    ],
)
def test_asked_colour_wins_and_keeps_the_remembered_brightness(color):
    assert fill(color, WARM) == {"brightness": 127, **color}


def test_white_takes_nothing():
    assert fill({"white": 200}, WARM) == {"white": 200}


def test_other_params_pass_through():
    assert fill({"transition": 2, "effect": "breathe"}, WARM) == {
        "transition": 2,
        "effect": "breathe",
        **WARM,
    }


@pytest.mark.parametrize("remembered", [None, {}])
def test_nothing_remembered_changes_nothing(remembered):
    assert fill({"transition": 1}, remembered) == {"transition": 1}


def test_fill_leaves_the_callers_params_alone():
    params = {"transition": 1}
    fill(params, WARM)
    assert params == {"transition": 1}
