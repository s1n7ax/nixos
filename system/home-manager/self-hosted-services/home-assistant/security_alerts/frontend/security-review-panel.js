// Security review: every alert since the last review, newest first.
//
// Opened at /security-review by tapping a security notification. With no query it records a
// review (security_alerts/review/start) and rewrites the URL to ?from=&to=, so a reload shows
// the same window without recording another. ?clip=<alert id> (the Play clip button) opens that
// alert's clip over the window since the last review, without recording one.
// Images and clips come as URLs signed for the logged-in user; this file holds no data.

const PANEL_PATH = "/security-review";
const POLL_CLIP_MS = 5000;
// Images this far below the screen start loading before they scroll in.
const PRELOAD_MARGIN = "600px 0px";
const BADGES = { paused: "Paused" };

// Read at module load too: the frontend may rewrite the URL before the panel starts.
const INITIAL_SEARCH = typeof window !== "undefined" ? window.location.search : "";

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

function hoursLabel(hours) {
  return `${hours} h`;
}

function sensorText(item) {
  if (item.kind === "door") return `${item.name} ${item.action || "opened"} ${item.clock}`;
  return `Motion: ${item.name} ${item.clock}`;
}

const STYLE = `
  :host { display: block; height: 100%; overflow-y: auto; background: var(--primary-background-color);
    color: var(--primary-text-color); font-family: var(--paper-font-body1_-_font-family, Roboto, sans-serif); }
  .toolbar { position: sticky; top: 0; z-index: 2; display: flex; align-items: center; gap: 8px; height: 56px;
    padding: 0 12px; background: var(--app-header-background-color, var(--primary-color));
    color: var(--app-header-text-color, #fff); font-size: 20px; }
  .content { max-width: 900px; margin: 0 auto; padding: 12px 12px 48px; }
  .controls { display: grid; gap: 12px; margin-bottom: 16px; }
  .siren { font: inherit; font-size: 1.05em; font-weight: 600; padding: 14px; border: 0; border-radius: 12px;
    background: var(--error-color, #db4437); color: #fff; cursor: pointer; }
  .siren:disabled { opacity: 0.6; }
  .snooze { background: var(--card-background-color); border-radius: 12px; padding: 12px;
    box-shadow: var(--ha-card-box-shadow, none); border: 1px solid var(--divider-color); }
  .snooze h2 { font-size: 1em; margin: 0 0 8px; font-weight: 500; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
  .chip { font: inherit; font-size: 0.9em; padding: 6px 12px; border-radius: 16px; cursor: pointer;
    border: 1px solid var(--divider-color); background: transparent; color: var(--primary-text-color); }
  .chip[aria-pressed="true"] { background: var(--primary-color); border-color: var(--primary-color);
    color: var(--text-primary-color, #fff); }
  .go { font: inherit; padding: 8px 18px; border-radius: 18px; border: 0; cursor: pointer;
    background: var(--primary-color); color: var(--text-primary-color, #fff); }
  .go:disabled { opacity: 0.5; cursor: default; }
  .window { color: var(--secondary-text-color); margin: 8px 2px 12px; font-size: 0.95em; }
  .list { display: grid; gap: 12px; }
  .card { background: var(--card-background-color); border-radius: 12px; overflow: hidden;
    border: 1px solid var(--divider-color); }
  .card header { display: flex; align-items: baseline; flex-wrap: wrap; gap: 4px 10px; padding: 10px 12px; }
  .type { font-weight: 600; font-size: 1.05em; }
  .meta { color: var(--secondary-text-color); }
  .badge { margin-left: auto; font-size: 0.8em; padding: 2px 8px; border-radius: 10px;
    background: var(--warning-color, #ffa600); color: #000; }
  .shot { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: contain; background: #111;
    cursor: pointer; border: 0; padding: 0; }
  .shot img { display: block; width: 100%; height: 100%; object-fit: contain; }
  .row { display: flex; align-items: center; gap: 10px; padding: 12px; background: var(--card-background-color);
    border-radius: 12px; border: 1px solid var(--divider-color); }
  .row .type { font-size: 0.95em; }
  .empty, .error { padding: 24px 8px; text-align: center; color: var(--secondary-text-color); }
  .error { color: var(--error-color, #db4437); }
  dialog { padding: 0; border: 0; background: transparent; max-width: min(96vw, 1100px); width: 96vw; }
  dialog::backdrop { background: rgba(0, 0, 0, 0.75); }
  .clip-body { background: var(--card-background-color); color: var(--primary-text-color);
    border-radius: 12px; padding: 12px; }
  .clip-title { font-weight: 600; margin-bottom: 4px; }
  .clip-note { color: var(--secondary-text-color); font-size: 0.9em; margin-bottom: 8px; }
  video { display: block; width: 100%; max-height: 75vh; background: #000; border-radius: 8px; }
`;

