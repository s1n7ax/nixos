// Security alerts card: start a Do-not-disturb or a Pause for some types (optionally only some
// cameras) for a set time, and see or end every running Pause, Do-not-disturb and Snooze.
//
//   type: custom:security-alerts-card
//   entity: sensor.security_alerts_quiet   # optional, this is the default
//
// Loaded on every page by the security_alerts integration. This file holds no data.

const DEFAULT_ENTITY = "sensor.security_alerts_quiet";
// Types and cameras come from Frigate's config, which may not be loaded yet; ask again
// this long after a failure or an answer with no cameras.
const OPTIONS_RETRY_MS = 30000;
const SENSOR_TYPES = new Set(["door", "motion"]);
const KIND_NAMES = { pause: "Pause", dnd: "Do not disturb", snooze: "Snooze" };
const SECTIONS = [
  {
    kind: "dnd",
    title: "Do not disturb",
    hint: "Critical alerts of these types follow the phone's silent mode.",
  },
  { kind: "pause", title: "Pause", hint: "No notifications for these types." },
];

function h(tag, attrs = {}, children = []) {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === null || value === false) continue;
    if (key === "class") el.className = value;
    else if (key === "text") el.textContent = value;
    else if (key.startsWith("on")) el.addEventListener(key.slice(2), value);
    else el.setAttribute(key, value === true ? "" : value);
  }
  for (const child of [].concat(children)) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return el;
}

function untilText(iso) {
  const end = new Date(iso);
  const time = end.toLocaleTimeString([], { hour: "numeric", minute: "2-digit", hour12: true });
  const today = new Date();
  if (end.toDateString() === today.toDateString()) return `until ${time}`;
  return `until ${end.toLocaleDateString([], { weekday: "short" })} ${time}`;
}

const STYLE = `
  ha-card { padding: 4px 16px 16px; }
  h2 { font-size: 1.1em; font-weight: 500; margin: 12px 0 2px; }
  .hint { color: var(--secondary-text-color); font-size: 0.9em; margin-bottom: 8px; }
  .label { font-size: 0.85em; color: var(--secondary-text-color); margin: 6px 0 4px; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { font: inherit; font-size: 0.9em; padding: 6px 12px; border-radius: 16px; cursor: pointer;
    border: 1px solid var(--divider-color); background: transparent; color: var(--primary-text-color); }
  .chip[aria-pressed="true"] { background: var(--primary-color); border-color: var(--primary-color);
    color: var(--text-primary-color, #fff); }
  .chip:disabled { opacity: 0.4; cursor: default; }
  .go { font: inherit; margin-top: 10px; padding: 8px 18px; border-radius: 18px; border: 0; cursor: pointer;
    background: var(--primary-color); color: var(--text-primary-color, #fff); }
  .go:disabled { opacity: 0.5; cursor: default; }
  section + section { border-top: 1px solid var(--divider-color); margin-top: 12px; }
  .entry { display: flex; align-items: center; gap: 8px; padding: 8px 0; }
  .entry + .entry { border-top: 1px solid var(--divider-color); }
  .entry .what { flex: 1; }
  .entry .kind { font-weight: 600; }
  .entry .when { color: var(--secondary-text-color); font-size: 0.9em; }
  .end { font: inherit; padding: 6px 14px; border-radius: 16px; cursor: pointer;
    border: 1px solid var(--divider-color); background: transparent; color: var(--primary-text-color); }
  .empty, .error { color: var(--secondary-text-color); padding: 8px 0; }
  .error { color: var(--error-color, #db4437); }
`;

class SecurityAlertsCard extends HTMLElement {
  constructor() {
    super();
    this._choices = {};
    for (const section of SECTIONS) {
      this._choices[section.kind] = { types: new Set(), cameras: new Set(), hours: null, busy: false };
    }
    this._options = null;
    this._retryAt = 0;
    this._lastState = undefined;
  }

  static getStubConfig() {
    return { entity: DEFAULT_ENTITY };
  }

  setConfig(config) {
    this._config = { entity: DEFAULT_ENTITY, ...(config || {}) };
  }

  getCardSize() {
    return 8;
  }

  set hass(hass) {
    this._hass = hass;
    if (!this._root) this._build();
    const complete = this._options && this._options.cameras.length;
    if (!complete && !this._loading && Date.now() >= this._retryAt) this._loadOptions();
    const state = hass.states[this._config.entity];
    if (state !== this._lastState) {
      this._lastState = state;
      this._renderRunning();
    }
  }

  _build() {
    this._root = this.attachShadow({ mode: "open" });
    this._sections = {};
    for (const section of SECTIONS) this._sections[section.kind] = h("section");
    this._running = h("div");
    this._root.append(
      h("style", { text: STYLE }),
      h("ha-card", { header: "Security alerts" }, [
        ...SECTIONS.map((s) => this._sections[s.kind]),
        h("section", {}, [h("h2", { text: "Running" }), this._running]),
      ]),
    );
    for (const section of SECTIONS) {
      this._sections[section.kind].replaceChildren(h("h2", { text: section.title }), h("div", { class: "empty", text: "Loading…" }));
    }
  }

