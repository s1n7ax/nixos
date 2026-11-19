// The Frequent tab: the office drawn in 3D (room-3d.js) with everything for the AC on it, the
// way a car shows its climate: the air streams from the AC to where it lands and is dragged to
// aim it, the spots light up and are tapped on and off, and the fan, swing, settings and
// automation sit in the room's bar under the AC. Settings turns the same room into setting each
// profile's aim. The ceiling lights are tapped on the room too, and their cards stay below.
// Look: Night — dark, quiet, warm light and cool air.

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
// The room in plan units (5 cm), as room-3d.js draws it, and the spots' tap areas around their
// furniture.
const PLAN = [103.6, 67.1];
const SPOTS = {
  my_desk: { name: "My desk", rect: [3, 2.5, 36, 25] },
  bed: { name: "Bed", rect: [56, 19, 46, 29] },
  wife_desk: { name: "Wife's desk", rect: [3, 41, 36, 24] },
};
// The profiles the automation aims with; the bed has its own while s1n7ax sleeps.
const AIM_NAMES = { my_desk: "My desk", bed: "Bed", bed_sleep: "Bed asleep", wife_desk: "Wife's desk" };
// Ceiling lights, where room-3d.js hangs them.
const LIGHT_AT = { "light.b_office_srinesh": [51.8, 12], "light.b_office_nidu": [51.8, 55] };
const AC_AT = [54, 62];
// Where the air lands for a louver position: left/right picks a column (5 far left … 1 far
// right, as the louver icons draw it), up/down a row (1 level, reaching the far wall … 5 straight
// down, by the AC). 0 is the AC's own swing across that axis.
const COLUMNS = [94, 73, 52, 31, 10];
const ROWS = [9, 20.5, 32, 43.5, 55];
const landing = (v, h) => [COLUMNS[(h || 3) - 1], ROWS[(v || 3) - 1]];
const nearest = (list, value) => list.reduce((best, x, i) => (Math.abs(x - value) < Math.abs(list[best] - value) ? i : best), 0) + 1;
const curve = ([x, y]) => {
  const [ax, ay] = AC_AT;
  return `M${ax} ${ay} Q ${(ax + x) / 2 + (x < ax ? 8 : -8)} ${(ay + y) / 2} ${x} ${y}`;
};
// The MirAIe AC's modes; the AC's own lists win when it reports them. "off" is not a fan speed.
const FANS = ["low", "medium", "high", "auto"];
// The AC's own swing on an axis, drawn as a sweeping arc: up/down seen from the side, left/right
// seen from above as on the plan.
const AT = { V: { ac: '<rect x="1.5" y="3" width="6" height="4" rx="1"/>', from: [8, 6], swing: [0, 90] },
  H: { ac: '<rect x="7" y="18.5" width="10" height="3.5" rx="1"/>', from: [12, 17], swing: [-140, -40] } };
const pt = ([x, y], deg, r) => [x + r * Math.cos((deg * Math.PI) / 180), y + r * Math.sin((deg * Math.PI) / 180)].map((v) => +v.toFixed(2));
// An arrowhead at `tip`, pointing along `deg`.
const head = (tip, deg) => `M${pt(tip, deg + 145, 4.5)} L${tip} L${pt(tip, deg - 145, 4.5)}`;
const swingIcon = (axis) => {
  const { ac, from, swing } = AT[axis];
  const [a, b] = swing.map((d) => pt(from, d, 13));
  return `<svg class="louver" viewBox="0 0 24 24" aria-hidden="true">${ac}<path d="M${a} A13 13 0 0 1 ${b} ${head(a, swing[0] - 90)} ${head(b, swing[1] + 90)}"/></svg>`;
};
// A louver mode the plan knows: V/H 0–5.
const known = (m) => /^[VH][0-5]$/.test(m);