class SecurityReviewPanel extends HTMLElement {
  constructor() {
    super();
    this._search = null;
    this._types = null;
    this._snoozeTypes = new Set();
    this._snoozeHours = null;
    this._observer = null;
    this._poll = null;
    this._liveCard = null;
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
    if (this._observer) this._observer.disconnect();
    this._stopPoll();
  }

  _currentSearch() {
    if (this._search === null && !window.location.search && INITIAL_SEARCH) return INITIAL_SEARCH;
    return window.location.search;
  }

  _toast(message) {
    this.dispatchEvent(
      new CustomEvent("hass-notification", { detail: { message }, bubbles: true, composed: true }),
    );
  }

  _shell() {
    if (this._root) return;
    this._root = this.attachShadow({ mode: "open" });
    this._root.append(h("style", { text: STYLE }));
    const toolbar = h("div", { class: "toolbar" });
    if (customElements.get("ha-menu-button")) {
      this._menu = document.createElement("ha-menu-button");
      this._menu.hass = this._hass;
      this._menu.narrow = this._narrow;
      toolbar.append(this._menu);
    }
    toolbar.append(h("span", { text: "Security review" }));
    this._siren = h("button", { class: "siren", onclick: () => this._triggerSiren() }, "Trigger siren");
    this._snooze = h("div", { class: "snooze" });
    this._windowText = h("div", { class: "window" });
    this._list = h("div", { class: "list" });
    this._dialog = h("dialog", {
      onclick: (ev) => {
        if (ev.target === this._dialog) this._dialog.close();
      },
      onclose: () => this._closeClip(),
    });
    this._root.append(
      toolbar,
      h("div", { class: "content" }, [
        h("div", { class: "controls" }, [this._siren, this._snooze]),
        this._windowText,
        this._list,
      ]),
      this._dialog,
    );
  }

