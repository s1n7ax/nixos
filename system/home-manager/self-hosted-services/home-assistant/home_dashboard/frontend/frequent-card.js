// The Frequent tab: the office on a plan, with the air drawn from the AC to the spot it
// is cooling, the spots to tap on and off, the AC's fan and louvers, each spot's aim and
// the two office lights. Look: Night — dark, quiet, warm light and cool air.

const AC = "climate.panasonic_ac_panasonic_ac";
const STATUS = "sensor.air_zones_status";
const AUTOMATION = "switch.air_zones_automation";
const ROOM_TEMP = "sensor.t_office_tempeture_sensor_temperature";
const LIGHTS = [
  { entity: "light.b_office_srinesh", name: "Srinesh" },
  { entity: "light.b_office_nidu", name: "Nidu" },
];
// Spots on the plan (viewBox 0 0 100 64): their outline, where the air lands, and their switch.
const SPOTS = {
  my_desk: { name: "My desk", rect: [3, 3, 37, 12], air: [21, 10] },
  bed: { name: "Bed", rect: [24, 19, 72, 22], air: [62, 30] },
  wife_desk: { name: "Wife's desk", rect: [3, 46, 40, 14], air: [17, 52] },
};
// The bed's aim while s1n7ax sleeps: left and middle, away from the pillows.
const AIRS = { ...Object.fromEntries(Object.entries(SPOTS).map(([k, s]) => [k, s.air])), bed_sleep: [44, 30] };
const AIM_NAMES = { my_desk: "My desk", bed: "Bed", bed_sleep: "Bed asleep", wife_desk: "Wife's desk" };
const AC_AT = [54, 56];
const FANS = ["low", "medium", "high", "auto"];
const VERTICAL = ["V0", "V1", "V2", "V3", "V4", "V5"];
const HORIZONTAL = ["H0", "H1", "H2", "H3", "H4", "H5"];
const louver = (m) => (m.endsWith("0") ? "Swing" : m.slice(1));

