// The Frequent tab: the office on a plan, with the air drawn from the AC to the spot it
// is cooling, the spots to tap on and off, the AC's fan and louvers, each spot's aim and
// the two office lights, and the water pump. Look: Night — dark, quiet, warm light and cool air.

const AC = "climate.panasonic_ac_panasonic_ac";
const STATUS = "sensor.air_zones_status";
const AUTOMATION = "switch.air_zones_automation";
const ROOM_TEMP = "sensor.t_office_tempeture_sensor_temperature";
// Fills the tank in about 30 minutes; an HA automation turns it off after 30.
const PUMP = "switch.p_water_pump";
const PUMP_MINUTES = 30;
const LIGHTS = [
  { entity: "light.b_office_srinesh", name: "Srinesh" },
  { entity: "light.b_office_nidu", name: "Nidu" },
];
// Spots on the plan (viewBox 0 0 100 64): their outline, where the air lands, and their switch.
const SPOTS = {
  my_desk: { name: "My desk", rect: [3, 3, 37, 12], air: [24, 12] },
  bed: { name: "Bed", rect: [52, 18, 44, 26], air: [78, 37] },
  wife_desk: { name: "Wife's desk", rect: [3, 46, 34, 14], air: [26, 49] },
};
// The bed's aim while s1n7ax sleeps: left and middle, away from the pillows.
const AIRS = { ...Object.fromEntries(Object.entries(SPOTS).map(([k, s]) => [k, s.air])), bed_sleep: [64, 37] };
const AIM_NAMES = { my_desk: "My desk", bed: "Bed", bed_sleep: "Bed asleep", wife_desk: "Wife's desk" };
const AC_AT = [54, 56];
// The MirAIe AC's modes; the AC's own lists win when it reports them. "off" is not a fan speed.
const FANS = ["low", "medium", "high", "auto"];
const VERTICAL = ["V0", "V1", "V2", "V3", "V4", "V5"];
const HORIZONTAL = ["H0", "H1", "H2", "H3", "H4", "H5"];
// Each louver position drawn as the way the air leaves: up/down seen from the side (1 level,
// 5 straight down), left/right seen from above as on the plan (1 right, 3 ahead, 5 left), and
// 0, the AC's own swing, as a sweeping arc.
const AT = { V: { ac: '<rect x="1.5" y="3" width="6" height="4" rx="1"/>', from: [8, 6], swing: [0, 90] },
  H: { ac: '<rect x="7" y="18.5" width="10" height="3.5" rx="1"/>', from: [12, 17], swing: [-140, -40] } };
const pt = ([x, y], deg, r) => [x + r * Math.cos((deg * Math.PI) / 180), y + r * Math.sin((deg * Math.PI) / 180)].map((v) => +v.toFixed(2));
// An arrowhead at `tip`, pointing along `deg`.
const head = (tip, deg) => `M${pt(tip, deg + 145, 4.5)} L${tip} L${pt(tip, deg - 145, 4.5)}`;
const LOUVER_ICON = (axis, n) => {
  const { ac, from, swing } = AT[axis];
  if (n === 0) {
    const [a, b] = swing.map((d) => pt(from, d, 13));
    return `${ac}<path d="M${a} A13 13 0 0 1 ${b} ${head(a, swing[0] - 90)} ${head(b, swing[1] + 90)}"/>`;
  }
  // Up/down: 1 level to 5 straight down. Left/right, as on the plan: 1 far right, 3 ahead, 5 far left.
  const deg = axis === "V" ? 8 + (n - 1) * 18 : -90 + (3 - n) * 27;
  const tip = pt(from, deg, 13);
  return `${ac}<path d="M${from} L${tip} ${head(tip, deg)}"/>`;
};
const louver = (m) => {
  const n = Number(m.slice(1));
  return `<svg class="louver" viewBox="0 0 24 24" aria-hidden="true">${LOUVER_ICON(m[0], n)}</svg>`;
};
const louverName = (m) => {
  const n = Number(m.slice(1));
  if (n === 0) return "Swing";
  return m[0] === "V" ? ["Level", "Slightly down", "Down", "Further down", "Straight down"][n - 1]
    : ["Far right", "Right", "Ahead", "Left", "Far left"][n - 1];
};

