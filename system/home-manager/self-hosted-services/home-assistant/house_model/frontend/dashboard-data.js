// What the dashboard shows beyond the model: each person's shortcuts, the cameras, the
// security toggles, and a one-line summary of the house.

import { PLAN } from "./plan.js";
import { deviceActive } from "./house-view.js";

// From 10 days of recorder history, most-tapped first. Groups toggle every switch together.
export const SHORTCUTS = {
  s1n7ax: [
    { name: "AC", entity: "climate.panasonic_ac_panasonic_ac", kind: "climate" },
    { name: "Office · Srinesh", entity: "light.b_office_srinesh", kind: "light" },
    { name: "Office · Nidu", entity: "light.b_office_nidu", kind: "light" },
    { name: "Backyard", room: "backyard", kind: "room" },
    { name: "House front", room: "house_front", kind: "room" },
    { name: "Living room", room: "living_room", kind: "room" },
  ],
  nidu: [
    { name: "AC", entity: "climate.panasonic_ac_panasonic_ac", kind: "climate" },
    { name: "Office · Nidu", entity: "light.b_office_nidu", kind: "light" },
    { name: "Office · Srinesh", entity: "light.b_office_srinesh", kind: "light" },
  ],
};

export const SECURITY = [
  { name: "I'm away", entity: "input_boolean.i_m_away_from_home" },
  { name: "We're away", entity: "input_boolean.we_are_away_from_home" },
  { name: "No one home", entity: "input_boolean.no_one_s_home" },
];

export const CAMERAS = PLAN.devices.filter((d) => d.kind === "camera");

export const roomLights = (roomId) => PLAN.devices.filter((d) => d.kind === "light" && d.room === roomId);

export function shortcutsFor(hass) {
  const name = (hass.user?.name ?? "").toLowerCase();
  return SHORTCUTS[name] ?? SHORTCUTS.s1n7ax;
}

// A shortcut is on when its entity is, or for a room when any of its lights is.
export function shortcutOn(hass, sc) {
  if (sc.kind === "room") return roomLights(sc.room).some((d) => hass.states[d.entity]?.state === "on");
  const st = hass.states[sc.entity];
  return !!st && st.state !== "off" && st.state !== "unavailable";
}

export function toggleShortcut(hass, sc) {
  if (sc.kind === "room") {
    const lights = roomLights(sc.room);
    const service = shortcutOn(hass, sc) ? "turn_off" : "turn_on";
    return hass.callService("homeassistant", service, { entity_id: lights.map((d) => d.entity) });
  }
  if (sc.kind === "climate") {
    return hass.callService("climate", shortcutOn(hass, sc) ? "turn_off" : "turn_on", { entity_id: sc.entity });
  }
  return hass.callService("homeassistant", "toggle", { entity_id: sc.entity });
}

export function summary(hass) {
  const lightsOn = PLAN.devices.filter((d) => d.kind === "light" && deviceActive(d, hass.states[d.entity])).length;
  const ac = hass.states["climate.panasonic_ac_panasonic_ac"];
  const carHome = Number(hass.states["sensor.veranda_parking_car_count"]?.state) > 0;
  const home = ["person.s1n7ax", "person.nidu"]
    .map((id) => hass.states[id])
    .filter((p) => p?.state === "home")
    .map((p) => p.attributes.friendly_name);
  const motion = PLAN.devices.filter((d) => d.kind === "motion" && hass.states[d.entity]?.state === "on").map((d) => d.name);
  const alarm = PLAN.devices.filter((d) => (d.kind === "smoke" || d.kind === "leak") && hass.states[d.entity]?.state === "on");
  const away = SECURITY.find((s) => hass.states[s.entity]?.state === "on");
  const weather = hass.states["weather.forecast_home"];
  const inside = hass.states["sensor.t_office_tempeture_sensor_temperature"];
  return { lightsOn, ac, carHome, home, motion, alarm, away, weather, inside };
}

export function moreInfo(el, entityId) {
  el.dispatchEvent(new CustomEvent("hass-more-info", { detail: { entityId }, bubbles: true, composed: true }));
}
