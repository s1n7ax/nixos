#!/usr/bin/env python3
"""Throwaway rig for wayfinder issue #134, forked from #133's recover.py.

Every prototype before this one carried a single audio stream - the mic - and
used it only to check that a seam did not drift. #121 asks for more:

1. mic AND desktop audio mixed into one track,
2. the camera's ~165ms lag corrected so the face matches the voice,
3. the raw streams kept on disk beside the mix,
4. a level meter that shows audio is actually being recorded.

This rig builds all four and measures them. Nothing here ships; the verdict
lives in the ticket.
"""

import argparse
import json
import os
import pathlib
import signal
import shlex
import subprocess
import sys
import threading
import time

import gi

gi.require_version("Gst", "1.0")

from gi.repository import Gio, GLib, Gst  # noqa: E402

CANVAS_W = 2560
CANVAS_H = 1440
CAM_W = 1024
CAM_H = 576
TOKEN_CACHE = pathlib.Path.home() / ".cache" / "proto133-restore-token"
NULL_SINK = "proto133mic"
DESK_SINK = "proto134desk"

FEEDS = ("screen", "camera", "mic", "deskaudio")

TOKEN_SEQ = [0]


def now() -> float:
    return time.monotonic()


def log(msg: str) -> None:
    print(f"[{now() - T0:7.3f}] {msg}", flush=True)


T0 = now()


# --------------------------------------------------------------------------
# pipewire registry


def pw_nodes():
    """Every PipeWire node as (id, serial, name, description, media class).

    `pw-dump` rather than a libpipewire binding: this is a measuring rig, and
    #130 already established that the thing to get right is *which* identifier
    is used, not how it is fetched.
    """
    r = subprocess.run(["pw-dump"], capture_output=True, text=True)
    out = []
    try:
        dump = json.loads(r.stdout or "[]")
    except json.JSONDecodeError:
        return out
    for obj in dump:
        if obj.get("type") != "PipeWire:Interface:Node":
            continue
        props = (obj.get("info") or {}).get("props") or {}
        out.append(
            {
                "id": obj.get("id"),
                "serial": props.get("object.serial"),
                "name": props.get("node.name"),
                "desc": props.get("node.description"),
                "class": props.get("media.class"),
            }
        )
    return out


def resolve_mic(match: str):
    """Find the audio source whose node.name contains `match`.

    A node's *serial* is what `pipewiresrc target-object` actually honours
    (#130: a node name is silently ignored and the default source is used
    instead), and a serial is new every time the node appears - so this has to
    be re-run on every recovery, never cached.
    """
    cands = [
        n
        for n in pw_nodes()
        if (n["class"] or "").startswith("Audio/Source")
        or (n["class"] or "") == "Audio/Sink"
    ]
    hits = [n for n in cands if match and match in (n["name"] or "")]
    if not hits:
        hits = [n for n in cands if match and match in (n["desc"] or "")]
    return hits[0] if hits else None


def resolve_sink(match: str):
    """Find the Audio/Sink whose node.name (or description) contains `match`.

    Desktop audio is captured from a sink's *monitor*, so the node we want is
    the sink itself; `stream.capture.sink=true` on the stream is what turns a
    playback node into a capture of what it is playing.
    """
    cands = [n for n in pw_nodes() if (n["class"] or "") == "Audio/Sink"]
    hits = [n for n in cands if match and match in (n["name"] or "")]
    if not hits:
        hits = [n for n in cands if match and match in (n["desc"] or "")]
    return hits[0] if hits else None


# --------------------------------------------------------------------------
# portal


class Screencast:
    """One ScreenCast session, held for the whole run.

    #126 crashed Hyprland 0.55.4 by opening a fresh session per variant, so
    this object is created exactly once and never re-handshakes. It also
    subscribes to org.freedesktop.portal.Session.Closed, which is the only
    authoritative "your desktop feed is gone" signal available.
    """

    def __init__(self, cursor: bool = True, token_cache: pathlib.Path = None,
                 use_token: bool = True):
        self.token_cache = token_cache or TOKEN_CACHE
        self.use_token = use_token
        self.had_token = use_token and self.token_cache.exists()
        self.token_in = (
            self.token_cache.read_text().strip() if self.had_token else None
        )
        self.token_out = None
        self.handshake_s = None
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.sender = self.bus.get_unique_name()[1:].replace(".", "_")
        self.proxy = Gio.DBusProxy.new_sync(
            self.bus,
            Gio.DBusProxyFlags.NONE,
            None,
            "org.freedesktop.portal.Desktop",
            "/org/freedesktop/portal/desktop",
            "org.freedesktop.portal.ScreenCast",
            None,
        )
        self.seq = 0
        self.session = None
        self.node = None
        self.fd = None
        self.closed_at = None
        self.on_closed = None
        self.session_token = None
        log(f"portal: proxy ready, handshake (cached token: "
            f"{'yes' if self.had_token else 'NO - picker expected'})")
        t0 = now()
        self._handshake(cursor)
        self.handshake_s = now() - t0
        log(f"portal: handshake done in {self.handshake_s * 1000:.0f}ms")

    def _token(self, kind: str) -> str:
        TOKEN_SEQ[0] += 1
        return f"proto130_{kind}_{os.getpid()}_{TOKEN_SEQ[0]}"

    def _request(self, method, build_args, on_done, result, loop):
        tok = self._token("req")
        path = f"/org/freedesktop/portal/desktop/request/{self.sender}/{tok}"
        sub = [None]

        def handler(_c, _s, _p, _i, _sig, params):
            self.bus.signal_unsubscribe(sub[0])
            code, results = params.unpack()
            if code != 0:
                result["error"] = f"{method} failed (code {code})"
                loop.quit()
                return
            on_done(results)

        sub[0] = self.bus.signal_subscribe(
            "org.freedesktop.portal.Desktop",
            "org.freedesktop.portal.Request",
            "Response",
            path,
            None,
            Gio.DBusSignalFlags.NONE,
            handler,
        )
        self.proxy.call_sync(method, build_args(tok), Gio.DBusCallFlags.NONE, -1, None)

    def _new_session_token(self) -> str:
        self.session_token = self._token("sess")
        return self.session_token

    def kill_stream(self):
        """Destroy the live stream while keeping the session object.

        Re-running CreateSession with the SAME session_handle_token makes
        xdg-desktop-portal-hyprland log "Stream destroyed" and stop feeding
        the existing PipeWire node, without a Session.Closed signal. That is
        the shape #130 asks about: the feed dies inside a held session.

        Do not use this twice in one boot: it leaves xdg-desktop-portal stuck
        on "Failed to close session implementation: Timeout was reached", and
        every later CreateSession from any client times out until the frontend
        is restarted. Prefer the killnode event.
        """
        loop = GLib.MainLoop()
        result = {}
        tok = self.session_token
        self._request(
            "CreateSession",
            lambda t: GLib.Variant(
                "(a{sv})",
                (
                    {
                        "handle_token": GLib.Variant("s", t),
                        "session_handle_token": GLib.Variant("s", tok),
                    },
                ),
            ),
            lambda _r: loop.quit(),
            result,
            loop,
        )
        GLib.timeout_add(3000, loop.quit)
        loop.run()
        return result.get("error")

    def _handshake(self, cursor: bool):
        loop = GLib.MainLoop()
        result = {}

        def on_started(results):
            log(f"portal: Start returned {results}")
            tok_out = results.get("restore_token")
            self.token_out = tok_out
            if tok_out:
                self.token_cache.parent.mkdir(parents=True, exist_ok=True)
                self.token_cache.write_text(tok_out)
                same = "SAME as the one sent" if tok_out == self.token_in else "NEW"
                log(f"portal: Start returned a restore_token ({same}), cached")
            else:
                log("portal: Start returned NO restore_token")
            streams = results.get("streams") or []
            if not streams:
                result["error"] = "portal returned no streams"
            else:
                self.node = streams[0][0]
            loop.quit()

        def start():
            self._request(
                "Start",
                lambda tok: GLib.Variant(
                    "(osa{sv})",
                    (self.session, "", {"handle_token": GLib.Variant("s", tok)}),
                ),
                on_started,
                result,
                loop,
            )

        def select_sources():
            def args(tok):
                opts = {
                    "handle_token": GLib.Variant("s", tok),
                    "types": GLib.Variant("u", 1),
                    "multiple": GLib.Variant("b", False),
                    "cursor_mode": GLib.Variant("u", 2 if cursor else 1),
                    "persist_mode": GLib.Variant("u", 2),
                }
                if self.token_in:
                    opts["restore_token"] = GLib.Variant("s", self.token_in)
                return GLib.Variant("(oa{sv})", (self.session, opts))

            log("portal: SelectSources")
            self._request("SelectSources", args, lambda _r: start(), result, loop)

        def on_session(results):
            log("portal: CreateSession ok")
            self.session = results["session_handle"]
            self.bus.signal_subscribe(
                "org.freedesktop.portal.Desktop",
                "org.freedesktop.portal.Session",
                "Closed",
                self.session,
                None,
                Gio.DBusSignalFlags.NONE,
                self._on_closed,
            )
            select_sources()

        self._request(
            "CreateSession",
            lambda tok: GLib.Variant(
                "(a{sv})",
                (
                    {
                        "handle_token": GLib.Variant("s", tok),
                        "session_handle_token": GLib.Variant(
                            "s", self._new_session_token()
                        ),
                    },
                ),
            ),
            on_session,
            result,
            loop,
        )
        loop.run()
        if "error" in result:
            raise RuntimeError(result["error"])

        reply, fds = self.proxy.call_with_unix_fd_list_sync(
            "OpenPipeWireRemote",
            GLib.Variant("(oa{sv})", (self.session, {})),
            Gio.DBusCallFlags.NONE,
            -1,
            None,
            None,
        )
        self.fd = fds.get(reply.unpack()[0])

    def close(self):
        """Close this session's portal object.

        #126's crash came from churning sessions, so the rig can hold them all
        instead. Holding leaks one session per recovery for the life of the
        program, which is why whether closing the *old* one after a successful
        swap is safe is worth knowing.
        """
        try:
            Gio.DBusProxy.new_sync(
                self.bus, Gio.DBusProxyFlags.NONE, None,
                "org.freedesktop.portal.Desktop", self.session,
                "org.freedesktop.portal.Session", None,
            ).call_sync("Close", None, Gio.DBusCallFlags.NONE, 2000, None)
            return None
        except GLib.Error as exc:
            return str(exc)

    def _on_closed(self, *_a):
        self.closed_at = now()
        log("PORTAL: Session.Closed signal received")
        if self.on_closed:
            self.on_closed()

    def alive(self) -> bool:
        """Ask the portal whether the session object still exists."""
        try:
            Gio.DBusProxy.new_sync(
                self.bus,
                Gio.DBusProxyFlags.DO_NOT_LOAD_PROPERTIES
                | Gio.DBusProxyFlags.DO_NOT_CONNECT_SIGNALS,
                None,
                "org.freedesktop.portal.Desktop",
                self.session,
                "org.freedesktop.DBus.Peer",
                None,
            ).call_sync("Ping", None, Gio.DBusCallFlags.NONE, 2000, None)
            return True
        except GLib.Error as exc:
            return "UnknownObject" not in str(exc) and "UnknownMethod" in str(exc)