const ICON = {
  bulb: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a7 7 0 0 0-4 12.74V17a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1v-2.26A7 7 0 0 0 12 2M9 21a1 1 0 0 0 1 1h4a1 1 0 0 0 1-1v-1H9z"/></svg>`,
  pump: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 3.2s-6 6.6-6 10.8a6 6 0 0 0 12 0c0-4.2-6-10.8-6-10.8m0 15.3a4.5 4.5 0 0 1-4.5-4.5h2a2.5 2.5 0 0 0 2.5 2.5z"/></svg>`,
  power: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M13 3h-2v10h2zm4.83 2.17-1.42 1.42A6.92 6.92 0 0 1 19 12a7 7 0 1 1-11.42-5.42L6.17 5.17A9 9 0 1 0 21 12a8.94 8.94 0 0 0-3.17-6.83"/></svg>`,
};

const escape = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const clock = (iso) => new Date(iso).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });

class FrequentCard extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this.tuning = "my_desk";
    this.shadowRoot.addEventListener("click", (ev) => this.onClick(ev));
    this.shadowRoot.addEventListener("change", (ev) => this.onChange(ev));
  }

  setConfig(config) {
    this.config = config;
  }

  getCardSize() {
    return 12;
  }

  set hass(hass) {
    this._hass = hass;
    // Only the entities the card shows: a render resets a brightness slider mid-drag.
    const key = this.watched().map((id) => {
      const s = hass.states[id];
      return s ? `${s.state}|${s.last_updated}` : "";
    }).join(",");
    if (key !== this.key) {
      this.key = key;
      this.render();
    }
  }

  watched() {
    return [AC, STATUS, AUTOMATION, ROOM_TEMP, PUMP, ...LIGHTS.map((l) => l.entity), ...Object.keys(SPOTS).map((k) => `switch.air_zones_${k}`),
      ...Object.keys(AIM_NAMES).flatMap((k) => [`select.air_zones_${k}_vertical`, `select.air_zones_${k}_horizontal`])];
  }

  call(domain, service, data) {
    this._hass.callService(domain, service, data);
  }

  onClick(ev) {
    const t = ev.target.closest("[data-action]");
    if (!t) return;
    const d = t.dataset;
    switch (d.action) {
      case "all-power": return this.allPower();
      case "pump": return this.pump();
      case "confirm-yes": { const run = this.confirming.run; this.confirming = null; this.render(); return run(); }
      case "confirm-no": this.confirming = null; return this.render();
      case "spot": return this.call("switch", "toggle", { entity_id: `switch.air_zones_${d.spot}` });
      case "power": return this.call("climate", this.acOn() ? "turn_off" : "turn_on", { entity_id: AC });
      case "auto": return this.call("switch", "toggle", { entity_id: AUTOMATION });
      case "fan": return this.call("climate", "set_fan_mode", { entity_id: AC, fan_mode: d.mode });
      case "v": return this.call("climate", "set_swing_mode", { entity_id: AC, swing_mode: d.mode });
      case "h": return this.call("climate", "set_swing_horizontal_mode", { entity_id: AC, swing_horizontal_mode: d.mode });
      case "tune": this.tuning = d.aim; return this.render();
      case "aim": return this.call("select", "select_option", { entity_id: `select.air_zones_${this.tuning}_${d.axis}`, option: d.mode });
      case "light": return this.call("light", "toggle", { entity_id: d.entity });
    }
  }

  onChange(ev) {
    const t = ev.target;
    if (t.dataset.action === "fan") {
      const speeds = (this._hass.states[AC]?.attributes.fan_modes ?? FANS).filter((m) => !["off", "auto"].includes(m));
      this.call("climate", "set_fan_mode", { entity_id: AC, fan_mode: speeds[Number(t.value)] });
    } else if (t.dataset.action === "brightness") {
      this.call("light", "turn_on", { entity_id: t.dataset.entity, brightness_pct: Number(t.value) });
    }
  }

  // Off takes the office lights with it; on brings back only the AC.
  allPower() {
    if (!this.acOn()) return this.call("climate", "turn_on", { entity_id: AC });
    this.call("climate", "turn_off", { entity_id: AC });
    this.call("light", "turn_off", { entity_id: LIGHTS.map((l) => l.entity) });
  }

  // Stopping the pump early, or filling a tank that was filled in the last day, is asked first.
  async pump() {
    if (this._hass.states[PUMP]?.state === "on") {
      return this.ask("Turn off the water pump?", "The tank may not be full yet.", "Turn off", () => this.call("switch", "turn_off", { entity_id: PUMP }));
    }
    let ran;
    try {
      ran = await this.lastPumpRun();
    } catch {
      return this.ask("Turn on the water pump?", "Couldn't check when it last ran.", "Turn on", () => this.call("switch", "turn_on", { entity_id: PUMP }));
    }
    if (!ran) return this.call("switch", "turn_on", { entity_id: PUMP });
    const when = ran.toDateString() === new Date().toDateString() ? `today at ${clock(ran)}` : `yesterday at ${clock(ran)}`;
    this.ask("Run the water pump again?", `It already ran ${when}. The tank is probably still full.`, "Turn on", () => this.call("switch", "turn_on", { entity_id: PUMP }));
  }

  // When the pump last started in the past 24 hours, or null.
  async lastPumpRun() {
    const start = new Date(Date.now() - 24 * 3600 * 1000);
    const res = await this._hass.callWS({ type: "history/history_during_period", start_time: start.toISOString(),
      entity_ids: [PUMP], minimal_response: true, no_attributes: true, significant_changes_only: false });
    const runs = (res[PUMP] ?? []).filter((e) => e.s === "on");
    return runs.length ? new Date(Math.max(start.getTime(), runs.at(-1).lu * 1000)) : null;
  }

  ask(title, text, yes, run) {
    this.confirming = { title, text, yes, run };
    this.render();
  }

  acOn() {
    const s = this._hass.states[AC]?.state;
    return !!s && !["off", "unavailable", "unknown"].includes(s);
  }

  statusLine(status, ac) {
    const a = status?.attributes ?? {};
    const names = (a.targets ?? []).map((t) => SPOTS[t === "bed_sleep" ? "bed" : t].name);
    switch (status?.state) {
      case "ac_off": return ac?.state === "unavailable" ? "AC unreachable" : "AC is off";
      case "paused": return "Automation off · you're steering";
      case "holding": return `Keeping your change until ${clock(a.hold_until)}`;
      case "idle": return "No spot needs air";
      case "aimed": return `Cooling ${names[0]}${a.asleep_since ? (a.fan === "low" ? " · gentle" : " · asleep") : ""}`;
      case "sweeping": return `Sweeping ${names.join(" → ")}`;
      default: return "Air zones not loaded";
    }
  }

  plan(states, status) {
    const a = status?.attributes ?? {};
    // The air is drawn only while the automation steers: on hold or paused the louvers are someone's.
    const target = this.acOn() && ["aimed", "sweeping"].includes(status?.state) ? a.target : null;
    const fan = states[AC]?.attributes.fan_mode;
    const spots = Object.entries(SPOTS).map(([k, s]) => {
      const on = states[`switch.air_zones_${k}`]?.state === "on";
      const [x, y, w, h] = s.rect;
      return `<g class="spot ${on ? "on" : ""}" data-action="spot" data-spot="${k}">
        <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2"/>
        ${k === "bed" ? "" : `<rect class="desk" x="${x + 2}" y="${y + 1.5}" width="${w - 4}" height="2.4" rx=".6"/>
        <circle class="chair" cx="${x + w - 5}" cy="${y + h / 2 + 1}" r="2"/>`}
        <text x="${x + w / 2}" y="${y + h / 2 + 1.4}">${s.name}</text></g>`;
    }).join("");
    let air = "";
    if (target && AIRS[target]) {
      const [x, y] = AIRS[target];
      const [ax, ay] = AC_AT;
      const width = { low: 0.6, medium: 0.9, high: 1.3 }[fan] ?? 1;
      const path = `M${ax} ${ay} Q ${(ax + x) / 2 + (x < ax ? 8 : -8)} ${(ay + y) / 2} ${x} ${y}`;
      air = `<g class="air ${fan === "low" ? "slow" : ""}" style="--w:${width}">
        <path d="${path}"/><path d="${path}" class="b"/><path d="${path}" class="c"/>
        <circle cx="${x}" cy="${y}" r="3.2"/></g>`;
    }
    return `<svg class="plan" viewBox="0 0 100 64" role="img" aria-label="Office plan">
      <rect class="room" x="1" y="1" width="98" height="62" rx="1.5"/>
      <path class="door" d="M99 6 V18"/>
      <path class="swing" d="M99 6 L89 6 A10 10 0 0 1 99 16"/>
      <text class="label" x="88" y="10" text-anchor="end">door</text>
      ${spots}
      <path class="blanket" d="M58 19 V43"/>
      <g class="pillows"><rect x="91" y="22.5" width="3.2" height="8" rx="1"/><rect x="91" y="32" width="3.2" height="8" rx="1"/></g>
      ${air}
      <g class="ac ${this.acOn() ? "on" : ""}" data-action="power"><rect x="38" y="56.5" width="32" height="5" rx="1.5"/>
        <path class="vent" d="M41 57.8 H48 M60 57.8 H67"/>
        <text x="54" y="60.6">AC</text></g>
    </svg>`;
  }

  render() {
    const states = this._hass.states;
    const ac = states[AC];
    const status = states[STATUS];
    const auto = states[AUTOMATION]?.state === "on";
    const room = Number(states[ROOM_TEMP]?.state);
    const on = this.acOn();
    const pump = states[PUMP];
    const ask = this.confirming;
    const attrs = ac?.attributes ?? {};
    // The AC's own controls are disabled while it is off; the aims are not.
    const seg = (action, modes, current, attrs = on ? "" : "disabled") => modes.map((m) =>
      `<button class="${m === current ? "sel" : ""}" data-action="${action}" data-mode="${m}" title="${louverName(m)}" aria-label="${louverName(m)}" ${attrs}>${louver(m)}</button>`).join("");
    const aim = (axis) => states[`select.air_zones_${this.tuning}_${axis}`]?.state;
    // The slider runs through the AC's speeds; auto sits beside it, as it is not a speed.
    const speeds = (attrs.fan_modes ?? FANS).filter((m) => !["off", "auto"].includes(m));
    const fanAuto = attrs.fan_mode === "auto";
    const speed = speeds.indexOf(attrs.fan_mode);
    const vertical = attrs.swing_modes ?? VERTICAL;
    const horizontal = attrs.swing_horizontal_modes ?? HORIZONTAL;
    this.shadowRoot.innerHTML = `<style>${CSS}</style>
      <div class="page">
        <header>
          <div>
            <h1>${Number.isFinite(room) ? `${room.toFixed(1)}°` : "—"}<small>office</small></h1>
            <p class="status">${escape(this.statusLine(status, ac))}</p>
          </div>
          <div class="head-right">
            <div class="head-button">
              <button class="power pump ${pump?.state === "on" ? "on" : ""}" data-action="pump" aria-label="Water pump" ${pump && pump.state !== "unavailable" ? "" : "disabled"}>${ICON.pump}</button>
              <span class="setpoint">${pump?.state === "on" ? `Pump till ${clock(new Date(new Date(pump.last_changed).getTime() + PUMP_MINUTES * 60000))}` : "Pump"}</span>
            </div>
            <div class="head-button">
              <button class="power ${on ? "on" : ""}" data-action="all-power" aria-label="AC and office lights power">${ICON.power}</button>
              <span class="setpoint">${on && attrs.temperature != null ? `${attrs.temperature}° set` : "off"}</span>
            </div>
          </div>
        </header>
        <section class="plan-wrap">${this.plan(states, status)}<p class="hint">Tap a spot to cool it, tap the AC to switch it.</p></section>
        <section class="panel ac-panel">
          <div class="row"><span>Automation</span>
            <button class="toggle ${auto ? "on" : ""}" data-action="auto" role="switch" aria-checked="${auto}"><i></i></button></div>
          <div class="row col"><span>Fan</span><div class="fan ${fanAuto ? "auto" : ""}">
            <div class="slider"><input type="range" min="0" max="${speeds.length - 1}" step="1" value="${Math.max(speed, 0)}" data-action="fan" aria-label="Fan speed" ${on ? "" : "disabled"}>
              <div class="ticks">${speeds.map((m) => `<span class="${m === attrs.fan_mode ? "sel" : ""}">${m}</span>`).join("")}</div></div>
            <button class="chip ${fanAuto ? "sel" : ""}" data-action="fan" data-mode="auto" ${on ? "" : "disabled"}>Auto</button></div></div>
          <div class="row col"><span>Up · down</span><div class="seg">${seg("v", vertical, attrs.swing_mode)}</div></div>
          <div class="row col"><span>Left · right</span><div class="seg">${seg("h", horizontal, attrs.swing_horizontal_mode)}</div></div>
          ${auto ? `<p class="hint">A change here holds for an hour, then the automation takes over.</p>` : ""}
        </section>
        <section class="panel aim-panel">
          <div class="row col"><span>Aim for</span><div class="seg tabs">${Object.entries(AIM_NAMES).map(([k, n]) =>
            `<button class="${k === this.tuning ? "sel" : ""}" data-action="tune" data-aim="${k}">${n}</button>`).join("")}</div></div>
          <div class="row col"><span>Up · down</span><div class="seg">${seg("aim", VERTICAL, aim("vertical"), 'data-axis="vertical"')}</div></div>
          <div class="row col"><span>Left · right</span><div class="seg">${seg("aim", HORIZONTAL, aim("horizontal"), 'data-axis="horizontal"')}</div></div>
          <p class="hint">Where the automation points the air when it cools ${AIM_NAMES[this.tuning].toLowerCase()}.</p>
        </section>
        <section class="lights">${LIGHTS.map((l) => this.lightHtml(l, states[l.entity])).join("")}</section>
      </div>
      ${ask ? `<div class="scrim" data-action="confirm-no"><div class="dialog" data-action="dialog" role="alertdialog" aria-modal="true" aria-label="${escape(ask.title)}">
        <h2>${escape(ask.title)}</h2><p>${escape(ask.text)}</p>
        <div class="actions"><button data-action="confirm-no">Cancel</button><button class="yes" data-action="confirm-yes">${escape(ask.yes)}</button></div>
      </div></div>` : ""}`;
  }

  lightHtml(l, st) {
    const on = st?.state === "on";
    const pct = on ? Math.round(((st.attributes.brightness ?? 255) / 255) * 100) : 0;
    const rgb = st?.attributes.rgb_color;
    const glow = on ? `rgb(${(rgb ?? [255, 181, 77]).join(",")})` : "";
    return `<div class="light ${on ? "on" : ""} ${st && st.state !== "unavailable" ? "" : "gone"}" style="${glow ? `--glow:${glow}` : ""}">
      <button data-action="light" data-entity="${l.entity}" aria-label="Toggle ${l.name}">
        <i>${ICON.bulb}</i><b>${l.name}</b><small>${on ? `${pct}%` : st?.state === "unavailable" ? "Unavailable" : "Off"}</small></button>
      <input type="range" min="1" max="100" value="${pct || 1}" data-action="brightness" data-entity="${l.entity}" aria-label="${l.name} brightness" ${on ? "" : "disabled"}>
    </div>`;
  }
}

