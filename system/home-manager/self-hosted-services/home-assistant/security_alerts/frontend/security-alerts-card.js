// Security alerts card: start a Do-not-disturb or a Pause for some types (optionally only some
// cameras) for a set time, and see or end every running Pause, Do-not-disturb and Snooze.
//
//   type: custom:security-alerts-card
//   entity: sensor.security_alerts_quiet   # optional, this is the default
//
// Loaded as a dashboard resource by the security_alerts integration. This file holds no data.
// The pickers follow the mode that is on, Home when no away mode is, and offer only the types
// each kind changes there: Do not disturb the ones that can ring critical, Pause the ones that
// notify. Each tab's quick buttons start it for every type and camera for 1 h or 2 h in one
// tap. Styled like the Bubble Card buttons.

const DEFAULT_ENTITY = "sensor.security_alerts_quiet";
// Types and cameras come from Frigate's config, which may not be loaded yet; ask again
// this long after a failure or an answer with no cameras.
const OPTIONS_RETRY_MS = 30000;
const SENSOR_TYPES = new Set(["door", "motion"]);
const KIND_NAMES = { pause: "Pause", dnd: "Do not disturb", snooze: "Snooze" };
const KIND_ICONS = { pause: "mdi:bell-off", dnd: "mdi:bell-sleep", snooze: "mdi:alarm-snooze" };
// The quick buttons' hours; they start a kind for every type and camera.
const QUICK_HOURS = [1, 2];
// A tab's running request: Start, or the hours of the quick button pressed.
const START = "start";
const FORMS = [
  {
    kind: "dnd",
    hint: (mode) => `These can ring critical in ${mode}. Picked types follow the phone's silent mode.`,
    none: (mode) => `Nothing is critical in ${mode}.`,
  },
  {
    kind: "pause",
    hint: (mode) => `These notify in ${mode}. Picked types send nothing.`,
    none: (mode) => `Nothing sends a notification in ${mode}.`,
  },
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

// Pill surfaces, icon bubbles and kind colours come from the theme (Bubble Card's own
// variables first), so light and dark themes both work.
const STYLE = `
  :host {
    --sa-surface: var(--bubble-main-background-color, var(--background-color-2, var(--secondary-background-color)));
    --sa-bubble: var(--bubble-icon-background-color, var(--card-background-color, var(--ha-card-background)));
    --sa-dnd: var(--indigo-color, #3f51b5);
    --sa-pause: var(--deep-orange-color, #ff6f22);
    --sa-snooze: var(--blue-grey-color, #607d8b);
    --kind: var(--primary-color);
  }
  ha-card { padding: 12px; color: var(--primary-text-color); }
  .k-dnd { --kind: var(--sa-dnd); }
  .k-pause { --kind: var(--sa-pause); }
  .k-snooze { --kind: var(--sa-snooze); }
  button { font: inherit; border: 0; cursor: pointer; -webkit-tap-highlight-color: transparent; }
  button:disabled { cursor: default; }
  .bubble { flex: none; display: flex; align-items: center; justify-content: center; border-radius: 50%;
    background: color-mix(in srgb, var(--kind) 18%, transparent); color: var(--kind); }
  .head { display: flex; align-items: center; gap: 10px; }
  .head .bubble { width: 42px; height: 42px; --kind: var(--primary-color); --mdc-icon-size: 24px; }
  .head > div { min-width: 0; }
  .title { font-size: 15px; font-weight: 600; line-height: 20px; }
  .sub { font-size: 13px; line-height: 18px; color: var(--secondary-text-color); min-height: 18px; }
  .switch { display: grid; grid-template-columns: 1fr 1fr; gap: 4px; height: 44px; box-sizing: border-box;
    margin-top: 12px; padding: 4px; border-radius: 22px; background: var(--sa-surface); }
  .seg { display: flex; align-items: center; justify-content: center; gap: 6px; min-width: 0; padding: 0 8px;
    border-radius: 18px; background: transparent; color: var(--primary-text-color); font-size: 14px;
    font-weight: 500; white-space: nowrap; --mdc-icon-size: 18px; }
  .seg[aria-pressed="true"] { background: var(--kind); color: #fff; }
  .hint, .note { font-size: 13px; line-height: 18px; color: var(--secondary-text-color); margin: 8px 4px 0; }
  .note.error { color: var(--error-color, #db4437); }
  .label { font-size: 12px; line-height: 16px; color: var(--secondary-text-color); margin: 12px 4px 6px; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { display: inline-flex; align-items: center; gap: 6px; height: 36px; box-sizing: border-box;
    max-width: 100%; padding: 0 14px 0 10px; border-radius: 18px; background: var(--sa-surface);
    color: var(--primary-text-color); font-size: 14px; --mdc-icon-size: 18px; }
  .chip span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .chip.text { padding: 0 14px; }
  .chip[aria-pressed="true"] { background: var(--kind); color: #fff; }
  .chip.quick { background: color-mix(in srgb, var(--kind) 18%, transparent); color: var(--kind); }
  .chip.quick:disabled { opacity: 0.5; }
  .go { display: flex; align-items: center; justify-content: center; gap: 8px; width: 100%; height: 44px;
    margin-top: 14px; border-radius: 22px; background: var(--kind); color: #fff; font-size: 15px;
    font-weight: 600; --mdc-icon-size: 20px; }
  .go:disabled { opacity: 0.4; }
  .running-head { display: flex; align-items: center; justify-content: space-between; margin: 16px 4px 8px; }
  .running-head .label { margin: 0; }
  .count { display: inline-flex; align-items: center; justify-content: center; min-width: 24px; height: 20px;
    box-sizing: border-box; padding: 0 8px; border-radius: 10px; background: var(--sa-surface);
    font-size: 12px; font-weight: 600; }
  .running { display: grid; gap: 6px; }
  .entry { display: flex; align-items: center; gap: 10px; min-height: 56px; box-sizing: border-box;
    padding: 9px 12px 9px 9px; border-radius: 28px; background: var(--sa-surface); }
  .entry.dim { opacity: 0.6; }
  .entry .bubble { width: 38px; height: 38px; --mdc-icon-size: 20px; }
  .what { flex: 1; min-width: 0; overflow-wrap: anywhere; }
  .what .main { font-size: 13px; font-weight: 600; line-height: 18px; }
  .what .detail { font-size: 12px; line-height: 16px; color: var(--secondary-text-color); }
  .end { flex: none; height: 32px; padding: 0 14px; border-radius: 16px; background: var(--sa-bubble);
    color: var(--primary-text-color); font-size: 13px; font-weight: 500; }
  .end:disabled { opacity: 0.5; }
`;

class SecurityAlertsCard extends HTMLElement {
  constructor() {
    super();
    this._choices = {};
    for (const form of FORMS) {
      this._choices[form.kind] = { types: new Set(), cameras: new Set(), hours: null, busy: null };
    }
    // The picked switch segment; kept in memory only.
    this._segment = FORMS[0];
    this._options = null;
    this._error = null;
    this._retryAt = 0;
    this._lastState = undefined;
    // The mode the card shows: one of _options.modes, or _options.home when no away mode is
    // on; null until the types load.
    this._mode = null;
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
    // The pickers and the no-effect marks follow the mode live, without a reload.
    const mode = this._activeMode();
    const state = hass.states[this._config.entity];
    if (mode === this._mode && state === this._lastState) return;
    if (mode !== this._mode) this._showMode(mode);
    this._lastState = state;
    this._renderRunning();
  }

  _build() {
    this._root = this.attachShadow({ mode: "open" });
    this._sub = h("div", { class: "sub" });
    this._form = h("div", { class: "form" });
    this._count = h("span", { class: "count", text: "0" });
    this._running = h("div", { class: "running" });
    this._root.append(
      h("style", { text: STYLE }),
      h("ha-card", {}, [
        h("div", { class: "head" }, [
          h("div", { class: "bubble" }, h("ha-icon", { icon: "mdi:shield-home" })),
          h("div", {}, [h("div", { class: "title", text: "Security alerts" }), this._sub]),
        ]),
        this._form,
        h("div", { class: "running-head" }, [h("span", { class: "label", text: "Running" }), this._count]),
        this._running,
      ]),
    );
    this._renderForm();
  }

  async _loadOptions() {
    this._loading = true;
    this._retryAt = Date.now() + OPTIONS_RETRY_MS;
    try {
      this._options = await this._hass.callWS({ type: "security_alerts/types" });
      this._error = null;
      for (const form of FORMS) {
        const choice = this._choices[form.kind];
        if (choice.hours === null) choice.hours = this._options.durations[0];
      }
      this._showMode(this._activeMode());
      this._renderRunning();
    } catch (err) {
      if (!this._options) {
        this._error = `Unavailable: ${err.message || err}`;
        this._renderForm();
      }
    } finally {
      this._loading = false;
    }
  }

  // The highest away mode that is on (the modes come in ladder order), else Home; null until
  // the types load.
  _activeMode() {
    if (!this._options) return null;
    const away = this._options.modes.find((mode) => {
      const state = this._hass.states[mode.entity];
      return state && state.state === "on";
    });
    return away || this._options.home;
  }

  // Shows `mode`: unpicks the types it no longer offers and re-renders the form.
  _showMode(mode) {
    this._mode = mode;
    for (const form of FORMS) {
      const offered = new Set(this._offered(form.kind).map((t) => t.id));
      const picked = this._choices[form.kind].types;
      for (const id of picked) if (!offered.has(id)) picked.delete(id);
    }
    this._renderForm();
  }

  // The types a kind changes in the shown mode: what its picker offers.
  _offered(kind) {
    const kinds = new Set(this._mode.changes[kind] || []);
    return this._options.types.filter((t) => kinds.has(t.kind));
  }

  // An entry has an effect when one of its types has a kind its kind changes in the shown
  // mode. A type the card does not know counts as having one, so nothing is wrongly marked.
  _hasEffect(entry) {
    const kinds = new Set(this._mode.changes[entry.kind] || []);
    return entry.types.some((id) => {
      const type = this._options.types.find((t) => t.id === id);
      return !type || kinds.has(type.kind);
    });
  }

  _chip(text, icon, pressed, onclick) {
    return h("button", { class: icon ? "chip" : "chip text", "aria-pressed": String(pressed), onclick }, [
      icon && h("ha-icon", { icon }),
      h("span", { text }),
    ]);
  }

  _renderForm() {
    const note = (text, error = false) => h("div", { class: error ? "note error" : "note", text });
    if (!this._options) {
      this._form.replaceChildren(this._error ? note(this._error, true) : note("Loading…"));
      return;
    }
    const mode = this._mode;
    const form = this._segment;
    const choice = this._choices[form.kind];
    const rerender = () => this._renderForm();
    this._form.className = `form k-${form.kind}`;
    const segments = FORMS.map((f) =>
      h(
        "button",
        {
          class: `seg k-${f.kind}`,
          "aria-pressed": String(f.kind === form.kind),
          onclick: () => {
            this._segment = f;
            rerender();
          },
        },
        [h("ha-icon", { icon: KIND_ICONS[f.kind] }), h("span", { text: KIND_NAMES[f.kind] })],
      ),
    );
    const switcher = h("div", { class: "switch", role: "group" }, segments);
    const quick = [
      h("div", { class: "label", text: "Quick" }),
      h(
        "div",
        { class: "chips" },
        QUICK_HOURS.map((hours) =>
          h(
            "button",
            { class: "chip quick", disabled: choice.busy !== null, onclick: () => this._quick(form.kind, hours) },
            [
              h("ha-icon", { icon: KIND_ICONS[form.kind] }),
              h("span", { text: choice.busy === hours ? "Starting…" : `All · ${hours} h` }),
            ],
          ),
        ),
      ),
    ];
    const offered = this._offered(form.kind);
    if (!offered.length) {
      this._form.replaceChildren(switcher, note(form.none(mode.name)), ...quick);
      return;
    }
    const toggle = (set, id) => () => {
      if (set.has(id)) set.delete(id);
      else set.add(id);
      rerender();
    };
    const types = offered.map((t) => this._chip(t.name, t.icon, choice.types.has(t.id), toggle(choice.types, t.id)));
    const cameraTypesPicked = [...choice.types].some((t) => !SENSOR_TYPES.has(t));
    const cameras = cameraTypesPicked && [
      h("div", { class: "label", text: "Cameras" }),
      h("div", { class: "chips" }, [
        this._chip("All cameras", "mdi:cctv", choice.cameras.size === 0, () => {
          choice.cameras.clear();
          rerender();
        }),
        ...this._options.cameras.map((c) =>
          this._chip(c.name, "mdi:cctv", choice.cameras.has(c.id), toggle(choice.cameras, c.id)),
        ),
      ]),
    ];
    const durations = this._options.durations.map((hours) =>
      this._chip(`${hours} h`, null, hours === choice.hours, () => {
        choice.hours = hours;
        rerender();
      }),
    );
    const go = h(
      "button",
      {
        class: "go",
        disabled: choice.busy !== null || choice.types.size === 0,
        onclick: () => this._start(form.kind),
      },
      [
        h("ha-icon", { icon: KIND_ICONS[form.kind] }),
        h("span", { text: choice.busy === START ? "Starting…" : `${KIND_NAMES[form.kind]} for ${choice.hours} h` }),
      ],
    );
    this._form.replaceChildren(
      switcher,
      h("div", { class: "hint", text: form.hint(mode.name) }),
      ...quick,
      h("div", { class: "label", text: "Types" }),
      h("div", { class: "chips" }, types),
      ...(cameras || []),
      h("div", { class: "label", text: "For" }),
      h("div", { class: "chips" }, durations),
      go,
    );
  }

  // Starts the picked types and cameras; success clears the picks.
  _start(kind) {
    const choice = this._choices[kind];
    const request = { types: [...choice.types], cameras: [...choice.cameras], hours: choice.hours };
    return this._add(kind, START, request, () => {
      choice.types.clear();
      choice.cameras.clear();
    });
  }

  // A quick button: every known type, door and motion too whatever the mode offers, so a mode
  // change while it runs lets nothing through. Every camera. The picks stay as they are.
  _quick(kind, hours) {
    const types = this._options.types.map((t) => t.id);
    return this._add(kind, hours, { types, cameras: [], hours });
  }

  // Sends one quiet/add for a tab. While it runs, the tab's quick buttons and Start are
  // disabled and the pressed one (`busy`) reads "Starting…".
  async _add(kind, busy, request, onDone = () => {}) {
    const choice = this._choices[kind];
    choice.busy = busy;
    this._renderForm();
    try {
      await this._hass.callWS({ type: "security_alerts/quiet/add", kind, ...request });
      onDone();
    } catch (err) {
      this._toast(`Could not start ${KIND_NAMES[kind].toLowerCase()}: ${err.message || err}`);
    } finally {
      choice.busy = null;
      this._renderForm();
    }
  }

  _toast(message) {
    this.dispatchEvent(new CustomEvent("hass-notification", { detail: { message }, bubbles: true, composed: true }));
  }

  _name(list, id) {
    const found = (list || []).find((x) => x.id === id);
    return found ? found.name : id.replace(/_/g, " ");
  }

  _row(kind, icon, main, detail, action, dim = false) {
    return h("div", { class: `entry k-${kind}${dim ? " dim" : ""}` }, [
      h("div", { class: "bubble" }, h("ha-icon", { icon })),
      h("div", { class: "what" }, [h("div", { class: "main", text: main }), detail && h("div", { class: "detail", text: detail })]),
      action,
    ]);
  }

  // The header's second line, the running count and the running list.
  _renderRunning() {
    const state = this._lastState;
    const entries = (state && state.attributes.entries) || [];
    const mode = this._mode;
    if (mode) {
      const running = entries.length ? `${entries.length} running` : "nothing running";
      this._sub.textContent = `${mode.name} · ${running}`;
    }
    this._count.textContent = String(entries.length);
    if (!state) {
      this._running.replaceChildren(h("div", { class: "note error", text: `${this._config.entity} is not available.` }));
      return;
    }
    if (!entries.length) {
      this._running.replaceChildren(this._row("none", "mdi:check", "Nothing running"));
      return;
    }
    const opts = this._options || {};
    const typeIds = (opts.types || []).map((t) => t.id);
    // Before the types load, nothing is marked and every type is named.
    this._running.replaceChildren(
      ...entries.map((entry) => {
        const all = typeIds.length > 0 && typeIds.every((id) => entry.types.includes(id));
        const types = all ? "All types" : entry.types.map((t) => this._name(opts.types, t)).join(", ");
        const cameras = entry.cameras.length ? entry.cameras.map((c) => this._name(opts.cameras, c)).join(", ") : "";
        const noEffect = mode !== null && !this._hasEffect(entry);
        const detail = [cameras, untilText(entry.ends_at), noEffect && `No effect in ${mode.name}`];
        const end = h("button", { class: "end", text: "End", onclick: () => this._end(entry.id, end) });
        return this._row(
          entry.kind,
          KIND_ICONS[entry.kind] || "mdi:bell",
          `${KIND_NAMES[entry.kind] || entry.kind} · ${types}`,
          detail.filter(Boolean).join(" · "),
          end,
          noEffect,
        );
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
