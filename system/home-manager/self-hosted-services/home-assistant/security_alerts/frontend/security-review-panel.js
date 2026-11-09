// Security review: the review panel and the Review tab's card, one photo gallery of alerts, newest
// first, with Trigger siren above it.
//
// The panel (security-review-panel) lists every alert since the last review. Opened at
// /security-review by tapping a security notification. With no query it records a review
// (security_alerts/review/start) and rewrites the URL to ?from=&to=, so a reload shows the same
// window without recording another. ?clip=<alert id> (the Play clip button) opens that alert in
// the viewer over the window since the last review, without recording one: a sound plays its
// audio, a detection its video.
//
// The card (type: custom:security-review-card, loaded as a dashboard resource) is the Review tab:
// every alert in the log, under day headers, older ones loading as it scrolls. It never records a
// review, and alerts logged while it is open appear at the top. It reloads from now each time it
// is shown again, and when its signed URLs may have expired (see SIGNED_URL_REFRESH_MS). Left
// open past midnight, it renames its day headers ("Today" becomes "Yesterday").
//
// Detections are photos: one full frame per row under its header, or, zoomed out, square crops
// around the object, 2 to 5 per row on a phone and more on wider screens. Pinch, Ctrl+scroll or
// the - and + buttons change the level, which each device keeps. Door and motion alerts are thin
// rows across the grid. Sounds are not listed.
//
// Tapping a photo opens the full-screen viewer: the clip, or the live view until it is saved.
// Pinch, double-tap or scroll zooms it and dragging pans it; a swipe opens the next or previous
// detection, loading older pages past the end. It downloads the snapshot and the clip.
// Images, clips and downloads come as URLs signed for the logged-in user; this file holds no data.

const PANEL_PATH = "/security-review";
const POLL_CLIP_MS = 5000;
// Images this far below the screen start loading before they scroll in.
const PRELOAD_MARGIN = "600px 0px";
const BADGES = { paused: "Paused" };
// The viewer plays a sound's audio or an alert's video.
const SOUND_MODE = "sound";
const VIDEO_MODE = "video";
// How often the Review tab checks whether a new day has begun, to rename its day headers.
const DAY_CHECK_MS = 60 * 1000;
// URLs are signed for 24 h (SIGNED_URL_HOURS on the server), and the Review tab can stay open
// longer. Once its first ones are this old, it reloads from now when it is shown again or when a
// list image fails, and a clip asks for its alert anew.
const SIGNED_URL_REFRESH_MS = 23 * 60 * 60 * 1000;
// Gallery levels: 1 is one full frame per row; 2 to 5 that many crops per row on a phone.
const MIN_LEVEL = 1;
const MAX_LEVEL = 5;
const DEFAULT_LEVEL = 3;
const LEVEL_KEY = "security-review-level";
// About the list's width on a phone; wider lists fit proportionally more crops per row.
const PHONE_WIDTH = 420;
// A pinch changes the level by one each time the fingers' spread grows or shrinks this much.
const PINCH_STEP = 1.5;
// Ctrl+scroll (or a trackpad pinch) changes the level by one per this much scrolling.
const WHEEL_STEP = 100;
// The viewer's zoom.
const MAX_ZOOM = 5;
const DOUBLE_TAP_ZOOM = 2.5;
const DOUBLE_TAP_MS = 300;
// A tap moves less than this, in pixels; a swipe more than SWIPE_PX, mostly sideways.
const TAP_SLOP = 10;
const SWIPE_PX = 60;
// Material Design Icons paths.
const ICONS = {
  close:
    "M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z",
  download: "M5,20H19V18H5M19,9H15V3H9V9H5L12,16L19,9Z",
  play: "M8,5.14V19.14L19,12.14L8,5.14Z",
  pause: "M14,19H18V5H14M6,19H10V5H6V19Z",
  volume:
    "M14,3.23V5.29C16.89,6.15 19,8.83 19,12C19,15.17 16.89,17.84 14,18.7V20.77C18,19.86 21,16.28 21,12C21,7.72 18,4.14 14,3.23M16.5,12C16.5,10.23 15.5,8.71 14,7.97V16C15.5,15.29 16.5,13.76 16.5,12M3,9V15H7L12,20V4L7,9H3Z",
  muted:
    "M12,4L9.91,6.09L12,8.18M4.27,3L3,4.27L7.73,9H3V15H7L12,20V13.27L16.25,17.53C15.58,18.04 14.83,18.46 14,18.7V20.77C15.38,20.45 16.63,19.82 17.68,18.96L19.73,21L21,19.73L12,10.73M19,12C19,12.94 18.8,13.82 18.46,14.64L19.97,16.15C20.62,14.91 21,13.5 21,12C21,7.72 18,4.14 14,3.23V5.29C16.89,6.15 19,8.83 19,12M16.5,12C16.5,10.23 15.5,8.71 14,7.97V10.18L16.45,12.63C16.5,12.43 16.5,12.21 16.5,12Z",
};

// Read at module load too: the frontend may rewrite the URL before the first panel starts.
// Only that first panel may use it; later ones would replay a stale clip or window. Loaded by a
// dashboard instead, the query is not the panel's, so it is never kept.
let initialSearch =
  typeof window !== "undefined" && window.location.pathname.startsWith(PANEL_PATH) ? window.location.search : "";

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

function icon(name) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
  path.setAttribute("d", ICONS[name]);
  svg.append(path);
  return svg;
}

function sensorText(item) {
  if (item.kind === "door") return `${item.name} ${item.action || "opened"} ${item.clock}`;
  return `Motion: ${item.name} ${item.clock}`;
}

// The signed URL the viewer plays in this mode, once the recording is saved.
function mediaUrl(item, mode) {
  const media = mode === SOUND_MODE ? item.audio : item.clip;
  return media && media.ready && media.url ? media.url : null;
}

// A link that saves `url` as a file, or a disabled button while there is none yet.
function downloadLink(text, url) {
  const content = [icon("download"), text];
  if (!url) return h("button", { class: "action", disabled: true }, content);
  return h("a", { class: "action", href: url, download: true }, content);
}