  async _loadOptions() {
    this._loading = true;
    this._retryAt = Date.now() + OPTIONS_RETRY_MS;
    try {
      this._options = await this._hass.callWS({ type: "security_alerts/types" });
      for (const section of SECTIONS) {
        const choice = this._choices[section.kind];
        if (choice.hours === null) choice.hours = this._options.durations[0];
        this._renderSection(section);
      }
      this._renderRunning();
    } catch (err) {
      if (!this._options) {
        for (const section of SECTIONS) {
          this._sections[section.kind].replaceChildren(
            h("h2", { text: section.title }),
            h("div", { class: "error", text: `Unavailable: ${err.message || err}` }),
          );
        }
      }
    } finally {
      this._loading = false;
    }
  }

  _chip(text, pressed, onclick, disabled = false) {
    return h("button", { class: "chip", "aria-pressed": String(pressed), text, onclick, disabled });
  }

  _renderSection(section) {
    const choice = this._choices[section.kind];
    const rerender = () => this._renderSection(section);
    const toggle = (set, id) => () => {
      if (set.has(id)) set.delete(id);
      else set.add(id);
      rerender();
    };
    const cameraTypesPicked = [...choice.types].some((t) => !SENSOR_TYPES.has(t));
    const types = this._options.types.map((t) => this._chip(t.name, choice.types.has(t.id), toggle(choice.types, t.id)));
    const cameras = [
      this._chip("All cameras", choice.cameras.size === 0, () => {
        choice.cameras.clear();
        rerender();
      }, !cameraTypesPicked),
      ...this._options.cameras.map((c) =>
        this._chip(c.name, choice.cameras.has(c.id), toggle(choice.cameras, c.id), !cameraTypesPicked),
      ),
    ];
    const durations = this._options.durations.map((hours) =>
      this._chip(`${hours} h`, hours === choice.hours, () => {
        choice.hours = hours;
        rerender();
      }),
    );
    const go = h("button", {
      class: "go",
      text: `Start ${section.title.toLowerCase()}`,
      disabled: choice.busy || choice.types.size === 0,
      onclick: () => this._start(section),
    });
    this._sections[section.kind].replaceChildren(
      h("h2", { text: section.title }),
      h("div", { class: "hint", text: section.hint }),
      h("div", { class: "label", text: "Types" }),
      h("div", { class: "chips" }, types),
      h("div", { class: "label", text: "Cameras (camera types only)" }),
      h("div", { class: "chips" }, cameras),
      h("div", { class: "label", text: "For" }),
      h("div", { class: "chips" }, durations),
      go,
    );
  }

  async _start(section) {
    const choice = this._choices[section.kind];
    choice.busy = true;
    this._renderSection(section);
    try {
      await this._hass.callWS({
        type: "security_alerts/quiet/add",
        kind: section.kind,
        types: [...choice.types],
        cameras: [...choice.cameras],
        hours: choice.hours,
      });
      choice.types.clear();
      choice.cameras.clear();
    } catch (err) {
      this._toast(`Could not start ${section.title.toLowerCase()}: ${err.message || err}`);
    } finally {
      choice.busy = false;
      this._renderSection(section);
    }
  }

  _toast(message) {
    this.dispatchEvent(new CustomEvent("hass-notification", { detail: { message }, bubbles: true, composed: true }));
  }

  _name(list, id) {
    const found = (list || []).find((x) => x.id === id);
    return found ? found.name : id.replace(/_/g, " ");
  }

  _renderRunning() {
    if (!this._running) return;
    const state = this._lastState;
    if (!state) {
      this._running.replaceChildren(h("div", { class: "error", text: `${this._config.entity} is not available.` }));
      return;
    }
    const entries = state.attributes.entries || [];
    if (!entries.length) {
      this._running.replaceChildren(h("div", { class: "empty", text: "Nothing running." }));
      return;
    }
    const opts = this._options || {};
    this._running.replaceChildren(
      ...entries.map((entry) => {
        const types = entry.types.map((t) => this._name(opts.types, t)).join(", ");
        const cameras = entry.cameras.length ? entry.cameras.map((c) => this._name(opts.cameras, c)).join(", ") : "";
        const end = h("button", { class: "end", text: "End", onclick: () => this._end(entry.id, end) });
        return h("div", { class: "entry" }, [
          h("div", { class: "what" }, [
            h("div", {}, [h("span", { class: "kind", text: KIND_NAMES[entry.kind] || entry.kind }), ` · ${types}`]),
            h("div", { class: "when", text: [cameras, untilText(entry.ends_at)].filter(Boolean).join(" · ") }),
          ]),
          end,
        ]);
      }),
    );
  }

  async _end(entryId, button) {
    button.disabled = true;
    try {
      await this._hass.callWS({ type: "security_alerts/quiet/end", entry_id: entryId });
    } catch (err) {
      this._toast(`Could not end it: ${err.message || err}`);
      button.disabled = false;
    }
  }
}

if (!customElements.get("security-alerts-card")) {
  customElements.define("security-alerts-card", SecurityAlertsCard);
}
window.customCards = window.customCards || [];
if (!window.customCards.some((c) => c.type === "security-alerts-card")) {
  window.customCards.push({
    type: "security-alerts-card",
    name: "Security alerts",
    description: "Do not disturb, Pause, and the running quiet entries of the security alerts.",
  });
}
