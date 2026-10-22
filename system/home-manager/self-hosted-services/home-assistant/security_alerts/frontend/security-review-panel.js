// Security review: every alert since the last review, newest first.
//
// Opened at /security-review by tapping a security notification. With no query it records a
// review (security_alerts/review/start) and rewrites the URL to ?from=&to=, so a reload shows
// the same window without recording another. ?clip=<alert id> (the Play clip button) opens that
// alert over the window since the last review, without recording one: a sound plays its audio,
// a detection its video.
// Sounds show no picture: their row plays the audio in place, and Video opens the clip.
// Images, audio and clips come as URLs signed for the logged-in user; this file holds no data.

const PANEL_PATH = "/security-review";
const POLL_CLIP_MS = 5000;
// Images this far below the screen start loading before they scroll in.
const PRELOAD_MARGIN = "600px 0px";
const BADGES = { paused: "Paused" };
// Types and cameras come from Frigate's config, which may not be loaded yet.
const TYPES_RETRY_MS = 30000;
// The popup plays a sound's audio or an alert's video.
const SOUND_MODE = "sound";
const VIDEO_MODE = "video";

// Read at module load too: the frontend may rewrite the URL before the first panel starts.
// Only that first panel may use it; later ones would replay a stale clip or window.
let initialSearch = typeof window !== "undefined" ? window.location.search : "";

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

// The signed URL the popup plays in this mode, once the recording is saved.
function mediaUrl(item, mode) {
  const media = mode === SOUND_MODE ? item.audio : item.clip;
  return media && media.ready && media.url ? media.url : null;
}

