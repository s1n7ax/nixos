"""Which energy meters belong under the Energy dashboard's "Individual devices"."""

from __future__ import annotations

import re
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any

EXCLUDE_LABEL = "energy_exclude"
# Derived helpers would double count; solarman is the inverter (a grid/solar source, not a
# device).
EXCLUDE_PLATFORMS = frozenset(
    {"utility_meter", "template", "integration", "statistics", "min_max", "group", "solarman"}
)
# Counters that reset every period (today, this month...) are not lifetime meters.
PERIOD_SUFFIX = re.compile(r"_(today|yesterday|day|daily|week|weekly|month|monthly|year|yearly)$")
ENERGY_UNITS = frozenset({"Wh", "kWh", "MWh"})


@dataclass(frozen=True)
class Entity:
    """An entity registry entry with the attributes of its current state."""

    entity_id: str
    device_id: str | None = None
    platform: str = ""
    disabled: bool = False
    labels: frozenset[str] = frozenset()
    attributes: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Changes:
    """The device list after a sync, and what the sync did to it."""

    devices: list[dict[str, str]]
    added: list[str]
    removed: list[str]


def sync(entities: Sequence[Entity], current: Sequence[Mapping[str, str]]) -> Changes:
    """Add new meters, drop deleted and excluded ones, leave hand-added entries alone."""
    by_id = {entity.entity_id: entity for entity in entities}

    def keep(device: Mapping[str, str]) -> bool:
        stat = device["stat_consumption"]
        # External statistics (contain ':') are not entities, so never prune them.
        return ":" in stat or (stat in by_id and EXCLUDE_LABEL not in by_id[stat].labels)

    devices = [dict(device) for device in current if keep(device)]
    removed = [device["stat_consumption"] for device in current if not keep(device)]
    known = {device["stat_consumption"] for device in devices}
    added = []
    for meter in entities:
        if meter.entity_id in known or not _is_meter(meter):
            continue
        entry = {"stat_consumption": meter.entity_id}
        if power := _power_for(meter, entities):
            entry["stat_rate"] = power
        devices.append(entry)
        added.append(meter.entity_id)
    return Changes(devices, added, removed)


def _is_meter(entity: Entity) -> bool:
    return (
        entity.entity_id.startswith("sensor.")
        and bool(entity.device_id)
        and not entity.disabled
        and EXCLUDE_LABEL not in entity.labels
        and entity.platform not in EXCLUDE_PLATFORMS
        and not PERIOD_SUFFIX.search(entity.entity_id)
        and entity.attributes.get("device_class") == "energy"
        and entity.attributes.get("state_class") == "total_increasing"
        and entity.attributes.get("unit_of_measurement") in ENERGY_UNITS
    )


def _power_for(meter: Entity, entities: Sequence[Entity]) -> str | None:
    """The power sensor on the meter's device, for the dashboard's live "now" usage."""
    candidates = [
        entity.entity_id
        for entity in entities
        if entity.device_id == meter.device_id
        and not entity.disabled
        and entity.entity_id.startswith("sensor.")
        and not PERIOD_SUFFIX.search(entity.entity_id)
        and entity.attributes.get("device_class") == "power"
    ]
    sibling = re.sub(r"_energy$", "_power", meter.entity_id)
    if sibling in candidates:
        return sibling
    return candidates[0] if candidates else None