const ICON = {
  gear: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8m0 6a2 2 0 1 1 0-4 2 2 0 0 1 0 4m7.43-1.02a7.6 7.6 0 0 0 0-1.96l2.11-1.65a.5.5 0 0 0 .12-.64l-2-3.46a.5.5 0 0 0-.61-.22l-2.49 1a7.3 7.3 0 0 0-1.69-.98l-.38-2.65A.49.49 0 0 0 14 2h-4a.49.49 0 0 0-.49.42l-.38 2.65c-.61.25-1.17.58-1.69.98l-2.49-1a.5.5 0 0 0-.61.22l-2 3.46a.49.49 0 0 0 .12.64l2.11 1.65a7.9 7.9 0 0 0 0 1.96l-2.11 1.65a.5.5 0 0 0-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.58 1.69-.98l2.49 1c.23.09.49 0 .61-.22l2-3.46a.5.5 0 0 0-.12-.64z"/></svg>`,
  check: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>`,
  auto: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20m0 18a8 8 0 1 1 0-16 8 8 0 0 1 0 16m.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>`,
  bulb: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 2a7 7 0 0 0-4 12.74V17a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1v-2.26A7 7 0 0 0 12 2M9 21a1 1 0 0 0 1 1h4a1 1 0 0 0 1-1v-1H9z"/></svg>`,
  pump: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 3.2s-6 6.6-6 10.8a6 6 0 0 0 12 0c0-4.2-6-10.8-6-10.8m0 15.3a4.5 4.5 0 0 1-4.5-4.5h2a2.5 2.5 0 0 0 2.5 2.5z"/></svg>`,
  power: `<svg viewBox="0 0 24 24"><path fill="currentColor" d="M13 3h-2v10h2zm4.83 2.17-1.42 1.42A6.92 6.92 0 0 1 19 12a7 7 0 1 1-11.42-5.42L6.17 5.17A9 9 0 1 0 21 12a8.94 8.94 0 0 0-3.17-6.83"/></svg>`,
};

// A light's colour while it is on, or null.
const lightColor = (st) => (st?.state === "on" ? (st.attributes.rgb_color ?? [255, 181, 77]) : null);
const escape = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const clock = (iso) => new Date(iso).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });

// The room in 3D under the plan, one for every card: HA rebuilds cards on view and dashboard
// changes, and each would hold a WebGL context. Without WebGL the plan stays flat. Loaded at
// the card's own version, as the files are served with long cache headers.
let room;
const room3d = () => (room ??= import(`./room-3d.js${new URL(import.meta.url).search}`).then(({ Room3D }) => new Room3D()));