// A date as YYYY-MM-DD in a time zone: Home Assistant's, so it matches the server's days.
function isoDate(date, timeZone) {
  const options = { year: "numeric", month: "2-digit", day: "2-digit" };
  let parts;
  try {
    parts = new Intl.DateTimeFormat("en-CA", { ...options, timeZone }).formatToParts(date);
  } catch (_err) {
    // An unknown time zone: the browser's own.
    parts = new Intl.DateTimeFormat("en-CA", options).formatToParts(date);
  }
  const part = (type) => parts.find((p) => p.type === type).value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}

// "Today", "Yesterday", else the server's name for the day, like "Thursday 22 October".
function dayLabel(day, dayName, today) {
  if (day === today) return "Today";
  const yesterday = new Date(`${today}T12:00:00Z`);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);
  if (day === yesterday.toISOString().slice(0, 10)) return "Yesterday";
  return dayName;
}

function endText(logDays) {
  const text = "That's everything in the log.";
  return logDays ? `${text} It keeps ${logDays} day${logDays === 1 ? "" : "s"}.` : text;
}

// A position in a clip, like 1:05.
function playTime(seconds) {
  const whole = Number.isFinite(seconds) ? Math.floor(seconds) : 0;
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function midpoint(a, b) {
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
}

// The gallery level this device keeps. Storage may be unavailable, as in a private window.
function storedLevel() {
  try {
    const level = Number(window.localStorage.getItem(LEVEL_KEY));
    if (Number.isInteger(level) && level >= MIN_LEVEL && level <= MAX_LEVEL) return level;
  } catch (_err) {
    // The default, then.
  }
  return DEFAULT_LEVEL;
}

function storeLevel(level) {
  try {
    window.localStorage.setItem(LEVEL_KEY, String(level));
  } catch (_err) {
    // Kept until the page reloads.
  }
}

// The element that scrolls `el`: its nearest scrolling ancestor, across shadow roots.
function scroller(el) {
  for (let node = el; node; node = node.parentNode || node.host) {
    if (!(node instanceof Element) || node.scrollHeight <= node.clientHeight) continue;
    if (/auto|scroll/.test(getComputedStyle(node).overflowY)) return node;
  }
  return document.scrollingElement;
}

// Ends a subscription; the connection may already be gone.
function unsubscribeQuietly(unsubscribe) {
  Promise.resolve()
    .then(unsubscribe)
    .catch(() => {});
}

// Pauses and unloads every player in `root`, so nothing keeps playing or downloading.
function stopMedia(root) {
  for (const media of root.querySelectorAll("audio, video")) {
    media.pause();
    media.removeAttribute("src");
    media.load();
  }
}

// Play, seek and mute for the viewer's clip: the video's own controls would zoom with it, and
// their double-tap seeks.
function playerControls(video) {
  const play = h("button", {
    class: "icon",
    onclick: () => (video.paused ? video.play().catch(() => {}) : video.pause()),
  });
  const seek = h("input", { class: "seek", type: "range", min: "0", max: "0", step: "0.1", value: "0" });
  seek.setAttribute("aria-label", "Position");
  seek.addEventListener("input", () => {
    video.currentTime = Number(seek.value);
  });
  const time = h("span", { class: "time" });
  const mute = h("button", {
    class: "icon",
    onclick: () => {
      video.muted = !video.muted;
    },
  });
  const update = () => {
    play.replaceChildren(icon(video.paused ? "play" : "pause"));
    play.setAttribute("aria-label", video.paused ? "Play" : "Pause");
    mute.replaceChildren(icon(video.muted ? "muted" : "volume"));
    mute.setAttribute("aria-label", video.muted ? "Unmute" : "Mute");
    if (Number.isFinite(video.duration)) seek.max = String(video.duration);
    seek.value = String(video.currentTime);
    time.textContent = `${playTime(video.currentTime)} / ${playTime(video.duration)}`;
  };
  for (const type of ["play", "pause", "timeupdate", "durationchange", "volumechange"]) {
    video.addEventListener(type, update);
  }
  update();
  return h("div", { class: "player" }, [play, seek, time, mute]);
}

// Zooms and pans `content` inside `stage`: pinch, double-tap, the wheel, and dragging. A drag
// while not zoomed in is a swipe: onSwipe(1) when dragged left (the next item), -1 when right.
class ZoomStage {
  constructor(stage, content, onSwipe) {
    this._stage = stage;
    this._content = content;
    this._onSwipe = onSwipe;
    this._scale = 1;
    this._x = 0;
    this._y = 0;
    this._pointers = new Map();
    this._gesture = null;
    this._lastTap = null;
    stage.addEventListener("pointerdown", (ev) => this._down(ev));
    stage.addEventListener("pointermove", (ev) => this._move(ev));
    stage.addEventListener("pointerup", (ev) => this._up(ev));
    stage.addEventListener("pointercancel", (ev) => this._up(ev));
    stage.addEventListener("wheel", (ev) => this._wheel(ev), { passive: false });
    stage.addEventListener("dragstart", (ev) => ev.preventDefault());
  }

  _point(ev) {
    const rect = this._stage.getBoundingClientRect();
    return { x: ev.clientX - rect.left, y: ev.clientY - rect.top };
  }

  // Each finger that lands or lifts starts a new gesture: a pinch with two, a drag with one. A
  // drag left over from a pinch is neither a tap nor a swipe.
  _begin(afterPinch) {
    const [a, b] = this._pointers.values();
    if (b) {
      return { pinch: true, spread: Math.max(distance(a, b), 1), mid: midpoint(a, b), scale: this._scale, x: this._x, y: this._y };
    }
    return { pinch: false, afterPinch, start: a, x: this._x, y: this._y, moved: false };
  }

  _down(ev) {
    if (ev.pointerType === "mouse" && ev.button !== 0) return;
    this._stage.setPointerCapture(ev.pointerId);
    this._pointers.set(ev.pointerId, this._point(ev));
    const g = this._gesture;
    this._gesture = this._begin(Boolean(g && (g.pinch || g.afterPinch)));
  }

  _move(ev) {
    if (!this._pointers.has(ev.pointerId)) return;
    this._pointers.set(ev.pointerId, this._point(ev));
    const g = this._gesture;
    const [a, b] = this._pointers.values();
    if (g.pinch) {
      if (!b) return;
      const mid = midpoint(a, b);
      const scale = clamp((g.scale * distance(a, b)) / g.spread, 1, MAX_ZOOM);
      // What was under the fingers when the pinch began stays under them.
      const k = scale / g.scale;
      this._set(scale, mid.x - (g.mid.x - g.x) * k, mid.y - (g.mid.y - g.y) * k);
      return;
    }
    const dx = a.x - g.start.x;
    const dy = a.y - g.start.y;
    if (Math.hypot(dx, dy) > TAP_SLOP) g.moved = true;
    if (this._scale > 1) this._set(this._scale, g.x + dx, g.y + dy);
  }

  _up(ev) {
    if (!this._pointers.has(ev.pointerId)) return;
    const end = this._point(ev);
    this._pointers.delete(ev.pointerId);
    const g = this._gesture;
    if (this._pointers.size) {
      this._gesture = this._begin(true);
      return;
    }
    this._gesture = null;
    if (g.pinch || g.afterPinch || ev.type === "pointercancel") return;
    if (!g.moved) {
      this._tap(end);
      return;
    }
    const dx = end.x - g.start.x;
    const dy = end.y - g.start.y;
    if (this._scale === 1 && Math.abs(dx) > SWIPE_PX && Math.abs(dx) > 2 * Math.abs(dy)) {
      this._onSwipe(dx < 0 ? 1 : -1);
    }
  }

  // A second tap soon after the first and near it zooms in there, or back out.
  _tap(point) {
    const now = Date.now();
    const last = this._lastTap;
    this._lastTap = { ...point, at: now };
    if (!last || now - last.at > DOUBLE_TAP_MS || distance(point, last) > 3 * TAP_SLOP) return;
    this._lastTap = null;
    if (this._scale > 1) this._set(1, 0, 0);
    else this._zoomAt(point, DOUBLE_TAP_ZOOM);
  }

  _wheel(ev) {
    ev.preventDefault();
    this._zoomAt(this._point(ev), this._scale * Math.exp(-ev.deltaY / 300));
  }

  _zoomAt(point, scale) {
    const next = clamp(scale, 1, MAX_ZOOM);
    const k = next / this._scale;
    this._set(next, point.x - (point.x - this._x) * k, point.y - (point.y - this._y) * k);
  }

  // The content always covers the stage: it never pans past its edges.
  _set(scale, x, y) {
    const { width, height } = this._stage.getBoundingClientRect();
    this._scale = scale;
    this._x = clamp(x, width * (1 - scale), 0);
    this._y = clamp(y, height * (1 - scale), 0);
    this._content.style.transform = `translate(${this._x}px, ${this._y}px) scale(${scale})`;
  }
}

// The panel scrolls on its own under a toolbar; the card grows with the dashboard page.
const PANEL_STYLE = `
  :host { display: block; height: 100%; overflow-y: auto; background: var(--primary-background-color);
    color: var(--primary-text-color); font-family: var(--paper-font-body1_-_font-family, Roboto, sans-serif); }
  .toolbar { position: sticky; top: 0; z-index: 2; display: flex; align-items: center; gap: 8px; height: 56px;
    padding: 0 12px; background: var(--app-header-background-color, var(--primary-color));
    color: var(--app-header-text-color, #fff); font-size: 20px; }
`;
const CARD_STYLE = `
  :host { display: block; color: var(--primary-text-color);
    font-family: var(--paper-font-body1_-_font-family, Roboto, sans-serif); }
`;
const STYLE = `
  .content { max-width: 1400px; margin: 0 auto; padding: 12px 12px 48px; touch-action: pan-y; }
  .controls { display: grid; }
  .siren { font: inherit; font-size: 1.05em; font-weight: 600; padding: 14px; border: 0; border-radius: 12px;
    background: var(--error-color, #db4437); color: #fff; cursor: pointer; }
  .siren:disabled { opacity: 0.6; }
  .bar { display: flex; align-items: center; gap: 8px; margin: 12px 2px; }
  .window { flex: 1; color: var(--secondary-text-color); font-size: 0.95em; }
  .sizes { display: flex; gap: 6px; }
  .size { font: inherit; font-size: 1.2em; line-height: 1; width: 36px; height: 36px; padding: 0; cursor: pointer;
    border-radius: 18px; border: 1px solid var(--divider-color); background: var(--card-background-color);
    color: var(--primary-text-color); }
  .size:disabled { opacity: 0.4; cursor: default; }
  @media (hover: none) and (pointer: coarse) { .sizes { display: none; } }
  .list { display: grid; gap: 4px; grid-template-columns: repeat(var(--per-row, 3), minmax(0, 1fr)); }
  .list.full { gap: 12px; max-width: 900px; margin: 0 auto; }
  .list > :not(.tile) { grid-column: 1 / -1; }
  .tile { background: var(--card-background-color); overflow: hidden; border-radius: 4px; }
  .full .tile { border-radius: 12px; border: 1px solid var(--divider-color); }
  .tile header { display: flex; align-items: baseline; flex-wrap: wrap; gap: 4px 10px; padding: 10px 12px; }
  .grid .tile header, .full .when, .full .shot .badge { display: none; }
  .type { font-weight: 600; font-size: 1.05em; }
  .meta { color: var(--secondary-text-color); }
  .badge { margin-left: auto; font-size: 0.8em; padding: 2px 8px; border-radius: 10px;
    background: var(--warning-color, #ffa600); color: #000; }
  .shot { position: relative; display: block; width: 100%; aspect-ratio: 16 / 9; background: #111;
    cursor: pointer; border: 0; padding: 0; }
  .grid .shot { aspect-ratio: 1; }
  .shot img { display: block; width: 100%; height: 100%; object-fit: contain; }
  .grid .shot img { object-fit: cover; }
  .shot.failed img { visibility: hidden; }
  .shot.failed::after { content: "No image"; position: absolute; inset: 0; display: flex; align-items: center;
    justify-content: center; color: #aaa; font-size: 0.85em; }
  .when { position: absolute; left: 4px; bottom: 4px; padding: 1px 5px; border-radius: 6px; font-size: 0.75em;
    background: rgba(0, 0, 0, 0.6); color: #fff; }
  .shot .badge { position: absolute; top: 4px; right: 4px; margin: 0; padding: 1px 6px; font-size: 0.7em; }
  .more { padding: 16px; text-align: center; color: var(--secondary-text-color); }
  .day { margin: 10px 2px 2px; font-weight: 600; color: var(--secondary-text-color); }
  .row { display: flex; align-items: center; gap: 8px; padding: 6px 10px; font-size: 0.9em;
    background: var(--card-background-color); border-radius: 8px; border: 1px solid var(--divider-color); }
  .row .type { font-size: 1em; }
  .empty, .error { padding: 24px 8px; text-align: center; color: var(--secondary-text-color); }
  .error { color: var(--error-color, #db4437); }
  dialog.viewer { box-sizing: border-box; width: 100vw; height: 100vh; height: 100dvh; max-width: none;
    max-height: none; margin: 0; padding: 0; border: 0; background: #000; color: #fff; }
  dialog.viewer[open] { display: flex; flex-direction: column; }
  dialog.viewer::backdrop { background: #000; }
  .viewer-bar { display: flex; align-items: center; gap: 8px; padding: 6px 6px 6px 16px; }
  .viewer-title { flex: 1; min-width: 0; font-weight: 600; overflow: hidden; text-overflow: ellipsis;
    white-space: nowrap; }
  .icon { display: inline-flex; align-items: center; justify-content: center; flex: none; width: 44px;
    height: 44px; padding: 10px; border: 0; border-radius: 22px; background: transparent; color: inherit;
    cursor: pointer; }
  .icon svg, .action svg { width: 24px; height: 24px; fill: currentColor; }
  .stage { position: relative; flex: 1; min-height: 0; overflow: hidden; touch-action: none; user-select: none;
    -webkit-user-select: none; }
  .pan { width: 100%; height: 100%; display: flex; align-items: center; justify-content: center;
    transform-origin: 0 0; }
  .pan video { display: block; width: 100%; height: 100%; object-fit: contain; }
  .pan .live { width: 100%; max-width: calc((100dvh - 200px) * 16 / 9); }
  .clip-note { padding: 6px 16px 0; color: #bbb; font-size: 0.9em; }
  .clip-note:empty { display: none; }
  .player { display: flex; align-items: center; gap: 4px; padding: 0 6px; }
  .seek { flex: 1; min-width: 0; accent-color: var(--primary-color); }
  .time { font-size: 0.85em; color: #ccc; font-variant-numeric: tabular-nums; }
  .downloads { display: flex; flex-wrap: wrap; gap: 8px; padding: 8px 16px 16px; }
  .action { display: inline-flex; align-items: center; gap: 6px; font: inherit; font-size: 0.95em;
    padding: 8px 14px; border-radius: 18px; border: 1px solid rgba(255, 255, 255, 0.4); background: transparent;
    color: #fff; text-decoration: none; cursor: pointer; }
  .action:disabled { opacity: 0.4; cursor: default; }
  .sound { flex: 1; display: flex; flex-direction: column; justify-content: center; gap: 12px; padding: 16px; }
  .sound audio { display: block; width: 100%; }
  .ghost { align-self: flex-start; font: inherit; padding: 8px 18px; border-radius: 18px; cursor: pointer;
    background: transparent; border: 1px solid rgba(255, 255, 255, 0.6); color: #fff; }
`;

// The gallery, its paging and lazy images, Trigger siren and the viewer, shared by the panel and
// the card. Subclasses build it with _shell() and fill it with _renderWindow().
class ReviewList extends HTMLElement {
  constructor() {
    super();
    this._types = null;
    this._observer = null;
    this._moreObserver = null;
    this._poll = null;
    this._liveCard = null;
    this._clipRequest = 0;
    // The listed alerts by id: each is listed once, and the viewer's swipes open them.
    this._items = new Map();
    // The sentinel and last item of the page to load next, and that load while it runs.
    this._next = null;
    this._loading = null;
    // The alert the viewer shows.
    this._current = null;
    this._level = storedLevel();
    this._lastDay = null;
    // The day that was today when the day headers were labelled.
    this._labelDay = null;
    this._end = null;
    // Set by subclasses: day headers, the end-of-log note, and the text of an empty window.
    this._dayHeaders = false;
    this._endNote = false;
    this._emptyText = "Nothing happened in this time.";
  }

  // Everything that runs on its own: observers and the clip poll.
  _stop() {
    if (this._observer) this._observer.disconnect();
    if (this._moreObserver) this._moreObserver.disconnect();
    this._stopPoll();
  }

  _toast(message) {
    this.dispatchEvent(
      new CustomEvent("hass-notification", { detail: { message }, bubbles: true, composed: true }),
    );
  }

  // The host's own styles, and what goes above the content.
  _hostStyle() {
    return "";
  }

  _header() {
    return null;
  }

  _shell() {
    if (this._root) return;
    this._root = this.attachShadow({ mode: "open" });
    this._root.append(h("style", { text: this._hostStyle() + STYLE }));
    this._siren = h("button", { class: "siren", onclick: () => this._triggerSiren() }, "Trigger siren");
    this._windowText = h("div", { class: "window" });
    this._smaller = h("button", { class: "size", "aria-label": "Smaller photos", text: "−", onclick: () => this._setLevel(this._level + 1) });
    this._bigger = h("button", { class: "size", "aria-label": "Bigger photos", text: "+", onclick: () => this._setLevel(this._level - 1) });
    this._list = h("div", { class: "list" });
    this._dialog = h("dialog", {
      class: "viewer",
      tabindex: "-1",
      onclose: () => this._closeClip(),
      onkeydown: (ev) => this._viewerKey(ev),
    });
    const content = h("div", { class: "content" }, [
      h("div", { class: "controls" }, [this._siren]),
      h("div", { class: "bar" }, [this._windowText, h("div", { class: "sizes" }, [this._smaller, this._bigger])]),
      this._list,
    ]);
    const header = this._header();
    if (header) this._root.append(header);
    this._root.append(content, this._dialog);
    this._listenZoom(content);
    new ResizeObserver(() => this._applyLevel()).observe(content);
    this._applyLevel();
  }

  // Top controls

  async _triggerSiren() {
    this._siren.disabled = true;
    try {
      const answer = await this._hass.callWS({ type: "security_alerts/siren" });
      this._toast(answer.message);
    } catch (err) {
      this._toast(`Could not trigger the siren: ${err.message || err}`);
    } finally {
      this._siren.disabled = false;
    }
  }

  // Gallery levels

  // Pinch on a phone; Ctrl+scroll, or a trackpad pinch, on a computer.
  _listenZoom(el) {
    let pinch = null;
    let wheel = 0;
    const fingers = (ev) => [...ev.touches].slice(0, 2).map((t) => ({ x: t.clientX, y: t.clientY }));
    el.addEventListener(
      "touchstart",
      (ev) => {
        if (ev.touches.length !== 2) return;
        const [a, b] = fingers(ev);
        pinch = { spread: Math.max(distance(a, b), 1), level: this._level };
      },
      { passive: true },
    );
    el.addEventListener(
      "touchmove",
      (ev) => {
        if (!pinch || ev.touches.length !== 2) return;
        ev.preventDefault();
        const [a, b] = fingers(ev);
        const steps = Math.round(Math.log(distance(a, b) / pinch.spread) / Math.log(PINCH_STEP));
        // Spreading the fingers makes the photos bigger: fewer per row.
        this._setLevel(pinch.level - steps, midpoint(a, b));
      },
      { passive: false },
    );
    const lifted = (ev) => {
      if (ev.touches.length < 2) pinch = null;
    };
    el.addEventListener("touchend", lifted);
    el.addEventListener("touchcancel", lifted);
    el.addEventListener(
      "wheel",
      (ev) => {
        if (!ev.ctrlKey) return;
        ev.preventDefault();
        wheel += ev.deltaY;
        if (Math.abs(wheel) < WHEEL_STEP) return;
        const step = Math.sign(wheel);
        wheel = 0;
        this._setLevel(this._level + step, { x: ev.clientX, y: ev.clientY });
      },
      { passive: false },
    );
  }

  // Keeps what is under `point` (else the first thing on screen) where it is on screen.
  _setLevel(level, point) {
    const next = clamp(level, MIN_LEVEL, MAX_LEVEL);
    if (next === this._level) return;
    const anchor = this._anchor(point);
    const top = anchor ? anchor.getBoundingClientRect().top : 0;
    this._level = next;
    storeLevel(next);
    this._applyLevel();
    if (anchor) scroller(this).scrollTop += anchor.getBoundingClientRect().top - top;
  }

  _anchor(point) {
    const hit = point ? this._root.elementFromPoint(point.x, point.y) : null;
    const item = hit ? hit.closest(".list > *") : null;
    if (item && this._list.contains(item)) return item;
    return [...this._list.children].find((el) => el.getBoundingClientRect().bottom > 0) || null;
  }

  // Level 1 shows full frames, one per row; the others crops, more per row on wider lists.
  _applyLevel() {
    const full = this._level === 1;
    const view = full ? "list full" : "list grid";
    if (this._list.className !== view) {
      this._list.className = view;
      this._reloadImages();
    }
    const perRow = full ? 1 : Math.max(this._level, Math.round((this._level * this._list.clientWidth) / PHONE_WIDTH));
    this._list.style.setProperty("--per-row", String(perRow));
    this._smaller.disabled = this._level === MAX_LEVEL;
    this._bigger.disabled = this._level === MIN_LEVEL;
  }

  // Full frames and crops are different images: load the other kind, near the screen first.
  _reloadImages() {
    if (this._observer) this._observer.disconnect();
    for (const img of this._list.querySelectorAll(".shot img")) img.removeAttribute("src");
    this._loadImages([this._list]);
  }

  // The list

  _renderWindow(result) {
    this._window = result;
    this._count = 0;
    this._items = new Map();
    this._next = null;
    this._loading = null;
    this._lastDay = null;
    this._end = null;
    if (this._observer) this._observer.disconnect();
    if (this._moreObserver) this._moreObserver.disconnect();
    if (!result.items.length && this._emptyText) {
      this._showCount(false);
      this._list.replaceChildren(h("div", { class: "empty", text: this._emptyText }));
      return;
    }
    this._list.replaceChildren();
    this._appendPage(result);
  }

  // The line above the list.
  _showCount(_more) {}

  _dayHeader(item) {
    const today = this._relabelDays();
    return h("div", {
      class: "day",
      "data-day": item.day,
      "data-day-name": item.day_name,
      text: dayLabel(item.day, item.day_name, today),
    });
  }

  // Renames the day headers once a new day has begun since they were labelled, so the list left
  // open past midnight has one "Today". Returns today, in Home Assistant's time zone.
  _relabelDays() {
    const timeZone = this._hass && this._hass.config ? this._hass.config.time_zone : undefined;
    const today = isoDate(new Date(), timeZone);
    if (today === this._labelDay) return today;
    this._labelDay = today;
    for (const header of this._list.querySelectorAll(".day")) {
      header.textContent = dayLabel(header.dataset.day, header.dataset.dayName, today);
    }
    return today;
  }

  _updateEnd() {
    if (this._end) this._end.textContent = endText(this._types && this._types.log_days);
  }

  // Appends one page; a sentinel at the end fetches the next page when it nears the screen.
  _appendPage(page) {
    const elements = [];
    for (const item of page.items) {
      if (this._dayHeaders && item.day !== this._lastDay) elements.push(this._dayHeader(item));
      this._lastDay = item.day;
      this._items.set(item.id, item);
      elements.push(this._renderItem(item));
    }
    this._list.append(...elements);
    this._count += page.items.length;
    this._showCount(page.more);
    this._loadImages(elements);
    if (!page.more) {
      if (this._endNote) {
        this._end = h("div", { class: "more" });
        this._updateEnd();
        this._list.append(this._end);
      }
      return;
    }
    const sentinel = h("div", { class: "more", text: "Loading more…" });
    this._list.append(sentinel);
    this._next = { sentinel, last: page.items[page.items.length - 1] };
    this._moreObserver = new IntersectionObserver(
      (entries, observer) => {
        if (!entries.some((e) => e.isIntersecting)) return;
        observer.disconnect();
        this._loadMore();
      },
      { rootMargin: PRELOAD_MARGIN },
    );
    this._moreObserver.observe(sentinel);
  }

  // Loads the next page once, however often it is asked for while loading. Resolves to whether a
  // page was added to the list shown now.
  _loadMore() {
    if (this._loading) return this._loading;
    const next = this._next;
    if (!next) return Promise.resolve(false);
    this._next = null;
    const shown = this._window;
    const loading = this._hass
      .callWS({
        type: "security_alerts/review/get",
        from: shown.from,
        to: shown.to,
        after_time: next.last.time,
        after_id: next.last.id,
      })
      .then(
        (page) => {
          if (this._window !== shown) return false;
          next.sentinel.remove();
          this._appendPage(page);
          return true;
        },
        (err) => {
          next.sentinel.textContent = `Could not load more: ${err.message || err}`;
          return false;
        },
      )
      .finally(() => {
        if (this._loading === loading) this._loading = null;
      });
    this._loading = loading;
    return loading;
  }

  // An alert logged while the list is open goes on top, under its day's header.
  _prepend(item) {
    if (this._items.has(item.id)) return;
    this._items.set(item.id, item);
    const element = this._renderItem(item);
    const first = this._list.firstElementChild;
    if (!this._dayHeaders) this._list.prepend(element);
    else if (first && first.dataset.day === item.day) first.after(element);
    else this._list.prepend(this._dayHeader(item), element);
    this._loadImages([element]);
  }

  _badge(item) {
    const text = BADGES[item.delivery];
    return text ? h("span", { class: "badge", text }) : null;
  }

  // A detection's photo holds both images: the full frame for level 1 and the crop for the grid.
  _renderItem(item) {
    if (item.kind === "door" || item.kind === "motion") {
      return h("div", { class: "row" }, [
        h("span", { class: "type", text: item.type_name }),
        h("span", { text: sensorText(item) }),
        this._badge(item),
      ]);
    }
    const img = h("img", {
      "data-full": item.image,
      "data-crop": item.crop,
      alt: `${item.type_name} at ${item.name}`,
      decoding: "async",
    });
    const shot = h(
      "button",
      {
        class: "shot",
        "aria-label": `Play the ${item.type_name} clip from ${item.clock}`,
        onclick: () => this._openClip(item.id, item),
      },
      [img, h("span", { class: "when", text: item.clock }), this._badge(item)],
    );
    img.addEventListener("error", () => this._mediaFailed(() => shot.classList.add("failed")));
    const header = h("header", {}, [
      h("span", { class: "type", text: item.type_name }),
      h("span", { class: "meta", text: `${item.name} · ${item.clock}` }),
      this._badge(item),
    ]);
    return h("article", { class: "tile", "data-id": item.id }, [header, shot]);
  }

  // A signed URL in the list did not load; `fallback` shows it. The card may reload instead.
  _mediaFailed(fallback) {
    fallback();
  }

  // Images on the first screen load at once with high priority; the rest when scrolled near.
  _loadImages(elements) {
    const load = (img) => {
      img.parentElement.classList.remove("failed");
      img.src = this._level === 1 ? img.dataset.full : img.dataset.crop;
    };
    if (!this._observer) {
      this._observer = new IntersectionObserver(
        (entries, observer) => {
          for (const entry of entries) {
            if (!entry.isIntersecting) continue;
            observer.unobserve(entry.target);
            load(entry.target);
          }
        },
        { rootMargin: PRELOAD_MARGIN },
      );
    }
    // Wait a frame so the list has its layout.
    requestAnimationFrame(() => {
      const screen = window.innerHeight;
      const images = elements.flatMap((el) => [...el.querySelectorAll(".shot img:not([src])")]);
      for (const img of images) {
        if (img.getBoundingClientRect().top < screen) {
          img.setAttribute("fetchpriority", "high");
          load(img);
        } else {
          img.setAttribute("loading", "lazy");
          img.setAttribute("fetchpriority", "low");
          this._observer.observe(img);
        }
      }
    });
  }

  // The viewer

  // A sound (only ?clip= opens one) plays its audio; a detection its video.
  async _openClip(alertId, item) {
    const request = this._nextClipRequest();
    this._dialog.replaceChildren(this._viewerBar("Loading…"));
    if (!this._dialog.open) this._dialog.showModal();
    try {
      const alert = item || (await this._fetchAlert(alertId));
      if (!this._isCurrentClip(request)) return;
      this._showClip(alert, alert.kind === "sound" ? SOUND_MODE : VIDEO_MODE);
    } catch (err) {
      if (!this._isCurrentClip(request)) return;
      this._dialog.replaceChildren(
        this._viewerBar(""),
        h("div", { class: "error", text: `Could not open the clip: ${err.message || err}` }),
      );
    }
  }

  _fetchAlert(alertId) {
    return this._hass.callWS({ type: "security_alerts/alert", alert_id: alertId });
  }

  // Each open, mode switch, swipe and close is a new request for the viewer: it stops the poll,
  // the players and the live view. Async work started for an earlier one is dropped, so a late
  // answer never replaces what the viewer shows now.
  _nextClipRequest() {
    this._stopPoll();
    stopMedia(this._dialog);
    this._liveCard = null;
    this._clipRequest += 1;
    return this._clipRequest;
  }

  _isCurrentClip(request) {
    return request === this._clipRequest && this._dialog.open;
  }

  _viewerBar(title) {
    return h("div", { class: "viewer-bar" }, [
      h("div", { class: "viewer-title", text: title }),
      h("button", { class: "icon", "aria-label": "Close", onclick: () => this._dialog.close() }, icon("close")),
    ]);
  }

  _viewerKey(ev) {
    if (ev.target instanceof HTMLInputElement) return;
    if (ev.key === "ArrowRight") this._step(1);
    else if (ev.key === "ArrowLeft") this._step(-1);
  }

  _showClip(item, mode) {
    this._nextClipRequest();
    this._current = item;
    this._renderClip(item, mode);
    // Replacing the content drops the focus; the viewer keeps it, for its keys.
    this._dialog.focus({ preventScroll: true });
  }

  _renderClip(item, mode) {
    const bar = this._viewerBar(`${item.type_name} · ${item.name} · ${item.clock}`);
    const note = h("div", { class: "clip-note" });
    const downloads = h("div", { class: "downloads" }, [
      item.kind === "detection" ? downloadLink("Download snapshot", item.image_download) : null,
      downloadLink("Download video", item.clip && item.clip.download),
    ]);
    if (mode === SOUND_MODE) {
      this._showSound(item, bar, note, downloads);
      return;
    }
    const pan = h("div", { class: "pan" });
    const stage = h("div", { class: "stage" }, pan);
    new ZoomStage(stage, pan, (step) => this._step(step));
    const url = mediaUrl(item, VIDEO_MODE);
    if (url) {
      const video = h("video", { playsinline: true, autoplay: true, preload: "auto" });
      video.addEventListener("error", () => {
        note.textContent = "The clip could not be played; the recording may not be saved yet.";
      });
      video.src = url;
      pan.append(video);
      this._dialog.replaceChildren(bar, stage, note, playerControls(video), downloads);
      this._play(video);
      return;
    }
    note.textContent = "Live view until the clip is saved.";
    this._dialog.replaceChildren(bar, stage, note, downloads);
    this._showLive(pan, item.camera_entity, note);
    this._pollUntilReady(item, VIDEO_MODE);
  }

  // Sound mode: the audio, trying to autoplay, and a Video button that switches this viewer.
  _showSound(item, bar, note, downloads) {
    const video = h("button", { class: "ghost", text: "Video", onclick: () => this._showClip(item, VIDEO_MODE) });
    const url = mediaUrl(item, SOUND_MODE);
    if (!url) {
      note.textContent = "The sound is ready about 30 s after it ends.";
      this._dialog.replaceChildren(bar, h("div", { class: "sound" }, [note, video]), downloads);
      this._pollUntilReady(item, SOUND_MODE);
      return;
    }
    const audio = h("audio", { controls: true, autoplay: true, preload: "auto" });
    audio.addEventListener("error", () => {
      note.textContent = "The sound could not be played; try again in a moment.";
    });
    audio.src = url;
    this._dialog.replaceChildren(bar, h("div", { class: "sound" }, [note, audio, video]), downloads);
    // If the WebView blocks autoplay, the controls stay for one tap.
    this._play(audio);
  }

  _play(media) {
    const playing = media.play();
    if (playing && typeof playing.catch === "function") playing.catch(() => {});
  }

  // The next (1, older) or previous (-1, newer) detection in the list, loading older pages past
  // its end. An alert that is not in the list, like a sound, has none.
  async _step(step) {
    const current = this._current;
    if (!current) return;
    const ids = () => [...this._list.querySelectorAll(".tile")].map((tile) => tile.dataset.id);
    let shown = ids();
    const index = shown.indexOf(current.id);
    if (index < 0) return;
    while (step > 0 && index + step >= shown.length && (await this._loadMore())) shown = ids();
    // The viewer may have moved on or closed while a page loaded.
    if (this._current !== current || !this._dialog.open) return;
    const id = shown[index + step];
    if (id) this._openClip(id, this._items.get(id));
  }

  // Asks for the alert every few seconds and shows it in this mode once its recording is saved.
  _pollUntilReady(item, mode) {
    const request = this._clipRequest;
    this._poll = setInterval(async () => {
      try {
        const fresh = await this._fetchAlert(item.id);
        if (this._isCurrentClip(request) && mediaUrl(fresh, mode)) this._showClip(fresh, mode);
      } catch (_err) {
        // Keep waiting; the next poll tries again.
      }
    }, POLL_CLIP_MS);
  }

  async _showLive(body, entity, note) {
    if (!entity || !window.loadCardHelpers) {
      note.textContent = "The clip appears here once it is saved.";
      return;
    }
    const helpers = await window.loadCardHelpers();
    // The viewer may have closed or moved on while the helpers loaded.
    if (!this._dialog.open || !body.isConnected) return;
    const card = helpers.createCardElement({
      type: "picture-entity",
      entity,
      camera_view: "live",
      show_name: false,
      show_state: false,
      tap_action: { action: "none" },
      hold_action: { action: "none" },
    });
    card.classList.add("live");
    card.hass = this._hass;
    this._liveCard = card;
    body.append(card);
  }

  _stopPoll() {
    if (this._poll) clearInterval(this._poll);
    this._poll = null;
  }

  _closeClip() {
    this._nextClipRequest();
    this._current = null;
    this._dialog.replaceChildren();
  }
}

class SecurityReviewPanel extends ReviewList {
  constructor() {
    super();
    this._search = null;
  }

  set hass(hass) {
    this._hass = hass;
    if (this._menu) this._menu.hass = hass;
    if (this._liveCard) this._liveCard.hass = hass;
    // The frontend may keep a hidden panel; only follow the URL while it is ours.
    if (!window.location.pathname.startsWith(PANEL_PATH)) return;
    const search = this._currentSearch();
    if (search !== this._search) {
      this._search = search;
      this._start(search);
    }
  }

  set narrow(narrow) {
    this._narrow = narrow;
    if (this._menu) this._menu.narrow = narrow;
  }

  disconnectedCallback() {
    this._stop();
  }

  _currentSearch() {
    const fallback = initialSearch;
    initialSearch = "";
    if (this._search === null && !window.location.search && fallback) return fallback;
    return window.location.search;
  }

  _hostStyle() {
    return PANEL_STYLE;
  }

  _header() {
    const toolbar = h("div", { class: "toolbar" });
    if (customElements.get("ha-menu-button")) {
      this._menu = document.createElement("ha-menu-button");
      this._menu.hass = this._hass;
      this._menu.narrow = this._narrow;
      toolbar.append(this._menu);
    }
    toolbar.append(h("span", { text: "Security review" }));
    return toolbar;
  }

  async _start(search) {
    this._shell();
    const params = new URLSearchParams(search || "");
    const clip = params.get("clip");
    const from = params.get("from");
    const to = params.get("to");
    this._list.replaceChildren(h("div", { class: "empty", text: "Loading…" }));
    try {
      let result;
      if (clip) {
        result = await this._hass.callWS({ type: "security_alerts/review/get" });
      } else if (from && to) {
        result = await this._hass.callWS({ type: "security_alerts/review/get", from: Number(from), to: Number(to) });
      } else {
        result = await this._hass.callWS({ type: "security_alerts/review/start" });
        const url = `${window.location.pathname}?from=${result.from}&to=${result.to}`;
        window.history.replaceState(window.history.state, "", url);
        this._search = window.location.search;
      }
      this._renderWindow(result);
      if (clip) this._openClip(clip);
    } catch (err) {
      this._list.replaceChildren(h("div", { class: "error", text: `Could not load alerts: ${err.message || err}` }));
    }
  }

  _showCount(more) {
    const w = this._window;
    const n = `${this._count}${more ? "+" : ""}`;
    this._windowText.textContent = `${w.from_clock} to ${w.to_clock} · ${n} alert${n === "1" ? "" : "s"}`;
  }
}

// The Review tab: every alert in the log from now back, under day headers. Opening it records no
// review and clears no notification.
class SecurityReviewCard extends ReviewList {
  constructor() {
    super();
    this._dayHeaders = true;
    this._endNote = true;
    this._emptyText = null;
    // Bumped on each start and stop, so answers for an earlier start are dropped.
    this._run = 0;
    this._running = false;
    this._unsubscribe = null;
    // Alerts pushed before the first page is shown.
    this._pending = null;
    this._dayCheck = null;
    // When the first page was asked for: its URLs are the oldest in the list.
    this._startedAt = null;
    this._onVisibility = () => {
      if (document.visibilityState !== "visible") return;
      if (this._expired()) this._restart();
      else this._relabelDays();
    };
  }

  static getStubConfig() {
    return {};
  }

  // Dashboards require it; the card has no options.
  setConfig(_config) {}

  getCardSize() {
    return 12;
  }

  set hass(hass) {
    this._hass = hass;
    if (this._liveCard) this._liveCard.hass = hass;
    if (this.isConnected && !this._running) this._start();
  }

  connectedCallback() {
    if (this._hass && !this._running) this._start();
  }

  disconnectedCallback() {
    this._stop();
  }

  _stop() {
    super._stop();
    this._run += 1;
    this._running = false;
    this._pending = null;
    if (this._unsubscribe) unsubscribeQuietly(this._unsubscribe);
    this._unsubscribe = null;
    clearInterval(this._dayCheck);
    this._dayCheck = null;
    document.removeEventListener("visibilitychange", this._onVisibility);
    if (this._dialog && this._dialog.open) this._dialog.close();
  }

  _hostStyle() {
    return CARD_STYLE;
  }

  // Whether the list's signed URLs may have expired.
  _expired() {
    return this._running && Date.now() - this._startedAt >= SIGNED_URL_REFRESH_MS;
  }

  _restart() {
    this._stop();
    this._start();
  }

  _mediaFailed(fallback) {
    if (this._expired()) this._restart();
    else super._mediaFailed(fallback);
  }

  // A clip from an old list asks for its alert again, for freshly signed URLs.
  _openClip(alertId, item) {
    return super._openClip(alertId, this._expired() ? null : item);
  }

  // The log's retention, for the end of the list.
  async _loadTypes() {
    try {
      this._types = await this._hass.callWS({ type: "security_alerts/types" });
      this._updateEnd();
    } catch (_err) {
      // The end of the list then names no retention.
    }
  }

  // Subscribes before anything else, so nothing logged while the first page loads is missed;
  // an alert both pushed and on that page is shown once.
  async _start() {
    this._running = true;
    this._startedAt = Date.now();
    const run = ++this._run;
    this._shell();
    this._windowText.textContent = "All alerts · newest first";
    this._list.replaceChildren(h("div", { class: "empty", text: "Loading…" }));
    this._pending = [];
    this._dayCheck = setInterval(() => this._relabelDays(), DAY_CHECK_MS);
    document.addEventListener("visibilitychange", this._onVisibility);
    try {
      const subscribed = this._hass.connection.subscribeMessage((item) => this._pushed(run, item), {
        type: "security_alerts/review/subscribe",
      });
      if (!this._types) this._loadTypes();
      const unsubscribe = await subscribed;
      if (run !== this._run) {
        unsubscribeQuietly(unsubscribe);
        return;
      }
      this._unsubscribe = unsubscribe;
      const result = await this._hass.callWS({ type: "security_alerts/review/get", from: 0 });
      if (run !== this._run) return;
      this._renderWindow(result);
      const pending = this._pending;
      this._pending = null;
      for (const item of pending) this._prepend(item);
    } catch (err) {
      if (run !== this._run) return;
      this._list.replaceChildren(h("div", { class: "error", text: `Could not load alerts: ${err.message || err}` }));
    }
  }

  _pushed(run, item) {
    if (run !== this._run) return;
    if (this._pending) this._pending.push(item);
    else this._prepend(item);
  }
}

if (!customElements.get("security-review-panel")) {
  customElements.define("security-review-panel", SecurityReviewPanel);
}
if (!customElements.get("security-review-card")) {
  customElements.define("security-review-card", SecurityReviewCard);
}
window.customCards = window.customCards || [];
if (!window.customCards.some((c) => c.type === "security-review-card")) {
  window.customCards.push({
    type: "security-review-card",
    name: "Security review",
    description: "Every security alert as a zoomable photo gallery, newest first, with Trigger siren: the Review tab.",
  });
}