const CSS = `
  :host {
    --bg: #0d0f11; --glass: rgba(24,27,31,.78); --line: rgba(255,255,255,.08); --ink: #e9ebee; --muted: #7d8590;
    --warm: #ffb54d; --cool: #7cc7ff;
    display: block; background: radial-gradient(120% 70% at 50% 20%, #181b1f 0%, var(--bg) 70%); color: var(--ink);
    font: 14px/1.4 Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif; -webkit-font-smoothing: antialiased;
    min-height: calc(100dvh - var(--header-height, 56px));
  }
  * { box-sizing: border-box; }
  button { font: inherit; color: inherit; background: none; border: 0; cursor: pointer; padding: 0; }
  button:disabled { opacity: .35; cursor: default; }
  .page { max-width: 1180px; margin: 0 auto; padding: 20px 16px 32px; display: grid; gap: 14px;
    grid-template-columns: minmax(0, 1fr); grid-template-areas: "head" "plan" "lights" "ac" "aim"; }
  header { grid-area: head; display: flex; justify-content: space-between; align-items: flex-start; }
  h1 { margin: 0; font-size: 44px; font-weight: 300; letter-spacing: -.03em; line-height: 1; font-variant-numeric: tabular-nums; }
  h1 small { font-size: 13px; color: var(--muted); letter-spacing: 0; margin-left: 8px; font-weight: 400; }
  .status { margin: 10px 0 0; color: var(--cool); font-size: 14px; }
  .head-right { display: flex; gap: 14px; }
  .head-button { display: grid; justify-items: center; gap: 6px; }
  .power.pump.on { background: #5fb0ff; border-color: #5fb0ff; }
  .scrim { position: fixed; inset: 0; z-index: 10; background: rgba(0,0,0,.55); display: grid; place-items: center; padding: 16px; }
  .dialog { width: min(360px, 100%); background: #181b1f; border: 1px solid var(--line); border-radius: 16px; padding: 20px; box-shadow: 0 20px 60px rgba(0,0,0,.5); }
  .dialog h2 { margin: 0 0 6px; font-size: 17px; font-weight: 600; }
  .dialog p { margin: 0 0 18px; color: var(--muted); }
  .actions { display: flex; justify-content: flex-end; gap: 8px; }
  .actions button { padding: 10px 16px; border-radius: 10px; border: 1px solid var(--line); color: var(--ink); }
  .actions .yes { background: var(--cool); border-color: var(--cool); color: #0d0f11; }
  .power { width: 52px; height: 52px; border-radius: 50%; border: 1px solid var(--line); background: var(--glass); display: grid; place-items: center; color: var(--muted); }
  .power svg { width: 24px; }
  .power.on { color: #0d0f11; background: var(--cool); border-color: var(--cool); box-shadow: 0 0 24px rgba(124,199,255,.35); }
  .setpoint { font-size: 12px; color: var(--muted); }
  .plan-wrap { grid-area: plan; }
  .plan { width: 100%; display: block; }
  .room { fill: rgba(255,255,255,.015); stroke: #39404a; stroke-width: .6; }
  .door { stroke: var(--bg); stroke-width: 1.4; }
  .swing { fill: none; stroke: #39404a; stroke-width: .3; stroke-dasharray: 1 1; }
  .desk { fill: #2a3038; stroke: none; } .chair { fill: none; stroke: #4a525c; stroke-width: .3; }
  .spot.on .desk { fill: rgba(124,199,255,.35); }
  .blanket { stroke: #3a4149; stroke-width: .3; }
  .vent { stroke: #4a525c; stroke-width: .3; } .ac.on .vent { stroke: var(--cool); }
  .label { fill: var(--muted); font-size: 2.4px; }
  .spot rect { fill: rgba(255,255,255,.03); stroke: #3a4149; stroke-width: .4; transition: fill .3s, stroke .3s; }
  .spot text, .ac text { fill: var(--muted); font-size: 3px; text-anchor: middle; pointer-events: none; }
  .spot { cursor: pointer; }
  .spot.on rect { fill: rgba(124,199,255,.12); stroke: var(--cool); }
  .spot.on text { fill: var(--ink); }
  .pillows rect { fill: #2a3038; stroke: #4a525c; stroke-width: .3; }
  .ac rect { fill: #1d2126; stroke: #4a525c; stroke-width: .4; cursor: pointer; }
  .ac.on rect { stroke: var(--cool); fill: rgba(124,199,255,.18); }
  .ac.on text { fill: var(--cool); }
  .air path { fill: none; stroke: var(--cool); stroke-width: calc(var(--w) * 1px); stroke-linecap: round; stroke-dasharray: 2 5; opacity: .85; animation: flow 1.1s linear infinite; }
  .air path.b { opacity: .45; transform: translate(-1.5px, 1px); animation-delay: -.4s; }
  .air path.c { opacity: .3; transform: translate(1.5px, -1px); animation-delay: -.8s; }
  .air.slow path { animation-duration: 2.6s; }
  .air circle { fill: rgba(124,199,255,.18); stroke: var(--cool); stroke-width: .3; animation: land 2s ease-out infinite; transform-box: fill-box; transform-origin: center; }
  @keyframes flow { to { stroke-dashoffset: -14; } }
  @keyframes land { from { transform: scale(.6); opacity: 1; } to { transform: scale(1.5); opacity: 0; } }
  @media (prefers-reduced-motion: reduce) { .air path, .air circle { animation: none; } }
  .hint { color: var(--muted); font-size: 12px; margin: 8px 2px 0; }
  .panel { background: var(--glass); border: 1px solid var(--line); border-radius: 16px; padding: 14px; display: grid; gap: 12px; }
  .ac-panel { grid-area: ac; } .aim-panel { grid-area: aim; }
  .row { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  .row.col { flex-direction: column; align-items: stretch; gap: 6px; }
  .row > span { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: .06em; }
  .seg { display: flex; gap: 4px; }
  .seg button { flex: 1; min-width: 0; padding: 10px 2px; border-radius: 10px; border: 1px solid var(--line); color: var(--muted); font-size: 13px; text-transform: capitalize; white-space: nowrap; }
  .seg button.sel { color: #0d0f11; background: var(--cool); border-color: var(--cool); }
  .seg.tabs button.sel { background: var(--ink); border-color: var(--ink); }
  .seg button:has(.louver) { padding: 6px 2px; display: grid; place-items: center; }
  .louver { width: 28px; height: 28px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
  .louver rect { fill: currentColor; stroke: none; opacity: .5; }
  .fan { display: flex; align-items: flex-start; gap: 12px; }
  .slider { flex: 1; min-width: 0; }
  .slider input { width: 100%; margin: 8px 0 4px; accent-color: var(--cool); }
  .fan.auto .slider input { accent-color: var(--muted); opacity: .5; }
  .ticks { display: flex; justify-content: space-between; color: var(--muted); font-size: 12px; text-transform: capitalize; }
  .ticks span.sel { color: var(--cool); }
  .chip { padding: 8px 14px; border-radius: 999px; border: 1px solid var(--line); color: var(--muted); font-size: 13px; }
  .chip.sel { color: #0d0f11; background: var(--cool); border-color: var(--cool); }
  .toggle { width: 48px; height: 28px; border-radius: 999px; background: #2a2f36; position: relative; transition: background .2s; }
  .toggle i { position: absolute; top: 3px; left: 3px; width: 22px; height: 22px; border-radius: 50%; background: #9aa3ad; transition: transform .2s, background .2s; }
  .toggle.on { background: rgba(124,199,255,.35); } .toggle.on i { transform: translateX(20px); background: var(--cool); }
  .lights { grid-area: lights; display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .light { background: var(--glass); border: 1px solid var(--line); border-radius: 16px; padding: 14px; display: grid; gap: 10px; transition: box-shadow .3s, border-color .3s; }
  .light button { display: grid; grid-template-columns: auto 1fr; grid-template-rows: auto auto; column-gap: 10px; text-align: left; align-items: center; }
  .light i { grid-row: span 2; width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center; background: #23272d; color: var(--muted); }
  .light i svg { width: 22px; }
  .light small { color: var(--muted); }
  .light.on { border-color: color-mix(in srgb, var(--glow) 45%, transparent); box-shadow: 0 0 32px -8px var(--glow); }
  .light.on i { background: var(--glow); color: #111; }
  .light.gone { opacity: .45; }
  .light input { width: 100%; accent-color: var(--warm); }
  @media (min-width: 900px) {
    .page { padding: 32px 32px 40px; gap: 18px; grid-template-columns: minmax(0, 1.6fr) minmax(300px, 1fr);
      grid-template-areas: "head head" "plan ac" "plan aim" "lights aim"; align-items: start; }
    h1 { font-size: 56px; }
  }`;

customElements.define("frequent-card", FrequentCard);