# --------------------------------------------------------------------------
# the rig


class Rig:
    def __init__(self, args):
        self.args = args
        self.cast = None
        self.mic_node = None
        self.old_casts = []
        self.screen_bin = None
        self.screen_gen = 0
        self.recasts = 0
        self.retries = {f: 0 for f in FEEDS}
        self.gave_up = {}
        self.died_at = {}
        self.attempted_at = {}
        self.waiting = {}
        self.watched = {}
        self.watch_proc = None
        self.revive_floor = {}
        self.rebuilds = {"mic": 0, "screen": 0, "deskaudio": 0}
        self.desk_node = None
        self.levels = {}
        self.level_counts = {}
        self.level_max = {}
        self.delays = {}
        self.paused = True  # startup counts as the first pause interval
        self.armed = set()
        self.total_offset = 0  # ns of wall clock excised so far
        self.pause_rt = 0
        self.stable_since = None
        self.dead = set()
        self.events = []  # measured latencies
        self.counts = {f: 0 for f in FEEDS}
        self.last_seen = {f: now() for f in FEEDS}
        self.max_gap = {f: 0.0 for f in FEEDS}
        self.enabled = set()
        self.progress_fd = None
        self.last_mux_pts = 0
        self.first_mux_pts = None
        self.mux_buffers = 0
        self.manual_pause = False
        self.started = False
        self.clock_logged = False
        self.stopping = False
        self.loop = GLib.MainLoop()
        self.timeouts = {
            "screen": args.screen_timeout / 1000.0,
            "camera": args.cam_timeout / 1000.0,
            "mic": args.mic_timeout / 1000.0,
            "deskaudio": args.desk_timeout / 1000.0,
        }

    # ---- build ----------------------------------------------------------

    def build(self):
        log("build: begin")
        a = self.args
        if a.fake_screen:
            screen = (
                f"videotestsrc pattern={a.screen_pattern} is-live=true "
                "! video/x-raw,width=3440,height=1440,framerate=60/1 "
                "! glupload ! glcolorconvert"
            )
        else:
            self.cast = Screencast(
                token_cache=pathlib.Path(a.token_cache),
                use_token=not a.no_token,
            )
            log(f"portal: fd={self.cast.fd} node={self.cast.node}")
            screen = None
            self.enabled.add("screen")

        if a.fake_camera:
            cam = (
                "videotestsrc pattern=ball is-live=true "
                f"! video/x-raw,width={CAM_W},height={CAM_H},framerate=50/1 "
                "! videoconvert"
            )
        else:
            cam = (
                f"v4l2src name=cam device={a.camera} "
                f"! image/jpeg,width={CAM_W},height={CAM_H} "
                "! jpegdec ! videoflip method=horizontal-flip"
            )
        if not a.no_camera:
            self.enabled.add("camera")

        if a.muxer == "hybrid":
            mux = (
                f"mp4mux name=mux fragment-duration={a.frag} "
                "fragment-mode=first-moov-then-finalise"
            )
        elif a.muxer == "dash":
            mux = f"mp4mux name=mux fragment-duration={a.frag}"
        else:
            mux = f"isofmp4mux name=mux fragment-duration={a.frag * 1000000}"
            if a.iso_finalise:
                mux += " header-update-mode=rewrite write-mehd=true"

        # ---- audio -----------------------------------------------------
        #
        # mic ---level--valve--tee--[delay]--\
        #                         \           audiomixer--aac--> track 1 (mix)
        # desk--level--valve--tee--[delay]--/
        #                     \   \--aac--> track 3 (raw desk, --raw-tracks)
        #                      \-----aac--> track 2 (raw mic,  --raw-tracks)
        #
        # One valve per SOURCE, not one per track: the pause has to excise the
        # same wall-clock from the mix and from both raw tracks, or the three
        # drift apart at the first dead feed.
        audio = ""
        if not a.no_audio:
            if a.mic_match:
                node = resolve_mic(a.mic_match)
                if not node:
                    raise RuntimeError(f"no audio node matching {a.mic_match!r}")
                self.mic_node = node
                self.watched["mic"] = node["id"]
                log(f"mic: id={node['id']} serial={node['serial']} "
                    f"name={node['name']} class={node['class']}")
                target = f"target-object={node['serial']} "
            else:
                target = f"target-object={a.mic} " if a.mic else ""
            audio += (
                f" pipewiresrc name=mic {target}do-timestamp=true "
                "! audio/x-raw,channels=2 "
                f"! queue max-size-time={a.audio_queue * 1000000} "
                "! valve name=micvalve "
                f"! level name=miclevel post-messages=true "
                f"interval={a.meter * 1000000} "
                "! audioconvert ! audioresample ! tee name=mict "
            )
            self.enabled.add("mic")

        if a.desk_audio:
            # No target-object at all, plus stream.capture.sink=true, follows
            # the DEFAULT sink - and keeps following it when the default
            # changes mid-recording, which is what a bluetooth headset
            # connecting looks like. --desk-match pins one sink instead.
            if a.desk_match:
                sink = resolve_sink(a.desk_match)
                if not sink:
                    raise RuntimeError(f"no Audio/Sink matching {a.desk_match!r}")
                self.desk_node = sink
                self.watched["deskaudio"] = sink["id"]
                log(f"deskaudio: id={sink['id']} serial={sink['serial']} "
                    f"name={sink['name']}")
                dtarget = f"target-object={sink['serial']} "
            else:
                dtarget = ""
                log("deskaudio: following the default sink (no target-object)")
            audio += (
                f" pipewiresrc name=desk {dtarget}do-timestamp=true "
                'stream-properties="props,stream.capture.sink=true" '
                "! audio/x-raw,channels=2 "
                f"! queue max-size-time={a.audio_queue * 1000000} "
                "! valve name=deskvalve "
                f"! level name=desklevel post-messages=true "
                f"interval={a.meter * 1000000} "
                "! audioconvert ! audioresample ! tee name=deskt "
            )
            self.enabled.add("deskaudio")

        mixpad = 0
        if not a.no_audio or a.desk_audio:
            # mixvalve, on top of the per-source valves, because `audiomixer`
            # SYNTHESISES SILENCE for a pad with no data. Closing the source
            # valves stops the inputs but not the mixer: it keeps emitting on
            # the clock, and those silence buffers sail into the encoder with
            # timestamps inside the paused region that `total_offset` has not
            # grown to cover yet. Measured: a 6.6s pause put 6.6s of digital
            # silence into the mixed track while both raw tracks joined
            # cleanly. The video branch never had this problem because its
            # valve is downstream of the compositor.
            audio += (
                " audiomixer name=amix latency="
                f"{max(a.mic_delay, a.desk_delay, 0) * 1000000 + 100000000} "
                "start-time-selection=first "
                f"! level name=mixlevel post-messages=true "
                f"interval={a.meter * 1000000} "
                "! valve name=mixvalve ! audioconvert ! audioresample "
                "! avenc_aac name=mixaac bitrate=192000 ! aacparse ! queue "
                f"! mux.{'sink_1' if a.muxer == 'isofmp4' else 'audio_0'} "
            )
            if not a.no_audio:
                audio += (
                    f" mict. ! queue max-size-time={(a.mic_delay + 400) * 1000000} "
                    f"max-size-buffers=0 max-size-bytes=0 ! amix.sink_{mixpad} "
                )
                self.mic_mixpad = mixpad
                mixpad += 1
            if a.desk_audio:
                audio += (
                    f" deskt. ! queue max-size-time={(a.desk_delay + 400) * 1000000} "
                    f"max-size-buffers=0 max-size-bytes=0 ! amix.sink_{mixpad} "
                )
                self.desk_mixpad = mixpad
                mixpad += 1

        raw_pad = 2
        if a.raw_tracks:
            if not a.no_audio:
                audio += (
                    " mict. ! queue ! avenc_aac name=rawmicaac bitrate=192000 "
                    f"! aacparse ! queue ! mux.sink_{raw_pad} "
                )
                self.rawmic_pad = raw_pad
                raw_pad += 1
            if a.desk_audio:
                audio += (
                    " deskt. ! queue ! avenc_aac name=rawdeskaac bitrate=192000 "
                    f"! aacparse ! queue ! mux.sink_{raw_pad} "
                )
                self.rawdesk_pad = raw_pad
                raw_pad += 1
        if a.raw_files:
            if not a.no_audio:
                audio += (
                    " mict. ! queue ! audioconvert ! wavenc "
                    f"! filesink name=rawmicsink location={a.record}.mic.wav "
                )
            if a.desk_audio:
                audio += (
                    " deskt. ! queue ! audioconvert ! wavenc "
                    f"! filesink name=rawdesksink location={a.record}.desk.wav "
                )

        head = (
            "glvideomixer name=mix background=black "
            f"! video/x-raw(memory:GLMemory),width={CANVAS_W},height={CANVAS_H},"
            "framerate=60/1 "
        )
        if a.tee:
            head += (
                "! tee name=t "
                "t. ! queue max-size-buffers=3 leaky=downstream "
                "! glcolorconvert ! fakesink sync=false "
                "t. "
            )
        desc = (
            head
            + "! queue max-size-buffers=6 ! valve name=vvalve "
            "! queue max-size-buffers=6 "
            f"! nvh264enc bitrate={a.bitrate} rc-mode=cbr gop-size=120 "
            f"! h264parse ! queue ! {mux} ! filesink name=sink "
            f"location={a.record} "
            + (f"{screen} ! mix.sink_0 " if screen else "")
        )
        if not a.no_camera:
            desc += (
                f"{cam} ! glupload ! glcolorconvert "
                "! video/x-raw(memory:GLMemory),format=RGBA ! mix.sink_1 "
            )
        desc += audio

        log(f"pipeline: {desc}")
        self.pipeline = Gst.parse_launch(desc)
        self.mix = self.pipeline.get_by_name("mix")
        if self.cast:
            self.screen_bin = self.make_screen_bin(self.cast)
            self.pipeline.add(self.screen_bin)
            self.screen_bin.get_static_pad("src").link(
                self.mix.request_pad_simple("sink_0")
            )
        self.vvalve = self.pipeline.get_by_name("vvalve")
        self.micvalve = self.pipeline.get_by_name("micvalve")
        self.deskvalve = self.pipeline.get_by_name("deskvalve")
        self.mixvalve = self.pipeline.get_by_name("mixvalve")
        self.avalves = [
            v for v in (self.micvalve, self.deskvalve, self.mixvalve) if v
        ]
        self.amix = self.pipeline.get_by_name("amix")
        self.mux = self.pipeline.get_by_name("mux")

        self.vpad = self.vvalve.get_static_pad("sink")
        self.vsrc = self.vvalve.get_static_pad("src")
        self.micpad = self.micvalve.get_static_pad("sink") if self.micvalve else None
        self.deskpad = (self.deskvalve.get_static_pad("sink")
                        if self.deskvalve else None)

        if self.cast:
            self.cast.on_closed = lambda: GLib.idle_add(
                self.mark_dead, "screen", "portal Session.Closed"
            )

        # geometry: desktop centre-cropped, camera as the 440px corner circle
        # box (no shader here - #126 settled the look, this rig measures time)
        pad0 = self.mix.get_static_pad("sink_0") or self.mix.get_static_pad("sink_0")
        pad0.set_property("xpos", 0)
        pad0.set_property("ypos", 0)
        pad0.set_property("width", CANVAS_W)
        pad0.set_property("height", CANVAS_H)
        pad0.set_property("zorder", 1)
        pad0.add_probe(Gst.PadProbeType.BUFFER, self.saw, "screen")
        if not self.args.no_camera:
            pad1 = self.mix.get_static_pad("sink_1")
            pad1.set_property("xpos", CANVAS_W - 440 - 48)
            pad1.set_property("ypos", CANVAS_H - 440 - 48)
            pad1.set_property("width", 440)
            pad1.set_property("height", 440)
            pad1.set_property("zorder", 2)
            pad1.add_probe(Gst.PadProbeType.BUFFER, self.saw, "camera")
        if self.micpad:
            self.micpad.add_probe(Gst.PadProbeType.BUFFER, self.saw, "mic")
        if self.deskpad:
            self.deskpad.add_probe(Gst.PadProbeType.BUFFER, self.saw, "deskaudio")

        # ---- the sync delays --------------------------------------------
        #
        # The camera feed is ~165ms behind the mic (#127), so a composited
        # frame shows a face that is 165ms older than the sound recorded
        # beside it. Pushing the mic's timestamps FORWARD by that much puts
        # the voice back on the face. The same arithmetic, with its own
        # number, holds the desktop audio against the screen.
        self.apply_delays()

        self.vvalve.set_property("drop", True)
        for v in self.avalves:
            v.set_property("drop", True)
        self.vmux, self.amux = self.mux_pads()
        self.vsrc.add_probe(Gst.PadProbeType.BUFFER, self.on_video_out)
        for name in ("mixaac", "rawmicaac", "rawdeskaac"):
            el = self.pipeline.get_by_name(name)
            if el:
                el.get_static_pad("sink").add_probe(
                    Gst.PadProbeType.BUFFER, self.on_audio_out
                )
                log(f"excision probe on {name}")
        self.vmux.add_probe(Gst.PadProbeType.BUFFER, self.on_mux)

        if self.args.meter:
            bus_meter = self.pipeline.get_bus()
            bus_meter.connect("message::element", self.on_level)

        if self.args.progress:
            self.progress_fd = os.open(
                self.args.progress, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644
            )

        if self.args.system_clock:
            clock = Gst.SystemClock.obtain()
            self.pipeline.use_clock(clock)
            log("pinned the pipeline to GstSystemClock")

        bus = self.pipeline.get_bus()
        bus.add_signal_watch()
        bus.connect("message::error", self.on_error)
        bus.connect("message::warning", self.on_warning)
        bus.connect("message::eos", self.on_eos)

    def mux_pads(self):
        """Request-pad names differ: mp4mux video_0/audio_0, isofmp4mux sink_N.

        Video is linked first in the pipeline description, so it always takes
        the first request pad. Caps are not negotiated until data flows, so
        the pads cannot be told apart by media type at this point.
        """
        if self.args.muxer == "isofmp4":
            return (self.mux.get_static_pad("sink_0"),
                    self.mux.get_static_pad("sink_1"))
        return (self.mux.get_static_pad("video_0"),
                self.mux.get_static_pad("audio_0"))

    # ---- probes ---------------------------------------------------------

    def saw(self, _pad, _info, feed):
        t = now()
        if feed not in self.armed:
            self.armed.add(feed)
            log(f"LIVE  {feed}: first buffer")
            self.events.append({"kind": "live", "feed": feed, "t": t - T0})
        gap = t - self.last_seen[feed]
        if self.counts[feed] and gap > self.max_gap[feed]:
            self.max_gap[feed] = gap
        self.last_seen[feed] = t
        self.counts[feed] += 1
        return Gst.PadProbeReturn.OK

    def on_video_out(self, _pad, info):
        """Rewrite-mode timestamp surgery, applied before the encoder."""
        if self.args.offset_mode != "rewrite" or not self.total_offset:
            return Gst.PadProbeReturn.OK
        buf = info.get_buffer()
        if buf.pts != Gst.CLOCK_TIME_NONE and buf.pts >= self.total_offset:
            buf.pts -= self.total_offset
        if buf.dts != Gst.CLOCK_TIME_NONE and buf.dts >= self.total_offset:
            buf.dts -= self.total_offset
        return Gst.PadProbeReturn.OK

    def on_audio_out(self, _pad, info):
        """The same excision surgery, in front of every audio encoder.

        Three tracks now hang off the audio graph - the mix and the two raw
        streams - and a pause has to take the same wall-clock out of each one
        or they drift apart at the first dead feed.
        """
        if self.args.offset_mode != "rewrite" or not self.total_offset:
            return Gst.PadProbeReturn.OK
        shift = self.total_offset
        buf = info.get_buffer()
        if buf.pts != Gst.CLOCK_TIME_NONE and buf.pts >= shift:
            buf.pts -= shift
        if buf.dts != Gst.CLOCK_TIME_NONE and buf.dts >= shift:
            buf.dts -= shift
        return Gst.PadProbeReturn.OK

    # ---- sync delay -----------------------------------------------------

    def apply_delays(self):
        """Push each branch's timestamps forward so the four feeds line up.

        Two places the delay can go, and the rig can do either:

        `probe`      rewrite PTS/DTS on the source side of the valve. Every
                     track downstream inherits it, so the raw mic track is
                     aligned exactly like the mix and drops straight into an
                     editor.
        `padoffset`  `gst_pad_set_offset()` on the mixer's sink pad, which is
                     what aggregator pad offsets are for. Only the mix moves;
                     the raw tracks keep source timing.
        """
        a = self.args
        self.delays = {}
        if a.mic_delay:
            self.delays["mic"] = a.mic_delay * 1000000
        if a.desk_delay:
            self.delays["deskaudio"] = a.desk_delay * 1000000
        if a.delay_mode == "probe":
            for feed, pad in (("mic", self.micpad), ("deskaudio", self.deskpad)):
                ns = self.delays.get(feed)
                if pad and ns:
                    pad.add_probe(Gst.PadProbeType.BUFFER, self.shift_pts, ns)
                    log(f"delay: {feed} +{ns / 1000000:.0f}ms by PTS rewrite "
                        "(mix and raw track both)")
        else:
            for feed, idx in (("mic", getattr(self, "mic_mixpad", None)),
                              ("deskaudio", getattr(self, "desk_mixpad", None))):
                ns = self.delays.get(feed)
                if idx is None or not ns:
                    continue
                pad = self.amix.get_static_pad(f"sink_{idx}")
                pad.set_offset(ns)
                log(f"delay: {feed} +{ns / 1000000:.0f}ms by pad offset on "
                    f"amix.sink_{idx} (mix only)")
        if a.screen_delay:
            ns = a.screen_delay * 1000000
            self.mix.get_static_pad("sink_0").set_offset(ns)
            log(f"delay: screen +{ns / 1000000:.0f}ms by pad offset on "
                "mix.sink_0 - holds GL frames, watch the buffer pool")

    @staticmethod
    def shift_pts(_pad, info, ns):
        buf = info.get_buffer()
        if buf.pts != Gst.CLOCK_TIME_NONE:
            buf.pts += ns
        if buf.dts != Gst.CLOCK_TIME_NONE:
            buf.dts += ns
        return Gst.PadProbeReturn.OK

    def on_level(self, _bus, msg):
        """What the corner preview's meter would be reading.

        Three taps, so the rig can say which one the meter should use: the two
        inputs separately, and the mix. A dead mic and a silent mic look the
        same on the mix; on the mic tap they do not, because a dead one stops
        producing messages altogether.
        """
        st = msg.get_structure()
        if not st or st.get_name() != "level":
            return
        src = msg.src.get_name()
        vals = list(st.get_value("rms") or [])
        peaks = list(st.get_value("peak") or [])
        self.levels[src] = {
            "t": round(now() - T0, 3),
            "rms": [round(v, 1) for v in vals],
            "peak": [round(v, 1) for v in peaks],
        }
        self.level_counts[src] = self.level_counts.get(src, 0) + 1
        loud = max(vals) if vals else -200.0
        self.level_max[src] = max(self.level_max.get(src, -200.0), loud)
        if self.args.meter_log:
            log(f"  meter {src:10s} rms={[round(v, 1) for v in vals]} "
                f"peak={[round(v, 1) for v in peaks]}")

    def on_mux(self, _pad, info):
        buf = info.get_buffer()
        self.mux_buffers += 1
        if buf.pts != Gst.CLOCK_TIME_NONE:
            if self.first_mux_pts is None:
                self.first_mux_pts = buf.pts
            self.last_mux_pts = buf.pts - self.first_mux_pts
        if self.progress_fd is not None and self.mux_buffers % 6 == 0:
            os.write(
                self.progress_fd,
                f"{now() - T0:.3f} {self.last_mux_pts} {self.mux_buffers}\n".encode(),
            )
        return Gst.PadProbeReturn.OK

    # ---- pause / resume -------------------------------------------------

    def rt(self) -> int:
        t = self.pipeline.get_current_running_time()
        return 0 if t == Gst.CLOCK_TIME_NONE else t

    def mark_dead(self, feed, why):
        if feed in self.dead:
            return False
        self.dead.add(feed)
        self.died_at[feed] = now()
        self.revive_floor[feed] = now()
        log(f"DEAD  {feed}: {why} "
            f"(last buffer {1000 * (now() - self.last_seen[feed]):.0f}ms ago)")
        self.events.append(
            {"kind": "dead", "feed": feed, "why": why, "t": now() - T0}
        )
        self.do_pause()
        return False

    def do_pause(self):
        if self.paused:
            return
        self.paused = True
        self.pause_rt = self.rt()
        self.vvalve.set_property("drop", True)
        for v in self.avalves:
            v.set_property("drop", True)
        self.stable_since = None
        log(f"PAUSE at running-time {self.pause_rt / Gst.SECOND:.3f}s")
        self.events.append({"kind": "pause", "t": now() - T0, "rt": self.pause_rt})

    def do_resume(self):
        if not self.paused:
            return
        gap = self.rt() - self.pause_rt
        if self.started:
            self.total_offset += gap
        else:
            self.started = True
            gap = 0
        if self.args.offset_mode != "rewrite":
            raise RuntimeError(
                "#130 settled this: only `rewrite` works. The other pad "
                "placements either do nothing or destroy what came before."
            )
        self.vvalve.set_property("drop", False)
        for v in self.avalves:
            v.set_property("drop", False)
        self.paused = False
        log(
            f"RESUME after {gap / Gst.SECOND:.3f}s "
            f"(total excised {self.total_offset / Gst.SECOND:.3f}s, "
            f"mode={self.args.offset_mode})"
        )
        self.events.append(
            {"kind": "resume", "t": now() - T0, "gap_ns": gap,
             "total_offset_ns": self.total_offset}
        )

    def watchdog(self):
        if self.stopping:
            return False
        t = now()
        if self.enabled - self.armed:
            return True
        for feed in self.enabled:
            silent = t - self.last_seen[feed]
            if silent > self.timeouts[feed]:
                if feed not in self.dead:
                    self.mark_dead(feed, f"no data for {silent * 1000:.0f}ms")
            elif feed in self.dead:
                died = self.died_at.get(feed)
                # A buffer that was already queued when the node went away is
                # not the feed coming back. Only data that arrives after the
                # replacement source is in place counts, so the floor moves
                # forward on every swap as well as on the death itself.
                if self.last_seen[feed] <= self.revive_floor.get(feed, 0):
                    continue
                self.dead.discard(feed)
                log(f"BACK  {feed}: data flowing again"
                    + (f" ({(t - died) * 1000:.0f}ms dead, "
                       f"{self.retries[feed]} recovery attempt(s))"
                       if died else ""))
                self.events.append(
                    {"kind": "back", "feed": feed, "t": now() - T0,
                     "dead_ms": round((t - died) * 1000, 1) if died else None,
                     "attempts": self.retries[feed]}
                )
                self.retries[feed] = 0
                self.gave_up.pop(feed, None)
                self.stable_since = t

        if self.args.auto_recover:
            for feed in sorted(self.dead):
                since = t - self.attempted_at.get(feed, 0)
                if since * 1000 >= self.args.retry_interval:
                    self.attempted_at[feed] = t
                    self.try_recover(feed)
        if self.paused and not self.dead and not self.manual_pause:
            if self.stable_since is None:
                self.stable_since = t
            if (t - self.stable_since) * 1000 >= self.args.resume_stable:
                self.do_resume()
        return True

    # ---- registry watch -------------------------------------------------

    def start_registry_watch(self):
        """Learn that a feed is gone from PipeWire, not from missing frames.

        A frame-arrival timeout cannot tell a dead desktop from an idle one:
        the desktop feed is damage-driven, so an untouched screen is silent
        for as long as nobody touches it. Any threshold short enough to catch
        a real death also fires on a quiet screen, and a false pause excises
        real content. The registry says `removed` exactly once, the instant
        the node goes.

        `pw-mon` rather than libpipewire because this rig has no binding for
        it; the real program watches the registry directly. The signal and its
        latency are the same either way.
        """
        self.watch_proc = subprocess.Popen(
            ["pw-mon", "-N", "-o", "-a"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )

        def pump():
            pending = False
            for line in self.watch_proc.stdout:
                line = line.strip()
                if line == "removed:":
                    pending = True
                    continue
                if pending:
                    pending = False
                    if line.startswith("id:"):
                        try:
                            gone = int(line.split(":", 1)[1].strip())
                        except ValueError:
                            continue
                        for feed, node in list(self.watched.items()):
                            if node == gone:
                                GLib.idle_add(
                                    self.mark_dead, feed,
                                    f"pipewire registry removed node {gone}",
                                )

        threading.Thread(target=pump, daemon=True).start()
        log("registry watch: pw-mon running")

    # ---- recovery -------------------------------------------------------

    def make_screen_bin(self, cast):
        """The desktop branch as one replaceable unit: source *and* GL head.

        Swapping only the `pipewiresrc` does not work. A fresh portal stream
        arrives with its own DMABuf modifiers, and the `glupload` left behind
        from the dead stream cannot renegotiate to them - it fails to fixate
        and the branch dies with `not-negotiated (-4)`. Replacing the whole
        head means the new stream negotiates from scratch, and the mixer's
        request pad - which carries the layout geometry - is never released.
        """
        self.screen_gen += 1
        bin_ = Gst.parse_bin_from_description(
            "pipewiresrc name=screen do-timestamp=true "
            "! queue max-size-buffers=4 leaky=downstream "
            "! glupload ! glcolorconvert",
            True,
        )
        bin_.set_name(f"screenbin{self.screen_gen}")
        src = bin_.get_by_name("screen")
        src.set_property("fd", cast.fd)
        src.set_property("path", str(cast.node))
        self.watched["screen"] = cast.node
        return bin_

    def _swap_bin(self, make, label):
        """Same swap as _swap_src, but for a whole branch head."""
        t0 = now()
        old = self.screen_bin
        ghost = old.get_static_pad("src")
        peer = ghost.get_peer()
        ghost.unlink(peer)
        t_unlink = now()
        old.set_state(Gst.State.NULL)
        ret, _c, _p = old.get_state(3 * Gst.SECOND)
        t_null = now()
        self.pipeline.remove(old)
        fresh = make()
        self.screen_bin = fresh
        self.pipeline.add(fresh)
        link = fresh.get_static_pad("src").link(peer)
        fresh.sync_state_with_parent()
        t_end = now()
        took = {
            "unlink_ms": round((t_unlink - t0) * 1000, 1),
            "to_null_ms": round((t_null - t_unlink) * 1000, 1),
            "null_ret": ret.value_nick,
            "total_ms": round((t_end - t0) * 1000, 1),
            "link": link.value_nick,
        }
        self.revive_floor[label] = now()
        log(f"{label}: swapped branch in {took['total_ms']}ms "
            f"(NULL {took['to_null_ms']}ms/{ret.value_nick}, link {link.value_nick})")
        self.events.append({"kind": "swap", "feed": label, "t": now() - T0, **took})
        return took

    def _swap_src(self, name, configure, label):
        """Tear the named pipewiresrc out of the running pipeline, put a fresh
        one in its place, and leave everything downstream alone.

        The queue, valve, encoder and muxer pad below the source are never
        touched, so the file keeps its track and the muxer keeps its pad - the
        whole point of recovering rather than restarting.
        """
        t0 = now()
        old = self.pipeline.get_by_name(name)
        if old is None:
            log(f"{label}: no element named {name}")
            return None
        srcpad = old.get_static_pad("src")
        peer = srcpad.get_peer()
        if peer is None:
            log(f"{label}: {name} src pad has no peer")
            return None
        srcpad.unlink(peer)
        t_unlink = now()
        old.set_state(Gst.State.NULL)
        ret, _cur, _pend = old.get_state(3 * Gst.SECOND)
        t_null = now()
        self.pipeline.remove(old)
        t_remove = now()

        fresh = Gst.ElementFactory.make("pipewiresrc", name)
        fresh.set_property("do-timestamp", True)
        cfg = configure(fresh)
        t_cfg = now()
        self.pipeline.add(fresh)
        if self.args.drop_restart_events:
            fresh.get_static_pad("src").add_probe(
                Gst.PadProbeType.EVENT_DOWNSTREAM, self._eat_restart
            )
        link = fresh.get_static_pad("src").link(peer)
        fresh.sync_state_with_parent()
        t_end = now()

        took = {
            "unlink_ms": round((t_unlink - t0) * 1000, 1),
            "to_null_ms": round((t_null - t_unlink) * 1000, 1),
            "null_ret": ret.value_nick,
            "remove_ms": round((t_remove - t_null) * 1000, 1),
            "configure_ms": round((t_cfg - t_remove) * 1000, 1),
            "relink_ms": round((t_end - t_cfg) * 1000, 1),
            "total_ms": round((t_end - t0) * 1000, 1),
            "link": link.value_nick,
        }
        self.revive_floor[label] = now()
        log(f"{label}: swapped source in {took['total_ms']}ms "
            f"(NULL {took['to_null_ms']}ms/{ret.value_nick}, "
            f"configure {took['configure_ms']}ms, link {link.value_nick}) {cfg}")
        self.events.append(
            {"kind": "swap", "feed": label, "t": now() - T0, **took, **(cfg or {})}
        )
        return took

    def _eat_restart(self, _pad, info):
        """Drop the new source's stream-start and segment.

        Downstream already has both from the source that died; a second pair
        can reset the running time the whole excision arithmetic depends on.
        Behind --drop-restart-events because whether it is needed at all is
        one of the things this rig is here to find out.
        """
        ev = info.get_event()
        if ev.type in (Gst.EventType.STREAM_START, Gst.EventType.SEGMENT):
            log(f"  dropped {ev.type.value_nick} from the replacement source")
            return Gst.PadProbeReturn.DROP
        return Gst.PadProbeReturn.OK

    def recover_mic(self):
        """Re-resolve the mic's serial and give the audio branch a new source."""
        self.rebuilds["mic"] += 1

        def configure(el):
            node = resolve_mic(self.args.mic_match) if self.args.mic_match else None
            if node:
                was = self.mic_node["serial"] if self.mic_node else None
                self.mic_node = node
                self.watched["mic"] = node["id"]
                el.set_property("target-object", str(node["serial"]))
                return {"serial": node["serial"], "old_serial": was,
                        "node_id": node["id"]}
            if self.args.mic:
                el.set_property("target-object", self.args.mic)
                return {"serial": self.args.mic}
            return {"serial": "default"}

        return self._swap_src("mic", configure, "mic")

    def recover_screen(self):
        """A fresh portal handshake, then a new source on the new fd and node.

        The old session object is deliberately *not* closed: #126 took Hyprland
        down with SIGSEGV by churning sessions, so how many handshakes a run
        survives is itself a measurement. --max-recast caps it.
        """
        if self.recasts >= self.args.max_recast:
            log(f"screen: refusing to re-handshake, already did "
                f"{self.recasts} (--max-recast)")
            return None
        self.recasts += 1
        t0 = now()
        try:
            fresh_cast = Screencast(
                token_cache=pathlib.Path(self.args.token_cache),
                use_token=not self.args.no_token,
            )
        except Exception as exc:  # noqa: BLE001
            log(f"screen: re-handshake FAILED: {exc}")
            self.events.append({"kind": "recast", "ok": False, "why": str(exc),
                                "t": now() - T0})
            return None
        handshake = now() - t0
        old_node = self.cast.node if self.cast else None
        self.old_casts.append(self.cast)
        self.cast = fresh_cast
        self.cast.on_closed = lambda: GLib.idle_add(
            self.mark_dead, "screen", "portal Session.Closed"
        )
        log(f"screen: re-handshake ok in {handshake * 1000:.0f}ms "
            f"node {old_node} -> {fresh_cast.node}")
        self.rebuilds["screen"] += 1

        self.events.append(
            {"kind": "recast", "ok": True, "t": now() - T0,
             "handshake_ms": round(handshake * 1000, 1),
             "node": fresh_cast.node, "old_node": old_node,
             "had_token": fresh_cast.had_token}
        )
        took = self._swap_bin(lambda: self.make_screen_bin(fresh_cast), "screen")
        if self.args.close_old_session and self.old_casts:
            stale = self.old_casts.pop()
            if stale is not None:
                stale.on_closed = None
                t0 = now()
                err = stale.close()
                log(f"screen: closed the old portal session in "
                    f"{(now() - t0) * 1000:.0f}ms -> {err or 'ok'}")
        return took

    def recover_desk(self):
        """Give the desktop-audio branch a fresh source.

        When the branch follows the default sink there is usually nothing to
        recover - PipeWire moves a default-sink capture on its own - so this
        exists for the pinned-sink case, and to measure what the unpinned one
        does without it.
        """
        self.rebuilds["deskaudio"] += 1

        def configure(el):
            el.set_property(
                "stream-properties",
                Gst.Structure.new_from_string("props,stream.capture.sink=true"),
            )
            if self.args.desk_match:
                sink = resolve_sink(self.args.desk_match)
                if sink:
                    was = self.desk_node["serial"] if self.desk_node else None
                    self.desk_node = sink
                    self.watched["deskaudio"] = sink["id"]
                    el.set_property("target-object", str(sink["serial"]))
                    return {"serial": sink["serial"], "old_serial": was,
                            "node_id": sink["id"]}
                return {"serial": "missing"}
            return {"serial": "default-sink"}

        return self._swap_src("desk", configure, "deskaudio")

    def try_recover(self, feed):
        """One recovery attempt, counted against --max-retries like the real
        program's three tries at `camera-connect` (#131).

        The mic is the exception: there is nothing to retry. Nobody can restart
        a USB microphone from software, so a missing node is not a failed
        attempt - it is a wait. The attempt only happens, and only counts, once
        a matching node is actually in the registry again.
        """
        if feed == "deskaudio" and self.args.desk_match:
            if resolve_sink(self.args.desk_match) is None:
                if not self.waiting.get(feed):
                    self.waiting[feed] = True
                    log(f"WAIT  deskaudio: no sink matching "
                        f"{self.args.desk_match!r} yet - nothing to retry")
                return
            self.waiting.pop(feed, None)
        if feed == "mic" and self.args.mic_match:
            if resolve_mic(self.args.mic_match) is None:
                if not self.waiting.get(feed):
                    self.waiting[feed] = True
                    log(f"WAIT  mic: no node matching "
                        f"{self.args.mic_match!r} yet - nothing to retry")
                return
            self.waiting.pop(feed, None)
        if self.retries[feed] >= self.args.max_retries:
            if not self.gave_up.get(feed):
                self.gave_up[feed] = True
                log(f"GIVEUP {feed}: {self.retries[feed]} attempts spent, "
                    "alert stays up and we wait (no give-up timer)")
            return
        self.retries[feed] += 1
        log(f"RECOVER {feed}: attempt {self.retries[feed]}")
        if feed == "mic":
            self.recover_mic()
        elif feed == "screen":
            self.recover_screen()
        elif feed == "deskaudio":
            self.recover_desk()
        elif feed == "camera":
            self.fire("startcam")

    # ---- scripted events ------------------------------------------------

    def schedule(self):
        for item in filter(None, self.args.script.split(",")):
            at, _, action = item.partition(":")
            GLib.timeout_add(int(float(at) * 1000), self.fire, action)
        if self.args.kill_after:
            GLib.timeout_add(
                int(self.args.kill_after * 1000), self.suicide
            )
        elif self.args.duration:
            GLib.timeout_add(int(self.args.duration * 1000), self.fire, "stop")
        GLib.timeout_add(50, self.watchdog)
        GLib.timeout_add(1000, self.heartbeat)

    def heartbeat(self):
        if self.stopping:
            return False
        if not self.clock_logged:
            clk = self.pipeline.get_clock()
            if clk:
                self.clock_logged = True
                log(f"pipeline clock: {clk.get_name()} ({type(clk).__name__})")
        rates = " ".join(f"{f}={self.counts[f]}" for f in FEEDS)
        log(
            f"rt={self.rt() / Gst.SECOND:6.2f}s mux_pts="
            f"{self.last_mux_pts / Gst.SECOND:6.2f}s frames={self.mux_buffers} "
            f"{rates} paused={self.paused}"
        )
        return True

    def fire(self, action):
        log(f"EVENT {action}")
        self.events.append({"kind": "event", "what": action, "t": now() - T0})
        if action == "stop":
            self.stop()
        elif action == "pause":
            self.manual_pause = True
            self.do_pause()
        elif action == "resume":
            self.manual_pause = False
            self.dead.clear()
            self.do_resume()
        elif action == "killcam":
            run("pkill -INT -f 'gphoto2 --stdout'")
        elif action == "startcam":
            log(f"  $ {self.args.startcam_cmd}")
            subprocess.Popen(
                shlex.split(self.args.startcam_cmd),
                stdout=subprocess.DEVNULL,
                stderr=open(self.args.startcam_log, "ab") if self.args.startcam_log
                else subprocess.DEVNULL,
                start_new_session=True,
            )
        elif action == "killnode":
            node = self.cast.node if self.cast else None
            run(f"pw-cli destroy {node}")
        elif action == "killstream":
            err = self.cast.kill_stream() if self.cast else "no session"
            log(f"killstream -> {err or 'stream destroyed'}")
        elif action == "killportal":
            run("systemctl --user restart xdg-desktop-portal-hyprland.service")
        elif action == "killmic":
            run(f"pactl unload-module module-null-sink 2>/dev/null || true")
        elif action == "startmic":
            run(
                f"pactl load-module module-null-sink sink_name={NULL_SINK} "
                f"sink_properties=device.description={NULL_SINK}"
            )
        elif action == "killdesk":
            run(f"pactl unload-module module-null-sink 2>/dev/null || true")
        elif action == "startdesk":
            run(
                f"pactl load-module module-null-sink sink_name={DESK_SINK} "
                f"sink_properties=device.description={DESK_SINK}"
            )
        elif action == "deskrecover":
            self.recover_desk()
        elif action == "micrecover":
            self.recover_mic()
        elif action == "screenrecover":
            self.recover_screen()
        elif action == "pwlist":
            for n in pw_nodes():
                if (n["class"] or "").startswith(("Audio/", "Stream/")) or \
                        "creen" in (n["desc"] or ""):
                    log(f"  node {n['id']} serial={n['serial']} "
                        f"class={n['class']} name={n['name']}")
        elif action == "recast":
            try:
                t0 = now()
                second = Screencast()
                log(f"RECAST ok in {now() - t0:.3f}s: fd={second.fd} "
                    f"node={second.node} (old node={self.cast.node if self.cast else None})")
                self.events.append({"kind": "recast", "ok": True,
                                    "took": now() - t0, "node": second.node,
                                    "t": now() - T0})
            except Exception as exc:  # noqa: BLE001
                log(f"RECAST failed: {exc}")
                self.events.append({"kind": "recast", "ok": False,
                                    "why": str(exc), "t": now() - T0})
        elif action == "castalive":
            log(f"portal session alive={self.cast.alive() if self.cast else 'n/a'}")
        elif action.startswith("sh="):
            run(action[3:])
        else:
            log(f"unknown action {action!r}")
        return False

    def suicide(self):
        log("SIGKILL self (crash simulation)")
        os.kill(os.getpid(), signal.SIGKILL)
        return False

    # ---- lifecycle ------------------------------------------------------

    def stop(self):
        if self.stopping:
            return False
        self.stopping = True
        log("EOS + finalise")
        if self.paused:
            self.manual_pause = False
            self.dead.clear()
            self.do_resume()
        self.pipeline.send_event(Gst.Event.new_eos())
        GLib.timeout_add(8000, self.bail)
        return False

    def bail(self):
        """A dead feed can wedge both EOS and the NULL state change.

        Observed with the desktop feed gone: the pipeline clock stops, EOS
        never reaches the sink and set_state(NULL) never returns. Report what
        we measured and leave hard rather than hang.
        """
        log("finalise timed out - reporting and exiting hard")
        self.report()
        sys.stdout.flush()
        os._exit(0)

    def on_eos(self, *_a):
        log("bus EOS")
        self.pipeline.set_state(Gst.State.NULL)
        self.loop.quit()

    def on_error(self, _bus, msg):
        err, dbg = msg.parse_error()
        src = msg.src.get_name() if msg.src else "?"
        log(f"ERROR from {src}: {err.message}")
        self.events.append(
            {"kind": "error", "src": src, "msg": err.message, "t": now() - T0}
        )
        feed = {"screen": "screen", "cam": "camera", "mic": "mic",
                "desk": "deskaudio"}.get(src)
        if feed:
            # A recovery can fail, and failing is not fatal. The commonest is
            # `target not found`: the node is in the registry a moment before
            # it can be connected to, so the swap races the session manager.
            # Keep the feed dead and let the retry loop have another go.
            if feed in self.dead:
                log(f"  recovery attempt {self.retries[feed]} for {feed} "
                    f"failed, will retry")
                self.attempted_at[feed] = now()
                self.events.append({"kind": "attempt-failed", "feed": feed,
                                    "msg": err.message, "t": now() - T0})
            else:
                self.mark_dead(feed, f"ERROR {err.message}")
            return
        print(dbg, file=sys.stderr, flush=True)
        self.stop()

    def on_warning(self, _bus, msg):
        err, _ = msg.parse_warning()
        src = msg.src.get_name() if msg.src else "?"
        log(f"WARN from {src}: {err.message}")

    def run(self):
        self.build()
        if self.args.registry_watch:
            self.start_registry_watch()
        self.schedule()
        self.pipeline.set_state(Gst.State.PLAYING)
        try:
            self.loop.run()
        except KeyboardInterrupt:
            pass
        self.pipeline.set_state(Gst.State.NULL)
        self.report()

    def report(self):
        out = {
            "record": self.args.record,
            "muxer": self.args.muxer,
            "frag_ms": self.args.frag,
            "offset_mode": self.args.offset_mode,
            "counts": self.counts,
            "max_gap_s": {k: round(v, 3) for k, v in self.max_gap.items()},
            "total_excised_ns": self.total_offset,
            "mux_buffers": self.mux_buffers,
            "rebuilds": self.rebuilds,
            "recasts": self.recasts,
            "mic_node": self.mic_node,
            "desk_node": self.desk_node,
            "delays_ms": {k: v / 1000000 for k, v in self.delays.items()},
            "screen_delay_ms": self.args.screen_delay,
            "delay_mode": self.args.delay_mode,
            "levels": self.levels,
            "level_counts": self.level_counts,
            "level_max_db": {k: round(v, 1) for k, v in self.level_max.items()},
            "last_mux_pts_ns": self.last_mux_pts,
            "events": self.events,
        }
        log("REPORT " + json.dumps(out))
        if self.args.report:
            pathlib.Path(self.args.report).write_text(json.dumps(out, indent=2))


def run(cmd: str):
    log(f"  $ {cmd}")
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.stdout.strip():
        log(f"    out: {r.stdout.strip()[:200]}")
    if r.returncode:
        log(f"    rc={r.returncode} err: {r.stderr.strip()[:200]}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--record", default="/tmp/proto130.mp4")
    p.add_argument("--muxer", choices=("hybrid", "dash", "isofmp4"), default="hybrid")
    p.add_argument("--frag", type=int, default=1000, help="fragment duration in ms")
    p.add_argument("--bitrate", type=int, default=50000)
    p.add_argument("--duration", type=float, default=0)
    p.add_argument("--kill-after", type=float, default=0)
    p.add_argument("--script", default="")
    p.add_argument("--camera", default="/dev/video9")
    p.add_argument("--startcam-cmd", default="camera-connect",
                   help="what `startcam` runs to bring the camera producer back")
    p.add_argument("--startcam-log", default="",
                   help="append that command's stderr here instead of discarding it")
    p.add_argument("--mic", default="",
                   help="raw target-object value (a name, which #130 found is "
                        "silently ignored - prefer --mic-match)")
    p.add_argument("--mic-match", default="",
                   help="substring of node.name; resolved to the node's SERIAL "
                        "at build time and again on every recovery")
    p.add_argument("--auto-recover", action="store_true",
                   help="the watchdog recovers a dead feed itself")
    p.add_argument("--max-retries", type=int, default=3,
                   help="recovery attempts per death before giving up and waiting")
    p.add_argument("--retry-interval", type=float, default=1000,
                   help="ms between recovery attempts")
    p.add_argument("--max-recast", type=int, default=3,
                   help="cap on portal re-handshakes per run (#126 crashed "
                        "Hyprland on the eighth fresh session)")
    p.add_argument("--close-old-session", action="store_true",
                   help="Close the superseded portal session after a swap "
                        "instead of holding it for the run's life")
    p.add_argument("--registry-watch", action="store_true",
                   help="detect death from the PipeWire registry instead of "
                        "waiting for frames to stop arriving")
    p.add_argument("--drop-restart-events", action="store_true",
                   help="eat the replacement source's stream-start and segment")
    p.add_argument("--token-cache",
                   default=str(pathlib.Path.home() / ".cache"
                               / "proto133-restore-token"))
    p.add_argument("--no-token", action="store_true",
                   help="ignore the cached restore token - forces the picker")
    p.add_argument("--desk-audio", action="store_true",
                   help="capture desktop audio from a sink monitor and mix it "
                        "with the mic")
    p.add_argument("--desk-match", default="",
                   help="substring of a SINK's node.name to pin the desktop "
                        "audio to; empty means follow the default sink")
    p.add_argument("--mic-delay", type=int, default=0,
                   help="ms to push the mic forward so the voice lands on the "
                        "face (#127 measured the camera ~165ms behind)")
    p.add_argument("--desk-delay", type=int, default=0,
                   help="ms to push desktop audio forward to match the screen")
    p.add_argument("--screen-delay", type=int, default=0,
                   help="ms to hold the desktop video back so the screen lands "
                        "on the face as well - costs GL frames in the mixer")
    p.add_argument("--delay-mode", choices=("probe", "padoffset"),
                   default="probe",
                   help="probe rewrites PTS before the valve, so the raw "
                        "tracks move too; padoffset moves the mix only")
    p.add_argument("--raw-tracks", action="store_true",
                   help="write raw mic and raw desktop as extra tracks in the "
                        "same file")
    p.add_argument("--raw-files", action="store_true",
                   help="write the raw streams to separate wav files instead")
    p.add_argument("--meter-log", action="store_true",
                   help="print every level message, not just the summary")
    p.add_argument("--meter", type=int, default=100,
                   help="ms between level messages; 0 turns the meter off")
    p.add_argument("--desk-timeout", type=float, default=500,
                   help="ms of no desktop-audio buffers before it counts as "
                        "dead. Unlike the screen, a sink monitor emits digital "
                        "silence when nothing plays, so a timeout is honest here")
    p.add_argument("--audio-queue", type=int, default=200,
                   help="ms of audio buffered in front of the valve; whatever "
                        "is in it when the valve closes is dropped, and that "
                        "is the hole the seam leaves in the audio track")
    p.add_argument("--fake-screen", action="store_true")
    p.add_argument("--screen-pattern", default="smpte",
                   help="videotestsrc pattern for --fake-screen; snow saturates CBR")
    p.add_argument("--iso-finalise", action="store_true",
                   help="isofmp4mux: rewrite the header and write mehd at EOS")
    p.add_argument("--system-clock", action="store_true",
                   help="pin GstSystemClock so a dead feed cannot stop time")
    p.add_argument("--fake-camera", action="store_true")
    p.add_argument("--no-camera", action="store_true")
    p.add_argument("--no-audio", action="store_true")
    p.add_argument("--cam-timeout", type=float, default=200)
    p.add_argument("--mic-timeout", type=float, default=200)
    p.add_argument("--screen-timeout", type=float, default=2000)
    p.add_argument("--resume-stable", type=float, default=300)
    p.add_argument(
        "--offset-mode",
        choices=("valve-sink", "valve-src", "mux-sink", "rewrite", "none"),
        default="valve-src",
    )
    p.add_argument("--error-is-death", action="store_true")
    p.add_argument("--tee", action="store_true",
                   help="hang a second branch off the composite, as the real preview will")
    p.add_argument("--progress", default="")
    p.add_argument("--report", default="")
    args = p.parse_args()

    Gst.init(None)
    Rig(args).run()


if __name__ == "__main__":
    main()
