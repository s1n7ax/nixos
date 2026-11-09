// Look: Night — always dark. The house fills the screen as glass with thin edges; lit rooms
// glow warm. Everything else floats over it in quiet translucent bars.

import { HouseCardBase } from "./card-base.js";
import { ICONS } from "./icons.js";

class HouseDashboardCard extends HouseCardBase {
  static alwaysDark = true;

  static theme() {
    return {
      sky: 0x8090a0, groundLight: 0x0b0c0e, slab: 0x1b1e22, outdoor: 0x14171a, wall: 0x2a2f36, wallOpacity: 0.55,
      lightOn: 0xffb54d, car: 0x3a4048, edges: true, edge: 0x6b7480, edgeOpacity: 0.55, glow: 0.32, zoom: 0.8, shadow: 0.5,
      ambient: 0.9, sun: 0.6, wallHeight: 0.55, view: [16, 18, 20],
    };
  }

  summaryHtml(s) {
    const time = new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
    const stat = (v, l, on) => `<div class="stat ${on ? "on" : ""}"><b>${v}</b><span>${l}</span></div>`;
    return `
      <div class="time">${time}<span>${s.weather.attributes.temperature}° outside · ${Math.round(s.inside.state)}° office</span></div>
      <div class="stats">
        ${stat(s.lightsOn, s.lightsOn === 1 ? "light" : "lights", s.lightsOn)}
        ${stat(s.ac.state === "off" ? "—" : `${s.ac.attributes.temperature}°`, "AC", s.ac.state !== "off")}
        ${stat(s.home.length, "home", false)}
        ${stat(s.carHome ? "In" : "Out", "car", s.carHome)}
      </div>
      ${s.alarm.length ? `<div class="alert">${s.alarm.map((a) => a.name).join(", ")} alarm</div>` : ""}
      ${s.away ? `<div class="away">${ICONS.shield}${s.away.name}</div>` : ""}`;
  }

  shortcutHtml(sc, i, on) {
    return `<button class="pill ${on ? "on" : ""}" data-action="shortcut" data-i="${i}">
      <i>${ICONS[sc.kind === "room" ? "light" : sc.kind]}</i><span>${sc.name}</span>
      ${sc.kind === "climate" ? `<em data-open>${this.shortcutState(sc, on)} ›</em>` : ""}</button>`;
  }

  cameraHtml(c, st) {
    return `<button class="cam" data-action="camera" data-entity="${c.entity}" data-name="${c.name}">
      <img src="${st.attributes.entity_picture}" alt=""><span>${c.name}</span></button>`;
  }

  securityHtml(s, on) {
    return `<button class="seg ${on ? "on" : ""}" data-action="security" data-entity="${s.entity}">${s.name}</button>`;
  }

  static layout = `
    <div class="page">
      <div class="model"></div>
      <header class="top"><div class="summary"></div><nav class="floors"></nav></header>
      <div class="dock">
        <div class="shortcuts"></div>
        <div class="row"><div class="cameras"></div></div>
        <div class="security"></div>
      </div>
    </div>
    <div class="sheet-host"></div>`;

