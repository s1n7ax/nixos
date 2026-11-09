// Look: Maquette — a white architect's model on warm paper. Ink type, one amber for "on".

import { HouseCardBase } from "./card-base.js";
import { ICONS } from "./icons.js";

class HouseDashboardCard extends HouseCardBase {
  static theme(dark) {
    return dark
      ? { sky: 0x9aa0a8, groundLight: 0x22201c, slab: 0x3a3833, outdoor: 0x2b2a27, wall: 0x56534c, wallOpacity: 1, lightOn: 0xf0b45a, car: 0x77736a, edges: false, glow: 0.5, shadow: 0.35, ambient: 1.2, sun: 1 }
      : { sky: 0xffffff, groundLight: 0xd8d2c6, slab: 0xfbfaf7, outdoor: 0xe6e1d6, wall: 0xffffff, wallOpacity: 1, lightOn: 0xf0a83c, car: 0xcfc9bd, edges: false, glow: 0.45, shadow: 0.14 };
  }

  summaryHtml(s) {
    const lights = s.lightsOn ? `${s.lightsOn} light${s.lightsOn > 1 ? "s" : ""} on` : "All lights off";
    const ac = s.ac.state === "off" ? "AC off" : `AC ${s.ac.attributes.temperature}°`;
    const people = s.home.length === 2 ? "Everyone home" : s.home.length ? `${s.home[0]} home` : "No one home";
    const alert = s.alarm.length ? `<p class="alert">${s.alarm.map((a) => a.name).join(", ")} alarm</p>` : "";
    return `
      <div class="date">${new Date().toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" })}</div>
      <h1>${lights}. ${ac}.<br><span>${people}${s.carHome ? ", car parked" : ""}.</span></h1>
      <div class="climate"><span>Outside ${s.weather.attributes.temperature}°</span><span>Office ${Math.round(s.inside.state)}°</span>${s.away ? `<span class="amber">${s.away.name}</span>` : ""}</div>
      ${alert}`;
  }

  shortcutHtml(sc, i, on) {
    return `<button class="tile ${on ? "on" : ""}" data-action="shortcut" data-i="${i}">
      <i>${ICONS[sc.kind === "room" ? "light" : sc.kind]}</i>
      <span class="name">${sc.name}</span>
      <span class="state" ${sc.kind === "climate" ? "data-open" : ""}>${this.shortcutState(sc, on)}${sc.kind === "climate" ? " ›" : ""}</span>
    </button>`;
  }

  cameraHtml(c, st) {
    return `<button class="cam" data-action="camera" data-entity="${c.entity}" data-name="${c.name}">
      <img src="${st.attributes.entity_picture}" alt=""><span>${c.name}</span></button>`;
  }

  securityHtml(s, on) {
    return `<button class="chip ${on ? "on" : ""}" data-action="security" data-entity="${s.entity}">${s.name}</button>`;
  }

  static layout = `
    <div class="page">
      <section class="hero">
        <div class="summary"></div>
        <div class="model"><nav class="floors"></nav></div>
      </section>
      <aside class="side">
        <h2>For you</h2>
        <div class="shortcuts"></div>
        <h2>Cameras</h2>
        <div class="cameras"></div>
        <h2>Security</h2>
        <div class="security"></div>
      </aside>
    </div>
    <div class="sheet-host"></div>`;