// Pauses and unloads every player in `root`, so nothing keeps playing or downloading.
function stopMedia(root) {
  for (const media of root.querySelectorAll("audio, video")) {
    media.pause();
    media.removeAttribute("src");
    media.load();
  }
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
  .no-image { display: flex; align-items: center; justify-content: center; height: 100%; color: #aaa; }
  .more { padding: 16px; text-align: center; color: var(--secondary-text-color); }
  .row { display: flex; align-items: center; gap: 10px; padding: 12px; background: var(--card-background-color);
    border-radius: 12px; border: 1px solid var(--divider-color); }
  .row .type { font-size: 0.95em; }
  .sound { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 10px; padding: 0 12px 12px; }
  .sound audio { flex: 1 1 240px; min-width: 0; }
  .ghost { font: inherit; padding: 8px 18px; border-radius: 18px; cursor: pointer; background: transparent;
    border: 1px solid var(--primary-color); color: var(--primary-color); }
  .empty, .error { padding: 24px 8px; text-align: center; color: var(--secondary-text-color); }
  .error { color: var(--error-color, #db4437); }
  dialog { padding: 0; border: 0; background: transparent; max-width: min(96vw, 1100px); width: 96vw; }
  dialog::backdrop { background: rgba(0, 0, 0, 0.75); }
  .clip-body { background: var(--card-background-color); color: var(--primary-text-color);
    border-radius: 12px; padding: 12px; }
  .clip-title { font-weight: 600; margin-bottom: 4px; }
  .clip-note { color: var(--secondary-text-color); font-size: 0.9em; margin-bottom: 8px; }
  video { display: block; width: 100%; max-height: 75vh; background: #000; border-radius: 8px; }
  .clip-body audio { display: block; width: 100%; margin-bottom: 10px; }
`;

class SecurityReviewPanel extends HTMLElement {
  constructor() {
    super();
    this._search = null;
    this._types = null;
    this._snoozeTypes = new Set();
    this._snoozeHours = null;
    this._observer = null;
    this._moreObserver = null;
    this._typesRetry = null;
    this._poll = null;
    this._liveCard = null;
    this._clipRequest = 0;
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
    if (this._moreObserver) this._moreObserver.disconnect();
    clearTimeout(this._typesRetry);
    this._stopPoll();
  }

  _currentSearch() {
    const fallback = initialSearch;
    initialSearch = "";
    if (this._search === null && !window.location.search && fallback) return fallback;
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
    if (this._typesLoading || (this._types && this._types.cameras.length)) return;
    this._typesLoading = true;
    clearTimeout(this._typesRetry);
    try {
      this._types = await this._hass.callWS({ type: "security_alerts/types" });
      if (this._snoozeHours === null) this._snoozeHours = this._types.durations[0];
      this._renderSnooze();
    } catch (err) {
      if (!this._types) {
        this._snooze.replaceChildren(h("div", { class: "error", text: `Snooze is unavailable: ${err.message || err}` }));
      }
    } finally {
      this._typesLoading = false;
    }
    // No cameras yet: Frigate's config has not arrived, so ask again later.
    if (!this._types || !this._types.cameras.length) {
      this._typesRetry = setTimeout(() => this._loadTypes(), TYPES_RETRY_MS);
    }
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
    this._window = result;
    this._count = 0;
    if (this._observer) this._observer.disconnect();
    if (this._moreObserver) this._moreObserver.disconnect();
    if (!result.items.length) {
      this._showCount(false);
      this._list.replaceChildren(h("div", { class: "empty", text: "Nothing happened in this time." }));
      return;
    }
    this._list.replaceChildren();
    this._appendPage(result);
  }

  _showCount(more) {
    const w = this._window;
    const n = `${this._count}${more ? "+" : ""}`;
    this._windowText.textContent = `${w.from_clock} to ${w.to_clock} · ${n} alert${n === "1" ? "" : "s"}`;
  }

  // Appends one page; a sentinel at the end fetches the next page when it nears the screen.
  _appendPage(page) {
    const items = page.items.map((item) => this._renderItem(item));
    this._list.append(...items);
    this._count += page.items.length;
    this._showCount(page.more);
    this._loadImages(items);
    if (!page.more) return;
    const last = page.items[page.items.length - 1];
    const sentinel = h("div", { class: "more", text: "Loading more…" });
    this._list.append(sentinel);
    this._moreObserver = new IntersectionObserver(
      async (entries, observer) => {
        if (!entries.some((e) => e.isIntersecting)) return;
        observer.disconnect();
        try {
          const next = await this._hass.callWS({
            type: "security_alerts/review/get",
            from: this._window.from,
            to: this._window.to,
            after_time: last.time,
            after_id: last.id,
          });
          sentinel.remove();
          this._appendPage(next);
        } catch (err) {
          sentinel.textContent = `Could not load more: ${err.message || err}`;
        }
      },
      { rootMargin: PRELOAD_MARGIN },
    );
    this._moreObserver.observe(sentinel);
  }

  _badge(item) {
    const text = BADGES[item.delivery];
    return text ? h("span", { class: "badge", text }) : null;
  }

  _cardHeader(item) {
    return h("header", {}, [
      h("span", { class: "type", text: item.type_name }),
      h("span", { class: "meta", text: `${item.name} · ${item.clock}` }),
      this._badge(item),
    ]);
  }

  _renderItem(item) {
    if (item.kind === "door" || item.kind === "motion") {
      return h("div", { class: "row" }, [
        h("span", { class: "type", text: item.type_name }),
        h("span", { text: sensorText(item) }),
        this._badge(item),
      ]);
    }
    if (item.kind === "sound") return this._renderSound(item);
    const img = h("img", { "data-src": item.image, alt: `${item.type_name} at ${item.name}`, decoding: "async" });
    img.addEventListener("error", () => img.replaceWith(h("div", { class: "no-image", text: "No image" })));
    return h("article", { class: "card" }, [
      this._cardHeader(item),
      h("button", { class: "shot", "aria-label": `Play the ${item.type_name} clip`, onclick: () => this._openClip(item.id, item) }, img),
    ]);
  }

  // A sound plays in place; nothing downloads until play is pressed. Before its recording is
  // saved, Play sound opens the popup, which waits for it.
  _renderSound(item) {
    const url = mediaUrl(item, SOUND_MODE);
    const player = url
      ? h("audio", { controls: true, preload: "none", src: url, "aria-label": `${item.type_name} at ${item.name}` })
      : h("button", { class: "go", text: "Play sound", onclick: () => this._openClip(item.id, item, SOUND_MODE) });
    return h("article", { class: "card" }, [
      this._cardHeader(item),
      h("div", { class: "sound" }, [
        player,
        h("button", { class: "ghost", text: "Video", onclick: () => this._openClip(item.id, item, VIDEO_MODE) }),
      ]),
    ]);
  }

  // Images on the first screen load at once with high priority; the rest when scrolled near.
  _loadImages(elements) {
    const load = (img) => {
      img.src = img.dataset.src;
      img.removeAttribute("data-src");
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
      const images = elements.flatMap((el) => [...el.querySelectorAll("img[data-src]")]);
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

  // The clip popup

  // Without a mode (?clip=), a sound opens in sound mode and a detection in video mode.
  async _openClip(alertId, item, mode) {
    const request = this._nextClipRequest();
    // The popup plays on its own: pause any sound playing in the list.
    for (const audio of this._list.querySelectorAll("audio")) audio.pause();
    this._dialog.replaceChildren(h("div", { class: "clip-body" }, h("div", { class: "clip-note", text: "Loading…" })));
    if (!this._dialog.open) this._dialog.showModal();
    try {
      const alert = item || (await this._fetchAlert(alertId));
      if (!this._isCurrentClip(request)) return;
      this._showClip(alert, mode || (alert.kind === "sound" ? SOUND_MODE : VIDEO_MODE));
    } catch (err) {
      if (!this._isCurrentClip(request)) return;
      this._dialog.replaceChildren(h("div", { class: "clip-body" }, h("div", { class: "error", text: `Could not open the clip: ${err.message || err}` })));
    }
  }

  _fetchAlert(alertId) {
    return this._hass.callWS({ type: "security_alerts/alert", alert_id: alertId });
  }

  // Each open, mode switch and close is a new request for the popup: it stops the poll, the
  // players and the live view. Async work started for an earlier one is dropped, so a late
  // answer never replaces what the popup shows now.
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

  _showClip(item, mode) {
    this._nextClipRequest();
    const title = h("div", { class: "clip-title", text: `${item.type_name} · ${item.name} · ${item.clock}` });
    if (mode === SOUND_MODE) {
      this._showSound(item, title);
      return;
    }
    const url = mediaUrl(item, VIDEO_MODE);
    if (url) {
      const note = h("div", { class: "clip-note" });
      const video = h("video", { controls: true, playsinline: true, autoplay: true, preload: "auto" });
      video.addEventListener("error", () => {
        note.textContent = "The clip could not be played; the recording may not be saved yet.";
      });
      video.src = url;
      this._dialog.replaceChildren(h("div", { class: "clip-body" }, [title, note, video]));
      this._play(video);
      return;
    }
    const note = h("div", { class: "clip-note", text: "Live view until the clip is saved." });
    const body = h("div", { class: "clip-body" }, [title, note]);
    this._dialog.replaceChildren(body);
    this._showLive(body, item.camera_entity, note);
    this._pollUntilReady(item, VIDEO_MODE);
  }

  // Sound mode: the audio, trying to autoplay, and a Video button that switches this popup.
  _showSound(item, title) {
    const video = h("button", { class: "ghost", text: "Video", onclick: () => this._showClip(item, VIDEO_MODE) });
    const url = mediaUrl(item, SOUND_MODE);
    if (!url) {
      const note = h("div", { class: "clip-note", text: "The sound is ready about 30 s after it ends." });
      this._dialog.replaceChildren(h("div", { class: "clip-body" }, [title, note, video]));
      this._pollUntilReady(item, SOUND_MODE);
      return;
    }
    const note = h("div", { class: "clip-note" });
    const audio = h("audio", { controls: true, autoplay: true, preload: "auto" });
    audio.addEventListener("error", () => {
      note.textContent = "The sound could not be played; try again in a moment.";
    });
    audio.src = url;
    this._dialog.replaceChildren(h("div", { class: "clip-body" }, [title, note, audio, video]));
    // If the WebView blocks autoplay, the controls stay for one tap.
    this._play(audio);
  }

  _play(media) {
    const playing = media.play();
    if (playing && typeof playing.catch === "function") playing.catch(() => {});
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
    // The popup may have closed or moved on while the helpers loaded.
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
    this._dialog.replaceChildren();
  }
}

if (!customElements.get("security-review-panel")) {
  customElements.define("security-review-panel", SecurityReviewPanel);
}