  static css = `
    :host {
      --bg: #0d0f11; --glass: rgba(24,27,31,.72); --line: rgba(255,255,255,.08); --ink: #e9ebee; --muted: #7d8590; --warm: #ffb54d;
      display: block; background: radial-gradient(120% 80% at 50% 30%, #181b1f 0%, var(--bg) 70%); color: var(--ink);
      font: 14px/1.4 Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif; -webkit-font-smoothing: antialiased;
    }
    * { box-sizing: border-box; }
    button { font: inherit; color: inherit; background: none; border: 0; cursor: pointer; padding: 0; }
    .page { position: relative; height: 100vh; min-height: 640px; overflow: hidden; }
    .model { position: absolute; inset: 0; touch-action: none; }
    .model canvas { width: 100%; height: 100%; display: block; }
    .top { position: absolute; top: 0; left: 0; right: 0; padding: 20px; display: flex; justify-content: space-between; align-items: flex-start; pointer-events: none; }
    .top > * { pointer-events: auto; }
    .time { font-size: 40px; font-weight: 300; letter-spacing: -.03em; line-height: 1; font-variant-numeric: tabular-nums; }
    .time span { display: block; font-size: 13px; letter-spacing: 0; color: var(--muted); margin-top: 8px; font-weight: 400; }
    .stats { display: flex; gap: 22px; margin-top: 18px; }
    .stat b { display: block; font-size: 20px; font-weight: 500; font-variant-numeric: tabular-nums; }
    .stat span { color: var(--muted); font-size: 12px; }
    .stat.on b { color: var(--warm); }
    .alert { margin-top: 12px; color: #ff6b5b; font-weight: 600; }
    .away { margin-top: 12px; display: inline-flex; gap: 6px; align-items: center; color: var(--warm); font-size: 13px; }
    .floors { display: flex; flex-direction: column; gap: 4px; }
    .floors button { width: 52px; padding: 6px 0; border-radius: 8px; font-size: 12px; color: var(--muted); background: var(--glass); border: 1px solid var(--line); backdrop-filter: blur(12px); }
    .floors button.sel { color: var(--ink); border-color: rgba(255,255,255,.3); }
    .markers { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
    .marker { position: absolute; left: 0; top: 0; pointer-events: auto; width: 30px; height: 30px; display: grid; place-items: center; font-size: 14px; color: var(--muted); }
    .marker.kind-light::before { content: ""; width: 8px; height: 8px; border-radius: 50%; background: #3a4048; box-shadow: 0 0 0 1px #59616b; }
    .marker.kind-light.on::before { background: var(--warm); box-shadow: 0 0 6px 2px var(--warm), 0 0 24px 8px rgba(255,181,77,.35); }
    .marker:not(.kind-light) { color: #8f98a3; }
    .marker.on:not(.kind-light):not(.kind-camera) { color: var(--warm); }
    .marker.kind-climate.on { width: auto; gap: 4px; display: flex; font-size: 12px; }
    .marker.kind-car { display: none; }
    .marker.kind-smoke.on, .marker.kind-leak.on { color: #ff6b5b; }
    .marker.unavailable { opacity: .3; }
    .dock { position: absolute; left: 0; right: 0; bottom: 0; padding: 0 0 18px; display: grid; gap: 10px; background: linear-gradient(transparent, rgba(13,15,17,.85) 30%); padding-top: 40px; }
    .shortcuts, .cameras, .security { display: flex; gap: 8px; overflow-x: auto; scrollbar-width: none; padding: 0 20px; }
    .pill { flex: none; display: flex; align-items: center; gap: 8px; padding: 10px 14px; border-radius: 999px; background: var(--glass); border: 1px solid var(--line); backdrop-filter: blur(12px); color: var(--muted); }
    .pill i { font-size: 16px; font-style: normal; display: grid; }
    .pill span { color: var(--ink); }
    .pill em { font-style: normal; font-size: 12px; color: var(--muted); }
    .pill.on { border-color: rgba(255,181,77,.45); color: var(--warm); background: rgba(255,181,77,.12); }
    .pill.on em { color: var(--warm); }
    .cam { flex: none; width: 132px; aspect-ratio: 16/10; border-radius: 10px; overflow: hidden; position: relative; border: 1px solid var(--line); }
    .cam img { width: 100%; height: 100%; object-fit: cover; display: block; opacity: .85; }
    .cam span { position: absolute; left: 8px; bottom: 5px; font-size: 11px; color: #fff; }
    .security { gap: 0; }
    .seg { flex: 1; min-width: 0; padding: 9px 6px; font-size: 12px; color: var(--muted); border: 1px solid var(--line); background: var(--glass); white-space: nowrap; }
    .seg:first-child { border-radius: 10px 0 0 10px; } .seg:last-child { border-radius: 0 10px 10px 0; } .seg + .seg { border-left: 0; }
    .seg.on { color: #111; background: var(--warm); border-color: var(--warm); }
    .scrim { position: fixed; inset: 0; background: #0009; z-index: 10; }
    .sheet { position: fixed; z-index: 11; left: 50%; bottom: 0; transform: translateX(-50%); width: min(560px, 100%); background: #16191c; border: 1px solid var(--line); border-radius: 20px 20px 0 0; padding: 18px 20px 28px; }
    .sheet header { display: flex; justify-content: space-between; align-items: center; font-weight: 500; margin-bottom: 14px; }
    .sheet header button { font-size: 20px; color: var(--muted); }
    .feed { width: 100%; border-radius: 12px; display: block; }
    .thermo { display: flex; align-items: center; justify-content: space-between; padding: 10px 0 20px; }
    .thermo button { width: 56px; height: 56px; border-radius: 50%; border: 1px solid var(--line); font-size: 22px; display: grid; place-items: center; }
    .setpoint { text-align: center; display: grid; }
    .setpoint b { font-size: 60px; font-weight: 200; letter-spacing: -.04em; line-height: 1; color: var(--warm); }
    .setpoint small { color: var(--muted); margin-top: 6px; }
    .modes { display: flex; gap: 6px; }
    .modes button { flex: 1; border: 1px solid var(--line); border-radius: 10px; padding: 10px 0; text-transform: capitalize; font-size: 12px; color: var(--muted); }
    .modes button.sel { color: var(--ink); border-color: rgba(255,255,255,.35); }
    @media (min-width: 960px) {
      .top { padding: 36px 40px; }
      .time { font-size: 56px; }
      .dock { left: auto; top: 0; width: 360px; padding: 120px 0 32px; background: linear-gradient(90deg, transparent, rgba(13,15,17,.8) 25%); align-content: end; }
      .top { right: 380px; }
      .shortcuts { flex-wrap: wrap; padding: 0 32px 0 20px; }
      .cameras { display: grid; grid-template-columns: 1fr 1fr; padding: 0 32px 0 20px; }
      .cam { width: auto; }
      .security { padding: 0 32px 0 20px; }
    }`;
}

customElements.define("house-dashboard-card", HouseDashboardCard);