  static css = `
    :host {
      --bg: #f4f1ea; --surface: #fbfaf7; --ink: #1c1b19; --muted: #8b867c; --line: #e3ded3; --amber: #e8a03a; --amber-soft: #f6e3c2;
      display: block; background: var(--bg); color: var(--ink);
      font: 15px/1.4 Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
      -webkit-font-smoothing: antialiased; min-height: 100vh;
    }
    :host(.dark) { --bg: #1a1917; --surface: #22211e; --ink: #ece8df; --muted: #8e897f; --line: #2f2d29; --amber-soft: #3d3121; }
    * { box-sizing: border-box; }
    button { font: inherit; color: inherit; background: none; border: 0; cursor: pointer; padding: 0; }
    .page { display: grid; grid-template-columns: 1fr; max-width: 1400px; margin: 0 auto; }
    .hero { position: relative; display: flex; flex-direction: column; }
    .summary { padding: 28px 20px 0; }
    .date { color: var(--muted); font-size: 13px; letter-spacing: .02em; }
    h1 { font-size: 26px; font-weight: 500; line-height: 1.2; letter-spacing: -.02em; margin: 6px 0 10px; }
    h1 span { color: var(--muted); }
    .climate { display: flex; gap: 16px; color: var(--muted); font-size: 13px; }
    .amber { color: var(--amber); }
    .alert { color: #c2410c; font-weight: 600; }
    .model { position: relative; height: 54vh; min-height: 340px; touch-action: none; }
    .model canvas { width: 100%; height: 100%; display: block; }
    .floors { position: absolute; right: 16px; top: 8px; z-index: 2; display: flex; gap: 2px; background: var(--surface); border: 1px solid var(--line); border-radius: 999px; padding: 3px; }
    .floors button { padding: 4px 12px; border-radius: 999px; font-size: 12px; color: var(--muted); }
    .floors button.sel { background: var(--ink); color: var(--bg); }
    .markers { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
    .marker { position: absolute; left: 0; top: 0; pointer-events: auto; width: 30px; height: 30px; display: grid; place-items: center; font-size: 15px; color: var(--muted); border-radius: 50%; }
    .marker::before { content: ""; position: absolute; inset: 7px; border-radius: 50%; background: var(--surface); box-shadow: 0 0 0 1px var(--line); z-index: -1; }
    .marker.kind-light::before { inset: 10px; background: transparent; box-shadow: 0 0 0 1.5px var(--muted); }
    .marker.kind-light.on::before { background: var(--amber); box-shadow: 0 0 0 4px color-mix(in srgb, var(--amber) 30%, transparent), 0 0 18px var(--amber); }
    .marker.kind-motion.on, .marker.kind-door.on, .marker.kind-pump.on { color: var(--amber); }
    .marker.kind-climate.on { width: auto; padding: 0 10px; gap: 4px; display: flex; color: var(--ink); font-size: 12px; }
    .marker.kind-climate.on::before { inset: 4px 0; border-radius: 999px; }
    .marker.kind-car { display: none; }
    .marker.kind-smoke.on, .marker.kind-leak.on { color: #c2410c; }
    .marker.unavailable { opacity: .35; }
    .side { padding: 4px 20px 40px; }
    h2 { font-size: 12px; font-weight: 600; color: var(--muted); letter-spacing: .08em; text-transform: uppercase; margin: 28px 0 10px; }
    .shortcuts { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    .tile { text-align: left; background: var(--surface); border: 1px solid var(--line); border-radius: 14px; padding: 14px; display: grid; gap: 2px; transition: background .2s; }
    .tile i { font-size: 20px; color: var(--muted); font-style: normal; margin-bottom: 10px; }
    .tile .name { font-weight: 500; }
    .tile .state { color: var(--muted); font-size: 13px; }
    .tile.on { background: var(--amber-soft); border-color: transparent; }
    .tile.on i { color: var(--amber); }
    .cameras { display: grid; grid-auto-flow: column; grid-auto-columns: 46%; gap: 8px; overflow-x: auto; scrollbar-width: none; margin: 0 -20px; padding: 0 20px; }
    .cam { position: relative; border-radius: 12px; overflow: hidden; aspect-ratio: 16/10; }
    .cam img { width: 100%; height: 100%; object-fit: cover; display: block; }
    .cam span { position: absolute; left: 8px; bottom: 6px; color: #fff; font-size: 12px; font-weight: 500; text-shadow: 0 1px 3px #0008; }
    .security { display: flex; flex-wrap: wrap; gap: 8px; }
    .chip { border: 1px solid var(--line); border-radius: 999px; padding: 8px 14px; font-size: 13px; background: var(--surface); }
    .chip.on { background: var(--ink); color: var(--bg); border-color: var(--ink); }
    .scrim { position: fixed; inset: 0; background: #0004; z-index: 10; }
    .sheet { position: fixed; z-index: 11; left: 50%; bottom: 0; transform: translateX(-50%); width: min(560px, 100%); background: var(--surface); border-radius: 20px 20px 0 0; padding: 18px 20px 28px; }
    .sheet header { display: flex; justify-content: space-between; align-items: center; font-weight: 600; margin-bottom: 14px; }
    .sheet header button { font-size: 20px; color: var(--muted); }
    .feed { width: 100%; border-radius: 12px; display: block; }
    .thermo { display: flex; align-items: center; justify-content: space-between; padding: 10px 0 20px; }
    .thermo button { width: 56px; height: 56px; border-radius: 50%; border: 1px solid var(--line); font-size: 22px; display: grid; place-items: center; }
    .setpoint { text-align: center; display: grid; }
    .setpoint b { font-size: 56px; font-weight: 300; letter-spacing: -.04em; line-height: 1; }
    .setpoint small { color: var(--muted); margin-top: 6px; }
    .modes { display: flex; gap: 6px; flex-wrap: wrap; }
    .modes button { flex: 1; border: 1px solid var(--line); border-radius: 10px; padding: 10px 0; text-transform: capitalize; font-size: 13px; }
    .modes button.sel { background: var(--ink); color: var(--bg); border-color: var(--ink); }
    @media (min-width: 960px) {
      .page { grid-template-columns: minmax(0, 1fr) 380px; gap: 8px; }
      .summary { padding: 40px 40px 0; }
      h1 { font-size: 34px; }
      .model { height: calc(100vh - 170px); }
      .side { padding: 24px 40px 40px 0; }
      .cameras { grid-auto-flow: row; grid-template-columns: 1fr 1fr; grid-auto-columns: auto; margin: 0; padding: 0; overflow: visible; }
    }`;
}

customElements.define("house-dashboard-card", HouseDashboardCard);