  async _start(search) {
    this._shell();
    this._loadTypes();
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

  async _loadTypes() {
    if (this._types) return;
    try {
      this._types = await this._hass.callWS({ type: "security_alerts/types" });
    } catch (err) {
      this._snooze.replaceChildren(h("div", { class: "error", text: `Snooze is unavailable: ${err.message || err}` }));
      return;
    }
    this._snoozeHours = this._types.durations[0];
    this._renderSnooze();
  }

  _renderSnooze() {
    const types = this._types.types.map((t) =>
      h("button", {
        class: "chip",
        "aria-pressed": String(this._snoozeTypes.has(t.id)),
        text: t.name,
        onclick: () => {
          if (this._snoozeTypes.has(t.id)) this._snoozeTypes.delete(t.id);
          else this._snoozeTypes.add(t.id);
          this._renderSnooze();
        },
      }),
    );
    const durations = this._types.durations.map((hours) =>
      h("button", {
        class: "chip",
        "aria-pressed": String(hours === this._snoozeHours),
        text: hoursLabel(hours),
        onclick: () => {
          this._snoozeHours = hours;
          this._renderSnooze();
        },
      }),
    );
    const go = h("button", {
      class: "go",
      text: "Snooze",
      disabled: this._snoozeTypes.size === 0,
      onclick: () => this._doSnooze(go),
    });
    this._snooze.replaceChildren(
      h("h2", { text: "Snooze" }),
      h("div", { class: "chips" }, types),
      h("div", { class: "chips" }, durations),
      go,
    );
  }

  async _doSnooze(button) {
    button.disabled = true;
    const types = [...this._snoozeTypes];
    try {
      await this._hass.callWS({ type: "security_alerts/quiet/add", kind: "snooze", types, hours: this._snoozeHours });
      const names = this._types.types.filter((t) => this._snoozeTypes.has(t.id)).map((t) => t.name);
      this._toast(`Snoozed ${names.join(", ")} for ${hoursLabel(this._snoozeHours)}`);
      this._snoozeTypes.clear();
      this._renderSnooze();
    } catch (err) {
      this._toast(`Could not snooze: ${err.message || err}`);
      button.disabled = false;
    }
  }

  // The list

  _renderWindow(result) {
    const count = result.items.length;
    this._windowText.textContent = `${result.from_clock} to ${result.to_clock} · ${count} alert${count === 1 ? "" : "s"}`;
    if (!count) {
      this._list.replaceChildren(h("div", { class: "empty", text: "Nothing happened in this time." }));
      return;
    }
    this._list.replaceChildren(...result.items.map((item) => this._renderItem(item)));
    this._loadImages();
  }

  _badge(item) {
    const text = BADGES[item.delivery];
    return text ? h("span", { class: "badge", text }) : null;
  }

  _renderItem(item) {
    if (item.kind === "door" || item.kind === "motion") {
      return h("div", { class: "row" }, [
        h("span", { class: "type", text: item.type_name }),
        h("span", { text: sensorText(item) }),
        this._badge(item),
      ]);
    }
    const img = h("img", { "data-src": item.image, alt: `${item.type_name} at ${item.name}`, decoding: "async" });
    return h("article", { class: "card" }, [
      h("header", {}, [
        h("span", { class: "type", text: item.type_name }),
        h("span", { class: "meta", text: `${item.name} · ${item.clock}` }),
        this._badge(item),
      ]),
      h("button", { class: "shot", "aria-label": `Play the ${item.type_name} clip`, onclick: () => this._openClip(item.id, item) }, img),
    ]);
  }

  _loadImages() {
    if (this._observer) this._observer.disconnect();
    const load = (img) => {
      img.src = img.dataset.src;
      img.removeAttribute("data-src");
    };
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
    // Wait a frame so the list has its layout, then load the first screen first.
    requestAnimationFrame(() => {
      const screen = window.innerHeight;
      for (const img of this._list.querySelectorAll("img[data-src]")) {
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

  // The clip popup

  async _openClip(alertId, item) {
    this._stopPoll();
    this._dialog.replaceChildren(h("div", { class: "clip-body" }, h("div", { class: "clip-note", text: "Loading…" })));
    if (!this._dialog.open) this._dialog.showModal();
    try {
      this._showClip(item || (await this._fetchAlert(alertId)));
    } catch (err) {
      this._dialog.replaceChildren(h("div", { class: "clip-body" }, h("div", { class: "error", text: `Could not open the clip: ${err.message || err}` })));
    }
  }

  _fetchAlert(alertId) {
    return this._hass.callWS({ type: "security_alerts/alert", alert_id: alertId });
  }

  _showClip(item) {
    const title = h("div", { class: "clip-title", text: `${item.type_name} · ${item.name} · ${item.clock}` });
    if (item.clip && item.clip.ready && item.clip.url) {
      const note = h("div", { class: "clip-note" });
      const video = h("video", { controls: true, playsinline: true, autoplay: true, preload: "auto" });
      video.addEventListener("error", () => {
        note.textContent = "The clip could not be played; the recording may not be saved yet.";
      });
      video.src = item.clip.url;
      this._dialog.replaceChildren(h("div", { class: "clip-body" }, [title, note, video]));
      const playing = video.play();
      if (playing && typeof playing.catch === "function") playing.catch(() => {});
      return;
    }
    const note = h("div", { class: "clip-note", text: "Live view until the clip is saved." });
    const body = h("div", { class: "clip-body" }, [title, note]);
    this._dialog.replaceChildren(body);
    this._showLive(body, item.camera_entity, note);
    this._poll = setInterval(async () => {
      try {
        const fresh = await this._fetchAlert(item.id);
        if (fresh.clip && fresh.clip.ready && this._dialog.open) {
          this._stopPoll();
          this._showClip(fresh);
        }
      } catch (_err) {
        // Keep the live view; the next poll tries again.
      }
    }, POLL_CLIP_MS);
  }

  async _showLive(body, entity, note) {
    if (!entity || !window.loadCardHelpers) {
      note.textContent = "The clip appears here once it is saved.";
      return;
    }
    const helpers = await window.loadCardHelpers();
    if (!this._dialog.open) return;
    const card = helpers.createCardElement({
      type: "picture-entity",
      entity,
      camera_view: "live",
      show_name: false,
      show_state: false,
      tap_action: { action: "none" },
      hold_action: { action: "none" },
    });
    card.hass = this._hass;
    this._liveCard = card;
    body.append(card);
  }

  _stopPoll() {
    if (this._poll) clearInterval(this._poll);
    this._poll = null;
  }

  _closeClip() {
    this._stopPoll();
    this._liveCard = null;
    for (const video of this._dialog.querySelectorAll("video")) {
      video.pause();
      video.removeAttribute("src");
      video.load();
    }
    this._dialog.replaceChildren();
  }
}

if (!customElements.get("security-review-panel")) {
  customElements.define("security-review-panel", SecurityReviewPanel);
}