const ICON = {
  bulb: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a7 7 0 0 0-4 12.74V17a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1v-2.26A7 7 0 0 0 12 2M9 21a1 1 0 0 0 1 1h4a1 1 0 0 0 1-1v-1H9z"/></svg>`,
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
    return [AC, STATUS, AUTOMATION, ROOM_TEMP, ...LIGHTS.map((l) => l.entity), ...Object.keys(SPOTS).map((k) => `switch.air_zones_${k}`),
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
    if (t.dataset.action === "brightness") {
      this.call("light", "turn_on", { entity_id: t.dataset.entity, brightness_pct: Number(t.value) });
    }
  }

  acOn() {
    const s = this._hass.states[AC]?.state;
    return !!s && !["off", "unavailable", "unknown"].includes(s);
  }

  statusLine(status, ac) {
    const a = status?.attributes ?? {};
    const names = (a.targets ?? []).map((t) => AIM_NAMES[t]);
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
    const target = this.acOn() ? a.target : null;
    const fan = states[AC]?.attributes.fan_mode;
    const spots = Object.entries(SPOTS).map(([k, s]) => {
      const on = states[`switch.air_zones_${k}`]?.state === "on";
      const [x, y, w, h] = s.rect;
      return `<g class="spot ${on ? "on" : ""}" data-action="spot" data-spot="${k}">
        <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2"/>
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
      <text class="label" x="96" y="24" text-anchor="end">door</text>
      ${spots}
      <g class="pillows"><rect x="91" y="21.5" width="3.2" height="7" rx="1"/><rect x="91" y="31.5" width="3.2" height="7" rx="1"/></g>
      ${air}
      <g class="ac ${this.acOn() ? "on" : ""}" data-action="power"><rect x="38" y="56.5" width="32" height="5" rx="1.5"/>
        <text x="54" y="60.2">AC</text></g>
    </svg>`;
  }

  render() {
    const states = this._hass.states;
    const ac = states[AC];
    const status = states[STATUS];
    const auto = states[AUTOMATION]?.state === "on";
    const room = Number(states[ROOM_TEMP]?.state);
    const on = this.acOn();
    const attrs = ac?.attributes ?? {};
    const seg = (action, modes, current, label = (m) => m) => modes.map((m) =>
      `<button class="${m === current ? "sel" : ""}" data-action="${action}" data-mode="${m}" ${on || action === "aim" ? "" : "disabled"}>${label(m)}</button>`).join("");
    const aim = (axis) => states[`select.air_zones_${this.tuning}_${axis}`]?.state;
    this.shadowRoot.innerHTML = `<style>${CSS}</style>
      <div class="page">
        <header>
          <div>
            <h1>${Number.isFinite(room) ? `${room.toFixed(1)}°` : "—"}<small>office</small></h1>
            <p class="status">${escape(this.statusLine(status, ac))}</p>
          </div>
          <div class="head-right">
            <button class="power ${on ? "on" : ""}" data-action="power" aria-label="AC power">${ICON.power}</button>
            <span class="setpoint">${on && attrs.temperature != null ? `${attrs.temperature}° set` : "off"}</span>
          </div>
        </header>
        <section class="plan-wrap">${this.plan(states, status)}<p class="hint">Tap a spot to cool it, tap the AC to switch it.</p></section>
        <section class="panel ac-panel">
          <div class="row"><span>Automation</span>
            <button class="toggle ${auto ? "on" : ""}" data-action="auto" role="switch" aria-checked="${auto}"><i></i></button></div>
          <div class="row col"><span>Fan</span><div class="seg">${seg("fan", FANS, attrs.fan_mode)}</div></div>
          <div class="row col"><span>Up · down</span><div class="seg">${seg("v", VERTICAL, attrs.swing_mode, louver)}</div></div>
          <div class="row col"><span>Left · right</span><div class="seg">${seg("h", HORIZONTAL, attrs.swing_horizontal_mode, louver)}</div></div>
          ${auto ? `<p class="hint">A change here holds for an hour, then the automation takes over.</p>` : ""}
        </section>
        <section class="panel aim-panel">
          <div class="row col"><span>Aim for</span><div class="seg tabs">${Object.entries(AIM_NAMES).map(([k, n]) =>
            `<button class="${k === this.tuning ? "sel" : ""}" data-action="tune" data-aim="${k}">${n}</button>`).join("")}</div></div>
          <div class="row col"><span>Up · down</span><div class="seg">${seg("aim", VERTICAL, aim("vertical"), louver).replaceAll('data-mode', 'data-axis="vertical" data-mode')}</div></div>
          <div class="row col"><span>Left · right</span><div class="seg">${seg("aim", HORIZONTAL, aim("horizontal"), louver).replaceAll('data-mode', 'data-axis="horizontal" data-mode')}</div></div>
        </section>
        <section class="lights">${LIGHTS.map((l) => this.lightHtml(l, states[l.entity])).join("")}</section>
      </div>`;
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
  .head-right { display: grid; justify-items: center; gap: 6px; }
  .power { width: 52px; height: 52px; border-radius: 50%; border: 1px solid var(--line); background: var(--glass); display: grid; place-items: center; color: var(--muted); }
  .power svg { width: 24px; }
  .power.on { color: #0d0f11; background: var(--cool); border-color: var(--cool); box-shadow: 0 0 24px rgba(124,199,255,.35); }
  .setpoint { font-size: 12px; color: var(--muted); }
  .plan-wrap { grid-area: plan; }
  .plan { width: 100%; display: block; background: rgba(255,255,255,.015); border: 1px solid var(--line); border-radius: 16px; }
  .room { fill: none; stroke: #39404a; stroke-width: .6; }
  .door { stroke: var(--bg); stroke-width: 1.4; }
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
