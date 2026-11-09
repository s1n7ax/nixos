// The card's behaviour: the 3D view, shortcuts, cameras, security toggles and the bottom
// sheet for the AC and cameras. The card's look (house-dashboard-card.js) supplies the 3D
// theme, its CSS, the page layout and the markup of each row.

import { PLAN } from "./plan.js";
import { HouseView } from "./house-view.js";
import { ICONS } from "./icons.js";
import { CAMERAS, moreInfo, SECURITY, shortcutOn, shortcutsFor, summary, toggleShortcut } from "./dashboard-data.js";

// Kinds a tap toggles; the AC and cameras open the sheet; anything else opens HA's more-info.
const TOGGLES = ["light", "pump"];
const SHEETS = ["climate", "camera"];
const CLOCK_MS = 20000;

export class HouseCardBase extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this.sheet = null;
    // The shadow root outlives the view, so one listener serves every mount.
    this.shadowRoot.addEventListener("click", (ev) => this.onClick(ev));
  }

  setConfig(config) {
    this.config = config;
  }

  getCardSize() {
    return 12;
  }

  set hass(hass) {
    this._hass = hass;
    if (this.isConnected) this.render();
  }

  connectedCallback() {
    if (this._hass) this.render();
  }

  render() {
    if (!this.view) this.mount();
    this.view.update(this._hass);
    this.refresh();
  }

  mount() {
    this.shadowRoot.innerHTML = `<style>${this.constructor.css}</style>${this.constructor.layout}`;
    this.view = new HouseView(this.shadowRoot.querySelector(".model"), PLAN, this.constructor.theme, {
      onTap: (device) => this.tapDevice(device),
      markerContent: (device, st, active) => this.markerContent(device, st, active),
    });
    this.clock = setInterval(() => this.refresh(), CLOCK_MS);
  }

  // HA detaches cards when the view changes; drop the GL context until it comes back.
  disconnectedCallback() {
    clearInterval(this.clock);
    this.view?.destroy();
    this.view = null;
    this.sheet = null;
  }

  markerContent(device, st, active) {
    if (device.kind === "light") return "";
    if (device.kind === "climate" && active && st.attributes.temperature != null) {
      return `${ICONS.climate}<span>${st.attributes.temperature}°</span>`;
    }
    return ICONS[device.kind] ?? "";
  }

  tapDevice(device) {
    if (TOGGLES.includes(device.kind)) {
      this._hass.callService("homeassistant", "toggle", { entity_id: device.entity });
    } else if (SHEETS.includes(device.kind)) {
      this.sheet = { kind: device.kind, entity: device.entity, name: device.name };
      this.refresh();
    } else {
      moreInfo(this, device.entity);
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
    this.fill(".floors", [{ id: "all", name: "All" }, ...PLAN.floors]
      .map((f) => `<button data-action="floor" data-floor="${f.id}" class="${this.view.visibleFloor === f.id ? "sel" : ""}">${f.name}</button>`)
      .join(""));
    this.fill(".sheet-host", this.sheet ? this.sheetHtml(hass.states[this.sheet.entity]) : "");
    this.attachStream();
  }

  // HA's own camera player, for a live stream instead of a still. The harness has none.
  attachStream() {
    const slot = this.shadowRoot.querySelector(".feed-live");
    if (!slot || !customElements.get("ha-camera-stream")) return;
    let player = slot.firstElementChild;
    if (!player) {
      player = document.createElement("ha-camera-stream");
      player.muted = true;
      player.controls = true;
      player.allowExoPlayer = true;
      slot.replaceChildren(player);
    }
    player.hass = this._hass;
    player.stateObj = this._hass.states[this.sheet.entity];
  }

  shortcutState(sc, on) {
    const st = this._hass.states[sc.entity];
    if (sc.kind === "climate") {
      if (!on) return st?.state === "unavailable" ? "Unavailable" : "Off";
      return [st.attributes.temperature != null && `${st.attributes.temperature}°`, st.state.replace("_", " ")].filter(Boolean).join(" · ");
    }
    return on ? "On" : "Off";
  }

  sheetHtml(st) {
    const { kind, entity, name } = this.sheet;
    let body = "";
    if (!st || st.state === "unavailable") {
      body = `<p class="unavailable-note">${name} is unavailable.</p>`;
    } else if (kind === "camera") {
      body = customElements.get("ha-camera-stream")
        ? `<div class="feed feed-live"></div>`
        : `<img class="feed" src="${st.attributes.entity_picture}" alt="${name}">`;
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
