"""Shared fixtures."""

from __future__ import annotations

import itertools

import pytest


@pytest.fixture
def make_id():
    counter = itertools.count(1)
    return lambda: f"id{next(counter)}"
