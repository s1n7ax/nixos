#!/usr/bin/env python3
"""Throwaway rig for wayfinder issue #130.

Two questions, one pipeline, because both need the real 1440p60 composite:

1. Does the dead-feed pause path work? A feed dies without erroring, a watchdog
   notices, a `valve` in front of the encoder drops the frozen frames, and the
   dead interval is excised from the file's running time. Proven per feed:
   desktop (portal screencast), camera (/dev/video9), mic (PipeWire).

2. Does a shorter `fragment-duration` close the loss window that #124 measured
   at 1 s fragments (hybrid ~2 s lost, isofmp4mux ~1 s)?

Nothing here ships. The verdict lives in the ticket.
"""

import argparse
import json
import os
import pathlib
import signal
import subprocess
import sys
import time

import gi

gi.require_version("Gst", "1.0")

from gi.repository import Gio, GLib, Gst  # noqa: E402

CANVAS_W = 2560
CANVAS_H = 1440
CAM_W = 1024
CAM_H = 576
TOKEN_CACHE = pathlib.Path.home() / ".cache" / "proto130-restore-token"
NULL_SINK = "proto130mic"

FEEDS = ("screen", "camera", "mic")

TOKEN_SEQ = [0]


def now() -> float:
    return time.monotonic()


def log(msg: str) -> None:
    print(f"[{now() - T0:7.3f}] {msg}", flush=True)


T0 = now()


# --------------------------------------------------------------------------
# portal


class Screencast:
    """One ScreenCast session, held for the whole run.

    #126 crashed Hyprland 0.55.4 by opening a fresh session per variant, so
    this object is created exactly once and never re-handshakes. It also
    subscribes to org.freedesktop.portal.Session.Closed, which is the only
    authoritative "your desktop feed is gone" signal available.
    """

    def __init__(self, cursor: bool = True):
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
        log("portal: proxy ready, starting handshake")
        self._handshake(cursor)
        log("portal: handshake done")

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
            log("portal: Start returned")
            if "restore_token" in results:
                TOKEN_CACHE.parent.mkdir(parents=True, exist_ok=True)
                TOKEN_CACHE.write_text(results["restore_token"])
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
                if TOKEN_CACHE.exists():
                    opts["restore_token"] = GLib.Variant(
                        "s", TOKEN_CACHE.read_text().strip()
                    )
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
            self.cast = Screencast()
            log(f"portal: fd={self.cast.fd} node={self.cast.node}")
            screen = (
                "pipewiresrc name=screen do-timestamp=true "
                "! queue max-size-buffers=4 leaky=downstream "
                "! glupload ! glcolorconvert"
            )
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

        audio = ""
        if not a.no_audio:
            target = f"target-object={a.mic} " if a.mic else ""
            audio = (
                f" pipewiresrc name=mic {target}do-timestamp=true "
                "! audio/x-raw,channels=2 "
                "! queue max-size-time=200000000 "
                "! valve name=avalve ! audioconvert ! audioresample "
                "! avenc_aac bitrate=192000 ! aacparse ! queue "
                f"! mux.{'sink_1' if a.muxer == 'isofmp4' else 'audio_0'}"
            )
            self.enabled.add("mic")

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
            f"{screen} ! mix.sink_0 "
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
        self.vvalve = self.pipeline.get_by_name("vvalve")
        self.avalve = self.pipeline.get_by_name("avalve")
        self.mux = self.pipeline.get_by_name("mux")

        self.vpad = self.vvalve.get_static_pad("sink")
        self.apad = self.avalve.get_static_pad("sink") if self.avalve else None
        self.vsrc = self.vvalve.get_static_pad("src")
        self.asrc = self.avalve.get_static_pad("src") if self.avalve else None

        if self.cast:
            src = self.pipeline.get_by_name("screen")
            src.set_property("fd", self.cast.fd)
            src.set_property("path", str(self.cast.node))
            self.cast.on_closed = lambda: GLib.idle_add(
                self.mark_dead, "screen", "portal Session.Closed"
            )

        # geometry: desktop centre-cropped, camera as the 440px corner circle
        # box (no shader here - #126 settled the look, this rig measures time)
        pad0 = self.mix.get_static_pad("sink_0")
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
        if self.apad:
            self.apad.add_probe(Gst.PadProbeType.BUFFER, self.saw, "mic")
            if self.args.audio_delay:
                self.apad.set_offset(self.args.audio_delay * 1000000)

        self.vvalve.set_property("drop", True)
        if self.avalve:
            self.avalve.set_property("drop", True)
        self.vmux, self.amux = self.mux_pads()
        self.vsrc.add_probe(Gst.PadProbeType.BUFFER, self.on_video_out)
        if self.asrc:
            self.asrc.add_probe(Gst.PadProbeType.BUFFER, self.on_audio_out)
        self.vmux.add_probe(Gst.PadProbeType.BUFFER, self.on_mux)

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
        """Same surgery on the audio branch, plus the camera's ~165ms lag."""
        if self.args.offset_mode != "rewrite":
            return Gst.PadProbeReturn.OK
        shift = self.total_offset - self.args.audio_delay * 1000000
        if not shift:
            return Gst.PadProbeReturn.OK
        buf = info.get_buffer()
        if buf.pts != Gst.CLOCK_TIME_NONE and buf.pts >= shift:
            buf.pts -= shift
        if buf.dts != Gst.CLOCK_TIME_NONE and buf.dts >= shift:
            buf.dts -= shift
        return Gst.PadProbeReturn.OK

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
        log(f"DEAD  {feed}: {why}")
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
        if self.avalve:
            self.avalve.set_property("drop", True)
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
        mode = self.args.offset_mode
        delay = self.args.audio_delay * 1000000
        if mode in ("valve-sink", "valve-src", "mux-sink"):
            vp, ap = {
                "valve-sink": (self.vpad, self.apad),
                "valve-src": (self.vsrc, self.asrc),
                "mux-sink": (self.vmux, self.amux),
            }[mode]
            vp.set_offset(-self.total_offset)
            if ap:
                ap.set_offset(delay - self.total_offset)
        self.vvalve.set_property("drop", False)
        if self.avalve:
            self.avalve.set_property("drop", False)
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
                self.dead.discard(feed)
                log(f"BACK  {feed}: data flowing again")
                self.events.append(
                    {"kind": "back", "feed": feed, "t": now() - T0}
                )
                self.stable_since = t
        if self.paused and not self.dead and not self.manual_pause:
            if self.stable_since is None:
                self.stable_since = t
            if (t - self.stable_since) * 1000 >= self.args.resume_stable:
                self.do_resume()
        return True

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
            subprocess.Popen(
                ["camera-connect"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
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
        if self.args.error_is_death and src in ("screen", "cam", "mic"):
            feed = {"screen": "screen", "cam": "camera", "mic": "mic"}[src]
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
    p.add_argument("--mic", default="")
    p.add_argument("--audio-delay", type=int, default=0, help="ms")
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