class FrequentCard extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this.tuning = "my_desk";
    this.setup = false;
    this.shadowRoot.addEventListener("click", (ev) => this.onClick(ev));
    this.shadowRoot.addEventListener("pointerdown", (ev) => this.dragStart(ev));
    this.shadowRoot.addEventListener("pointermove", (ev) => this.dragMove(ev));
    this.shadowRoot.addEventListener("pointerup", (ev) => this.dragEnd(ev, true));
    this.shadowRoot.addEventListener("pointercancel", (ev) => this.dragEnd(ev, false));
    this.shadowRoot.addEventListener("change", (ev) => this.onChange(ev));
    // From auto the slider sits on the lowest speed, and picking that fires no change (nor, on a
    // touch screen, a click), so letting go of it sends the speed unless change just did.
    this.shadowRoot.addEventListener("pointerup", (ev) => {
      const t = ev.target;
      // A disabled slider (AC off) still gets pointerup.
      if (t.dataset?.action !== "fan-speed" || t.disabled) return;
      setTimeout(() => {
        const sent = Date.now() - (this.fanSentAt ?? 0) < 1000;
        if (!sent && this._hass.states[AC]?.attributes.fan_mode === "auto") this.setSpeed(t);
      }, 150);
    });
    this.resized = new ResizeObserver(() => this.drawRoom());
  }

  connectedCallback() {
    this.resized.observe(this);
    room3d().then((room) => {
      this.room3d = room;
      this.drawRoom();
    }).catch((err) => console.warn("frequent-card: no 3D room", err));
  }

  disconnectedCallback() {
    this.resized.disconnect();
  }

  // A render replaces the plan's box, so the canvas moves into the new one; it keeps its picture,
  // so it is drawn again only when its size or the AC changes.
  drawRoom() {
    const box = this.shadowRoot.querySelector(".room3d");
    if (!this.room3d || !box || !box.clientWidth) return;
    if (this.room3d.canvas.parentNode !== box) box.replaceChildren(this.room3d.canvas);
    const states = this._hass.states;
    const shown = {
      acOn: this.acOn(),
      spots: Object.keys(SPOTS).filter((k) => states[`switch.air_zones_${k}`]?.state === "on"),
      lights: Object.fromEntries(LIGHTS.map(({ entity }) => [entity, lightColor(states[entity])])),
    };
    const look = JSON.stringify([box.clientWidth, window.devicePixelRatio, shown]);
    if (look !== this.room3d.look) {
      this.room3d.look = look;
      this.room3d.draw(box.clientWidth, shown);
    }
    this.shadowRoot.querySelector(".plan-box").classList.add("solid");
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
      // A render mid-drag would drop the stream being dragged; it waits for the drop.
      if (this.drag) this.drag.stale = true;
      else this.render();
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
      case "spot":
        if (!this.setup) return this.call("switch", "toggle", { entity_id: `switch.air_zones_${d.spot}` });
        this.tuning = d.spot;
        return this.render();
      case "setup": this.setup = !this.setup; return this.render();
      case "power": return this.call("climate", this.acOn() ? "turn_off" : "turn_on", { entity_id: AC });
      case "auto": return this.call("switch", "toggle", { entity_id: AUTOMATION });
      case "fan": return this.call("climate", "set_fan_mode", { entity_id: AC, fan_mode: d.mode });
      case "swing": {
        // Swing on an axis is its 0; off goes back to the middle of it.
        const [v, h] = this.aim();
        return this.aimAt(d.axis === "V" ? (v ? 0 : 3) : v, d.axis === "H" ? (h ? 0 : 3) : h);
      }
      case "tune": this.tuning = d.aim; return this.render();
      case "light": return this.call("light", "toggle", { entity_id: d.entity });
    }
  }

  // The louver positions shown: the AC's own, or in settings the profile's. A mode the drawings
  // don't know (not V/H 0–5) is drawn at the middle.
  aim() {
    const states = this._hass.states;
    const modes = this.setup
      ? ["vertical", "horizontal"].map((axis) => states[`select.air_zones_${this.tuning}_${axis}`]?.state)
      : [states[AC]?.attributes.swing_mode, states[AC]?.attributes.swing_horizontal_mode];
    const aim = modes.map((m) => (m && known(m) ? Number(m.slice(1)) : 3));
    // A dropped aim stays drawn until HA reports it, for at most 15 s, so the air doesn't jump back.
    const sent = this.sent;
    if (sent && sent.of === this.aimOf() && Date.now() < sent.until && sent.aim.join() !== aim.join()) return sent.aim;
    this.sent = null;
    return aim;
  }

  aimOf() {
    return this.setup ? this.tuning : "ac";
  }

  // Sends only the axes that change: each is its own call, and the AC answers each.
  aimAt(v, h) {
    const [cv, ch] = this.aim();
    this.sent = { of: this.aimOf(), aim: [v, h], until: Date.now() + 15000 };
    if (this.setup) {
      if (v !== cv) this.call("select", "select_option", { entity_id: `select.air_zones_${this.tuning}_vertical`, option: `V${v}` });
      if (h !== ch) this.call("select", "select_option", { entity_id: `select.air_zones_${this.tuning}_horizontal`, option: `H${h}` });
      return;
    }
    if (v !== cv) this.call("climate", "set_swing_mode", { entity_id: AC, swing_mode: `V${v}` });
    if (h !== ch) this.call("climate", "set_swing_horizontal_mode", { entity_id: AC, swing_horizontal_mode: `H${h}` });
  }

  // Dragging the air's landing point snaps it to the nearest louver position and sends it on drop.
  // It starts only once the pointer moves: a tap on the handle goes to whatever is under it.
  dragStart(ev) {
    const handle = ev.target.closest?.(".handle");
    if (!handle || (!this.setup && !this.acOn())) return;
    ev.preventDefault();
    handle.setPointerCapture(ev.pointerId);
    this.drag = { id: ev.pointerId, svg: handle.ownerSVGElement, from: [ev.clientX, ev.clientY], moved: false };
  }

  dragMove(ev) {
    const drag = this.drag;
    if (!drag || ev.pointerId !== drag.id) return;
    if (!drag.moved && Math.hypot(ev.clientX - drag.from[0], ev.clientY - drag.from[1]) < 6) return;
    drag.moved = true;
    drag.svg.classList.add("dragging");
    const p = new DOMPoint(ev.clientX, ev.clientY).matrixTransform(drag.svg.getScreenCTM().inverse());
    const x = Math.min(Math.max(p.x, 0), PLAN[0]);
    const y = Math.min(Math.max(p.y, 0), PLAN[1]);
    drag.aim = [nearest(ROWS, y), nearest(COLUMNS, x)];
    const air = drag.svg.querySelector(".air");
    const at = landing(...drag.aim);
    air.classList.remove("sweep");
    for (const path of air.querySelectorAll("path")) path.setAttribute("d", curve(at));
    air.querySelectorAll("animate").forEach((a) => a.remove());
    for (const c of air.querySelectorAll("circle")) c.setAttribute("cx", at[0]), c.setAttribute("cy", at[1]);
    const handle = drag.svg.querySelector(".handle");
    handle.setAttribute("transform", `translate(${at[0]} ${at[1]})`);
  }

  dragEnd(ev, drop) {
    const drag = this.drag;
    if (!drag || ev.pointerId !== drag.id) return;
    this.drag = null;
    if (!drag.moved) {
      // A tap: the spot, light or AC under the handle gets it.
      const under = this.shadowRoot.elementsFromPoint(ev.clientX, ev.clientY).find((el) => !el.closest(".handle") && el.closest("[data-action]"));
      if (drag.stale) this.render();
      if (drop && under) this.onClick({ target: under });
      return;
    }
    if (drop) this.aimAt(...drag.aim);
    this.render();
  }

  setSpeed(input) {
    const speeds = (this._hass.states[AC]?.attributes.fan_modes ?? FANS).filter((m) => !["off", "auto"].includes(m));
    this.call("climate", "set_fan_mode", { entity_id: AC, fan_mode: speeds[Number(input.value)] });
  }

  onChange(ev) {
    const t = ev.target;
    if (t.dataset.action === "fan-speed") {
      this.fanSentAt = Date.now();
      this.setSpeed(t);
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

  // The air from the AC to where it lands: an animated stream, a landing ring and the handle to
  // drag it by. A swinging axis sweeps the stream across its row or column.
  air(fan) {
    const [v, h] = this.aim();
    const steps = (n) => (n ? [n] : [1, 2, 3, 4, 5, 4, 3, 2]);
    const vs = steps(v);
    const hs = steps(h);
    const frames = Array.from({ length: Math.max(vs.length, hs.length) }, (_, i) => landing(vs[i % vs.length], hs[i % hs.length]));
    const at = landing(v, h);
    const sweep = frames.length > 1;
    const loop = [...frames, frames[0]];
    const anim = (attr, values) => (sweep ? `<animate attributeName="${attr}" dur="${frames.length * 1.4}s" repeatCount="indefinite" values="${values.join(";")}"/>` : "");
    const d = anim("d", loop.map(curve));
    const width = { low: 0.6, medium: 0.9, high: 1.3 }[fan] ?? 1;
    const ring = `<circle cx="${at[0]}" cy="${at[1]}" r="3.2">${anim("cx", loop.map((p) => p[0]))}${anim("cy", loop.map((p) => p[1]))}</circle>`;
    const grid = ROWS.flatMap((y) => COLUMNS.map((x) => `<circle cx="${x}" cy="${y}" r=".7"/>`)).join("");
    return `<g class="grid">${grid}</g>
      <g class="air ${fan === "low" ? "slow" : ""} ${sweep ? "sweep" : ""} ${this.setup ? "setup" : ""}" style="--w:${width}">
        <path d="${curve(at)}">${d}</path><path d="${curve(at)}" class="b">${d}</path><path d="${curve(at)}" class="c">${d}</path>${ring}</g>
      <g class="handle" transform="translate(${at[0]} ${at[1]})" role="slider" aria-label="Drag to aim the air"><circle class="hit" r="7"/><circle class="knob" r="2.4"/></g>`;
  }

  plan(states) {
    const on = this.acOn();
    const fan = states[AC]?.attributes.fan_mode;
    const spots = Object.entries(SPOTS).map(([k, s]) => {
      const active = states[`switch.air_zones_${k}`]?.state === "on";
      const picked = this.setup && (this.tuning === k || (k === "bed" && this.tuning === "bed_sleep"));
      const [x, y, w, h] = s.rect;
      return `<g class="spot ${active ? "on" : ""} ${picked ? "picked" : ""}" data-action="spot" data-spot="${k}" role="button" aria-label="${s.name}" aria-pressed="${active}">
        <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2"/>
        <text x="${x + 1.8}" y="${y + 4}">${s.name}</text></g>`;
    }).join("");
    const lights = LIGHTS.map(({ entity, name }) => {
      const [x, y] = LIGHT_AT[entity];
      const lit = states[entity]?.state === "on";
      return `<g class="ceiling ${lit ? "on" : ""}" data-action="light" data-entity="${entity}" role="button" aria-label="Toggle ${name} light" aria-pressed="${lit}">
        <circle cx="${x}" cy="${y}" r="5.5"/><text x="${x + 6}" y="${y + 1}">${name}</text></g>`;
    }).join("");
    // In settings the profile's air shows whether or not the AC runs; live, only while it runs.
    const air = this.setup || on ? this.air(fan) : "";
    return `<div class="plan-box ${this.setup ? "setup" : ""}"><div class="room3d"></div>
      <svg class="plan" viewBox="0 0 ${PLAN.join(" ")}" role="img" aria-label="Office plan">
      <rect class="room" x="1" y="1" width="${PLAN[0] - 2}" height="${PLAN[1] - 2}" rx="1.5"/>
      ${spots}
      ${lights}
      <g class="ac ${on ? "on" : ""}" data-action="power" role="button" aria-label="AC power"><rect x="43" y="60" width="22" height="7" rx="1.5"/>
        <text x="67" y="65">AC</text></g>
      ${air}
    </svg></div>`;
  }

  // The bar under the room, beside the AC: fan and swing for what the room shows, then settings
  // and the automation.
  bar(states) {
    const on = this.acOn();
    const attrs = states[AC]?.attributes ?? {};
    const auto = states[AUTOMATION]?.state === "on";
    const [v, h] = this.aim();
    // Live the AC's controls are disabled while it is off; a profile is set either way.
    const off = this.setup || on ? "" : "disabled";
    const swing = (axis, value, label) =>
      `<button class="chip icon ${value === 0 ? "sel" : ""}" data-action="swing" data-axis="${axis}" aria-pressed="${value === 0}" aria-label="Swing ${label}" title="Swing ${label}" ${off}>${swingIcon(axis)}</button>`;
    // The slider runs through the AC's speeds; auto sits beside it, as it is not a speed.
    const speeds = (attrs.fan_modes ?? FANS).filter((m) => !["off", "auto"].includes(m));
    const fanAuto = attrs.fan_mode === "auto";
    const speed = speeds.indexOf(attrs.fan_mode);
    const fan = this.setup
      ? `<div class="profiles">${Object.entries(AIM_NAMES).map(([k, n]) =>
          `<button class="${k === this.tuning ? "sel" : ""}" data-action="tune" data-aim="${k}" aria-pressed="${k === this.tuning}">${n}</button>`).join("")}</div>`
      : `<div class="fan ${fanAuto ? "auto" : ""}">
          <div class="slider"><input type="range" min="0" max="${speeds.length - 1}" step="1" value="${Math.max(speed, 0)}" data-action="fan-speed" aria-label="Fan speed" ${off}>
            <div class="ticks">${speeds.map((m) => `<span class="${m === attrs.fan_mode ? "sel" : ""}">${m}</span>`).join("")}</div></div>
          <button class="chip ${fanAuto ? "sel" : ""}" data-action="fan" data-mode="auto" ${off}>Auto</button></div>`;
    return `<div class="bar">
      ${fan}
      <div class="tools">
        ${swing("V", v, "up and down")}${swing("H", h, "left and right")}
        <span class="gap"></span>
        <button class="chip icon ${this.setup ? "sel" : ""}" data-action="setup" aria-pressed="${this.setup}" aria-label="${this.setup ? "Done setting profiles" : "Set each profile's aim"}" title="${this.setup ? "Done" : "Profiles"}">${this.setup ? ICON.check : ICON.gear}</button>
        <button class="automation ${auto ? "on" : ""}" data-action="auto" role="switch" aria-checked="${auto}" aria-label="Automation">${ICON.auto}<i></i></button>
      </div>
    </div>`;
  }

  render() {
    // The SVG being dragged is replaced, so a drag in progress ends here, sending nothing.
    this.drag = null;
    const states = this._hass.states;
    const ac = states[AC];
    const status = states[STATUS];
    const room = Number(states[ROOM_TEMP]?.state);
    const on = this.acOn();
    const pump = states[PUMP];
    const ask = this.confirming;
    const attrs = ac?.attributes ?? {};
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
        <section class="plan-wrap"><div class="frame">${this.plan(states)}${this.bar(states)}</div>
          <p class="hint">${this.setup ? `Drag the air to where it should land for ${AIM_NAMES[this.tuning].toLowerCase()}. Tap ✓ when done.`
            : states[AUTOMATION]?.state === "on" ? "Tap a spot to cool it, drag the air to aim it — your aim holds for an hour."
            : "Tap a spot to cool it, drag the air to aim it, tap the AC to switch it."}</p></section>
        <section class="lights">${LIGHTS.map((l) => this.lightHtml(l, states[l.entity])).join("")}</section>
      </div>
      ${ask ? `<div class="scrim" data-action="confirm-no"><div class="dialog" data-action="dialog" role="alertdialog" aria-modal="true" aria-label="${escape(ask.title)}">
        <h2>${escape(ask.title)}</h2><p>${escape(ask.text)}</p>
        <div class="actions"><button data-action="confirm-no">Cancel</button><button class="yes" data-action="confirm-yes">${escape(ask.yes)}</button></div>
      </div></div>` : ""}`;
    this.drawRoom();
  }

  lightHtml(l, st) {
    const on = st?.state === "on";
    const pct = on ? Math.round(((st.attributes.brightness ?? 255) / 255) * 100) : 0;
    const glow = on ? `rgb(${lightColor(st).join(",")})` : "";
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
    grid-template-columns: minmax(0, 1fr); grid-template-areas: "head" "plan" "lights"; }
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
  .setpoint { font-size: 12px; color: var(--muted); white-space: nowrap; }
  .plan-wrap { grid-area: plan; }
  .frame { background: var(--glass); border: 1px solid var(--line); border-radius: 16px; overflow: hidden; }
  .plan-box { position: relative; aspect-ratio: 103.6 / 67.1; overflow: hidden; }
  .room3d canvas { width: 100%; height: 100%; display: block; }
  .plan { position: absolute; inset: 0; width: 100%; height: 100%; }
  .room { fill: rgba(255,255,255,.015); stroke: #39404a; stroke-width: .6; }
  .solid .room { display: none; }
  .spot rect { fill: rgba(124,199,255,0); stroke: rgba(255,255,255,.07); stroke-width: .3; stroke-dasharray: 1.2 1; transition: fill .3s, stroke .3s; }
  /* With the room drawn, the furniture itself lights up; the outlines are only for the flat plan. */
  .solid .spot rect { stroke: none; }
  .ceiling { cursor: pointer; }
  .ceiling circle { fill: transparent; }
  .ceiling text { fill: var(--muted); font-size: 2.2px; pointer-events: none;
    paint-order: stroke; stroke: rgba(13,15,17,.85); stroke-width: .8px; stroke-linejoin: round; }
  .ceiling.on text { fill: var(--warm); }
  .plan-box:not(.solid) .ceiling circle { stroke: #39404a; stroke-width: .3; }
  .plan-box:not(.solid) .ceiling.on circle { fill: rgba(255,181,77,.25); stroke: var(--warm); }
  .spot text, .ac text { fill: var(--muted); font-size: 2.6px; font-weight: 500; letter-spacing: .02em; pointer-events: none;
    paint-order: stroke; stroke: rgba(13,15,17,.85); stroke-width: .8px; stroke-linejoin: round; }
  .ac text { font-size: 2.2px; }
  .spot { cursor: pointer; }
  .plan-box:not(.solid) .spot.on rect { fill: rgba(124,199,255,.10); stroke: var(--cool); stroke-dasharray: none; stroke-width: .4; }
  .setup .spot.picked text { fill: var(--warm); }
  .spot.on text { fill: var(--cool); }
  .ac rect { fill: transparent; cursor: pointer; }
  .ac.on text { fill: var(--cool); }
  .air path { fill: none; stroke: var(--cool); stroke-width: calc(var(--w) * 1px); stroke-linecap: round; stroke-dasharray: 2 5; opacity: .85; animation: flow 1.1s linear infinite; }
  .air path.b { opacity: .45; transform: translate(-1.5px, 1px); animation-delay: -.4s; }
  .air path.c { opacity: .3; transform: translate(1.5px, -1px); animation-delay: -.8s; }
  .air.slow path { animation-duration: 2.6s; }
  .air.setup path { stroke: var(--warm); }
  .air.setup circle { fill: rgba(255,181,77,.18); stroke: var(--warm); }
  .handle { cursor: grab; touch-action: none; }
  .dragging .handle { cursor: grabbing; }
  .handle .hit { fill: transparent; }
  .handle .knob { fill: var(--ink); stroke: var(--cool); stroke-width: .6; filter: drop-shadow(0 0 1.2px rgba(124,199,255,.9)); }
  .setup .handle .knob { stroke: var(--warm); }
  .grid circle { fill: var(--ink); opacity: 0; transition: opacity .2s; pointer-events: none; }
  .dragging .grid circle { opacity: .35; }
  .profiles { flex: 1 1 300px; display: flex; gap: 6px; flex-wrap: wrap; }
  .profiles button { padding: 7px 10px; border-radius: 999px; font-size: 12px; color: var(--muted); border: 1px solid var(--line); }
  .profiles button.sel { color: #0d0f11; background: var(--warm); border-color: var(--warm); }
  .bar { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 14px; padding: 12px 14px; border-top: 1px solid var(--line); }
  .bar .fan { flex: 1 1 260px; }
  .tools { display: flex; align-items: center; gap: 8px; flex: 1 1 auto; }
  .tools .gap { flex: 1; }
  .chip.icon { width: 40px; height: 40px; padding: 0; display: grid; place-items: center; }
  .chip.icon svg { width: 22px; }
  .chip.icon .louver { width: 24px; height: 24px; }
  .automation { height: 40px; padding: 0 6px 0 10px; border-radius: 999px; border: 1px solid var(--line); display: flex; align-items: center; gap: 8px; color: var(--muted); }
  .automation svg { width: 20px; }
  .automation i { width: 36px; height: 22px; border-radius: 999px; background: #2a2f36; position: relative; transition: background .2s; }
  .automation i::after { content: ""; position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; border-radius: 50%; background: #9aa3ad; transition: transform .2s, background .2s; }
  .automation.on { color: var(--cool); border-color: rgba(124,199,255,.4); }
  .automation.on i { background: rgba(124,199,255,.35); } .automation.on i::after { transform: translateX(14px); background: var(--cool); }
  .air circle { fill: rgba(124,199,255,.18); stroke: var(--cool); stroke-width: .3; animation: land 2s ease-out infinite; transform-box: fill-box; transform-origin: center; }
  @keyframes flow { to { stroke-dashoffset: -14; } }
  @keyframes land { from { transform: scale(.6); opacity: 1; } to { transform: scale(1.5); opacity: 0; } }
  @media (prefers-reduced-motion: reduce) { .air path, .air circle { animation: none; } }
  .hint { color: var(--muted); font-size: 12px; margin: 8px 2px 0; }
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
    .page { max-width: 1040px; padding: 32px 32px 40px; gap: 18px; }
    h1 { font-size: 56px; }
  }`;

customElements.define("frequent-card", FrequentCard);
