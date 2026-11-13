from __future__ import annotations

from meters import Entity, sync

METER = {"device_class": "energy", "state_class": "total_increasing", "unit_of_measurement": "kWh"}
POWER = {"device_class": "power", "state_class": "measurement", "unit_of_measurement": "W"}


def meter(entity_id="sensor.p_ac_energy", device_id="plug", platform="mqtt", **rest):
    return Entity(entity_id, device_id, platform, **{"attributes": METER, **rest})


def power(entity_id="sensor.p_ac_power", device_id="plug", **rest):
    return Entity(entity_id, device_id, "mqtt", **{"attributes": POWER, **rest})


def added(*entities):
    return sync(entities, []).added


def test_new_meter_is_added_with_its_power_sensor():
    changes = sync([meter(), power()], [])
    assert changes.devices == [
        {"stat_consumption": "sensor.p_ac_energy", "stat_rate": "sensor.p_ac_power"}
    ]
    assert changes.added == ["sensor.p_ac_energy"]
    assert changes.removed == []


def test_meter_without_a_power_sensor_has_no_rate():
    assert sync([meter()], []).devices == [{"stat_consumption": "sensor.p_ac_energy"}]


def test_power_sensor_named_like_the_meter_wins():
    other = power("sensor.p_ac_load")
    assert sync([meter(), other, power()], []).devices[0]["stat_rate"] == "sensor.p_ac_power"


def test_first_power_sensor_of_the_device_when_none_is_named_like_the_meter():
    entities = [meter(), power("sensor.other_power", "other"), power("sensor.p_ac_load")]
    assert sync(entities, []).devices[0]["stat_rate"] == "sensor.p_ac_load"


def test_disabled_and_period_power_sensors_are_not_the_rate():
    entities = [meter(), power(disabled=True), power("sensor.p_ac_power_today")]
    assert sync(entities, []).devices == [{"stat_consumption": "sensor.p_ac_energy"}]


def test_known_meter_is_left_as_it_is():
    current = [{"stat_consumption": "sensor.p_ac_energy", "name": "AC"}]
    changes = sync([meter(), power()], current)
    assert changes.devices == current
    assert changes.added == []
    assert changes.removed == []


def test_hand_added_entry_stays():
    current = [{"stat_consumption": "sensor.p_ac_energy_today"}, {"stat_consumption": "ext:meter"}]
    entities = [Entity("sensor.p_ac_energy_today", platform="utility_meter", attributes=METER)]
    changes = sync(entities, current)
    assert changes.devices == current
    assert changes.removed == []


def test_deleted_entity_is_dropped():
    changes = sync([], [{"stat_consumption": "sensor.p_ac_energy"}])
    assert changes.devices == []
    assert changes.removed == ["sensor.p_ac_energy"]


def test_excluded_label_drops_the_entry_and_keeps_it_out():
    excluded = meter(labels=frozenset({"energy_exclude"}))
    changes = sync([excluded], [{"stat_consumption": "sensor.p_ac_energy"}])
    assert changes.devices == []
    assert changes.added == []
    assert changes.removed == ["sensor.p_ac_energy"]


def test_only_lifetime_energy_meters_on_a_device_are_added():
    assert added(meter("binary_sensor.p_ac_energy")) == []
    assert added(meter(device_id=None)) == []
    assert added(meter(disabled=True)) == []
    assert added(meter(platform="utility_meter")) == []
    assert added(meter(platform="solarman")) == []
    assert added(meter("sensor.p_ac_energy_today")) == []
    assert added(meter("sensor.p_ac_energy_monthly")) == []
    assert added(meter(attributes={**METER, "device_class": "power"})) == []
    assert added(meter(attributes={**METER, "state_class": "total"})) == []
    assert added(meter(attributes={**METER, "unit_of_measurement": "m³"})) == []
    assert added(meter(attributes={})) == []


def test_every_energy_unit_counts():
    for unit in ("Wh", "kWh", "MWh"):
        assert added(meter(attributes={**METER, "unit_of_measurement": unit})) == [
            "sensor.p_ac_energy"
        ]
