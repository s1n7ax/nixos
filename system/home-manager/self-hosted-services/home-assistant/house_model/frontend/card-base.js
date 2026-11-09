// The card's behaviour, shared by every look: the 3D view, shortcuts, cameras, security
// toggles and the bottom sheet for the AC and cameras. A look supplies the 3D theme,
// its CSS and the page layout.

import { PLAN } from "./plan.js";
import { HouseView } from "./house-view.js";
import { ICONS } from "./icons.js";
import { CAMERAS, SECURITY, shortcutOn, shortcutsFor, summary, toggleShortcut } from "./dashboard-data.js";

export class HouseCardBase extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this.sheet = null;
  }

  setConfig(config) {
    this.config = config;
  }

  getCardSize() {
    return 12;
  }

  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (first) this.mount();
    this.view.update(hass);
    this.refresh();
  }

  get dark() {
    return this.constructor.alwaysDark || !!this._hass?.themes?.darkMode;
  }

  mount() {
    this.shadowRoot.innerHTML = `<style>${this.constructor.css}</style>${this.constructor.layout}`;
    this.classList.toggle("dark", this.dark);
    const root = this.shadowRoot;
    this.view = new HouseView(root.querySelector(".model"), PLAN, this.constructor.theme(this.dark), {
      onTap: (device) => this.tapDevice(device),
      markerContent: (device, st, active) => this.markerContent(device, st, active),
    });
    root.addEventListener("click", (ev) => this.onClick(ev));
  }

  markerContent(device, st, active) {
    if (device.kind === "light") return "";
    if (device.kind === "climate" && st && st.state !== "off") return `${ICONS.climate}<span>${st.attributes.temperature}°</span>`;
    return ICONS[device.kind] ?? "";
  }

  tapDevice(device) {
    const hass = this._hass;
    if (device.kind === "light" || device.kind === "pump") {
      hass.callService("homeassistant", "toggle", { entity_id: device.entity });
    } else if (device.kind === "climate" || device.kind === "camera") {
      this.sheet = { kind: device.kind, entity: device.entity, name: device.name };
      this.refresh();
    }
  }

  onClick(ev) {
    const t = ev.target.closest("[data-action]");
    if (!t) return;
    const hass = this._hass;
    const { action, i, entity } = t.dataset;
    if (action === "shortcut") {
      const sc = shortcutsFor(hass)[Number(i)];
      if (sc.kind === "climate" && ev.target.closest("[data-open]")) {
        this.sheet = { kind: "climate", entity: sc.entity, name: sc.name };
        this.refresh();
      } else toggleShortcut(hass, sc);
    } else if (action === "floor") {
      this.view.setFloor(t.dataset.floor);
      this.refresh();
    } else if (action === "camera") {
      this.sheet = { kind: "camera", entity, name: t.dataset.name };
      this.refresh();
    } else if (action === "security") {
      hass.callService("homeassistant", "toggle", { entity_id: entity });
    } else if (action === "close") {
      this.sheet = null;
      this.refresh();
    } else if (action === "temp") {
      const st = hass.states[entity];
      hass.callService("climate", "set_temperature", { entity_id: entity, temperature: st.attributes.temperature + Number(t.dataset.step) });
    } else if (action === "mode") {
      hass.callService("climate", "set_hvac_mode", { entity_id: entity, hvac_mode: t.dataset.mode });
    }
  }

  fill(selector, html) {
    const el = this.shadowRoot.querySelector(selector);
    if (el && el.innerHTML !== html) el.innerHTML = html;
  }

  refresh() {
    const hass = this._hass;
    const sum = summary(hass);
    this.fill(".summary", this.summaryHtml(sum));
    this.fill(".shortcuts", shortcutsFor(hass).map((sc, i) => this.shortcutHtml(sc, i, shortcutOn(hass, sc))).join(""));
    this.fill(".cameras", CAMERAS.map((c) => this.cameraHtml(c, hass.states[c.entity])).join(""));
    this.fill(".security", SECURITY.map((s) => this.securityHtml(s, hass.states[s.entity]?.state === "on")).join(""));
    this.fill(".floors", ["all", ...PLAN.floors.map((f) => f.id)]
      .map((id) => {
        const label = id === "all" ? "All" : PLAN.floors.find((f) => f.id === id).name;
        return `<button data-action="floor" data-floor="${id}" class="${this.view.visibleFloor === id ? "sel" : ""}">${label}</button>`;
      })
      .join(""));
    this.fill(".sheet-host", this.sheet ? this.sheetHtml(hass.states[this.sheet.entity]) : "");
  }

  shortcutState(sc, on) {
    const st = this._hass.states[sc.entity];
    if (sc.kind === "climate") return on ? `${st.attributes.temperature}° · ${st.state.replace("_", " ")}` : "Off";
    return on ? "On" : "Off";
  }

  sheetHtml(st) {
    const { kind, entity, name } = this.sheet;
    let body = "";
    if (kind === "camera") {
      body = `<img class="feed" src="${st.attributes.entity_picture}" alt="${name}">`;
    } else {
      const modes = st.attributes.hvac_modes
        .map((m) => `<button data-action="mode" data-entity="${entity}" data-mode="${m}" class="${st.state === m ? "sel" : ""}">${m.replace("_", " ")}</button>`)
        .join("");
      body = `
        <div class="thermo">
          <button data-action="temp" data-step="-1" data-entity="${entity}" aria-label="Cooler">${ICONS.minus}</button>
          <div class="setpoint"><b>${st.attributes.temperature}°</b><small>Room ${st.attributes.current_temperature}°</small></div>
          <button data-action="temp" data-step="1" data-entity="${entity}" aria-label="Warmer">${ICONS.plus}</button>
        </div>
        <div class="modes">${modes}</div>`;
    }
    return `<div class="scrim" data-action="close"></div>
      <div class="sheet"><header><span>${name}</span><button data-action="close" aria-label="Close">${ICONS.close}</button></header>${body}</div>`;
  }
}
