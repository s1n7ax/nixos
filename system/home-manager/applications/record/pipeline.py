"""Every command line the session runs, built from the constants in `config`.

One ffmpeg spans the whole session — preflight and take alike — because the preview
fifo cannot survive a handover: the reader locks to the first stream's parameters, and
a second writer's timestamps restart at zero and are rejected wholesale. So there is no
handover. The file rolls from the first preview frame and Enter is a marker, not a
switch; the preflight head is trimmed in LosslessCut along with everything else.
"""

from __future__ import annotations

import audio
import config

PREVIEW_TITLE = "rec-preview"
"""What the Hyprland dispatcher matches on to park the window under the circle."""


def wf_recorder_argv() -> list[str]:
    """Raw frames off the one monitor, onto stdout.

    The only viable route on this machine: `wl-screenrec` needs VAAPI encode that
    NVIDIA lacks, ffmpeg has no PipeWire input at all, and `kmsgrab` needs the DRM
    master that Hyprland holds. `-r` is what makes the output constant-rate, which
    rawvideo over a pipe otherwise has no way to express.
    """
    return [
        "wf-recorder",
        "-o", config.MONITOR,
        "-c", "rawvideo",
        "-m", "rawvideo",
        "-x", "yuv420p",
        "-r", str(config.OUTPUT_FPS),
        "-D",
        "--file=pipe:1",
    ]


def gphoto2_argv(frames: int | None = None) -> list[str]:
    """PTP live view onto stdout. With `frames`, a burst that stops itself."""
    capture = "--capture-movie" if frames is None else f"--capture-movie={frames}"
    return ["gphoto2", "--stdout", "--set-config", "viewfinder=1", capture]


def filter_graph() -> str:
    """The composite, the preview branch, and the three audio tracks.

    The mask is a static PNG through `alphamerge`, never `geq`, which benchmarked 8.3x
    more expensive; it depends only on diameter and feather, both constants, so it is
    generated once at build time. The three `format=` filters are load-bearing:
    `yuva420p` on the overlay before the upload, `yuv420p` on the main input before it,
    and no `-pix_fmt` on the encoder — drop any one and the circle becomes a square or
    the graph refuses to configure.
    """
    crop_width, crop_height, crop_x, crop_y = config.camera_crop()
    inner = config.ring_inner_size()
    circle_x, circle_y = config.circle_position()
    hud_width, _ = config.hud_size()
    return ";".join(
        [
            f"[1:v]crop={crop_width}:{crop_height}:{crop_x}:{crop_y}"
            f",scale={inner}:{inner}"
            f",pad={config.CIRCLE_DIAMETER}:{config.CIRCLE_DIAMETER}"
            f":{config.RING_WIDTH}:{config.RING_WIDTH}:{config.RING_COLOUR}"
            ",format=rgba[c]",
            "[2:v]format=gray[m]",
            "[c][m]alphamerge,format=yuva420p,hwupload_cuda[kg]",
            "[0:v]format=yuv420p,hwupload_cuda[sg]",
            f"[sg][kg]overlay_cuda=x={circle_x}:y={circle_y}:eof_action=pass,split=2[venc][p]",
            f"[p]hwdownload,format=yuv420p,scale={hud_width}:-2[pv]",
            "[3:a]asplit=2[micraw][micmix]",
            "[micraw]pan=mono|c0=0.5*c0+0.5*c1[mic]",
            "[4:a]asplit=2[desk][deskmix]",
            f"[micmix][deskmix]amix=inputs=2:normalize=0:weights={config.MIX_WEIGHTS}[mix]",
        ]
    )


def _pulse_input(source: str, stream_name: str) -> list[str]:
    return [
        "-f", "pulse",
        "-thread_queue_size", str(config.THREAD_QUEUE_SIZE),
        "-stream_name", stream_name,
        "-i", source,
    ]


def ffmpeg_argv(
    *,
    screen_fd: int,
    camera_fd: int,
    mask: str,
    mic: str,
    desktop: str,
    output: str,
    preview: str,
) -> list[str]:
    """The one process. Two inherited pipes, a mask, two pulse sources, two outputs.

    No output carries `-t`: SIGINT finalises every output of a multi-output ffmpeg, but
    a stop condition on only one of them leaves the process serving the other for
    minutes after the take is over.

    The camera input is given no geometry and no rate. `-video_size` is a hard error
    on the mjpeg demuxer, which exposes only `-framerate` and `-raw_packet_size`, so
    the warm-up burst is the pipeline's whole defence against the stale-geometry
    frames the demuxer would otherwise lock the entire take to. A declared rate is
    wrong anyway: 25 against the real 25.04 drifts the circle ~3.8 s behind the audio
    over a 40-minute take, which is why both pipes run on the wall clock instead.
    """
    return [
        "ffmpeg",
        "-hide_banner", "-nostdin", "-y",
        "-init_hw_device", "cuda=cu:0", "-filter_hw_device", "cu",
        "-thread_queue_size", str(config.THREAD_QUEUE_SIZE),
        "-f", "rawvideo",
        "-pixel_format", "yuv420p",
        "-video_size", f"{config.SCREEN_WIDTH}x{config.SCREEN_HEIGHT}",
        "-use_wallclock_as_timestamps", "1",
        "-i", f"pipe:{screen_fd}",
        "-thread_queue_size", str(config.THREAD_QUEUE_SIZE),
        "-f", "mjpeg",
        "-use_wallclock_as_timestamps", "1",
        "-i", f"pipe:{camera_fd}",
        "-i", mask,
        *_pulse_input(mic, audio.MIC_STREAM),
        *_pulse_input(desktop, audio.DESKTOP_STREAM),
        "-filter_complex", filter_graph(),
        "-map", "[venc]",
        "-c:v", "h264_nvenc",
        "-preset", "p4",
        "-tune", "hq",
        "-rc", "vbr",
        "-cq", "23",
        "-b:v", "0",
        "-g", "100",
        "-bf", "3",
        "-spatial-aq", "1",
        "-aq-strength", "8",
        "-rc-lookahead", "20",
        "-fps_mode", "cfr",
        "-r", str(config.OUTPUT_FPS),
        "-map", "[mix]", "-c:a:0", "aac", "-b:a:0", "192k",
        "-map", "[mic]", "-c:a:1", "aac", "-b:a:1", "96k",
        "-map", "[desk]", "-c:a:2", "aac", "-b:a:2", "192k",
        "-metadata:s:a:0", "title=Mix", "-metadata:s:a:0", "handler_name=Mix",
        "-metadata:s:a:1", "title=Mic", "-metadata:s:a:1", "handler_name=Mic",
        "-metadata:s:a:2", "title=Desktop", "-metadata:s:a:2", "handler_name=Desktop",
        output,
        "-map", "[pv]",
        "-c:v", "rawvideo",
        "-f", "fifo",
        "-fifo_format", "nut",
        "-queue_size", "8",
        "-drop_pkts_on_overflow", "1",
        preview,
    ]


def ffplay_argv(preview: str) -> list[str]:
    """The preview window.

    A separate process because ffmpeg's own `-f sdl` output silently never opens a
    window on Wayland — it accepts and burns frames, exits clean, and shows nothing.
    Sized at birth because Hyprland will not shrink a window below its native size.
    """
    width, height = config.hud_size()
    return [
        "ffplay",
        "-hide_banner",
        "-loglevel", "quiet",
        "-nostats",
        "-noborder",
        "-autoexit",
        "-fflags", "nobuffer",
        "-flags", "low_delay",
        "-window_title", PREVIEW_TITLE,
        "-x", str(config.to_logical(width)),
        "-y", str(config.to_logical(height)),
        "-i", preview,
    ]


def placement_dispatches() -> list[str]:
    """Park the preview inside the circle's inscribed square, where the overlay hides it.

    `wf-recorder` grabs the monitor's composited image, so anything visible on the only
    monitor is in the take — except what the circle is painted over the top of. Hyprland
    0.55.4 replaced the old dispatcher syntax with a Lua API, and `relative = false` is
    required or the coordinates are read as deltas.
    """
    width, height = config.hud_size()
    x, y = config.hud_position()
    window = f"'title:{PREVIEW_TITLE}'"
    return [
        f'hl.dsp.window.float("title:{PREVIEW_TITLE}")',
        f"hl.dsp.window.resize{{ x = {config.to_logical(width)}, y = {config.to_logical(height)},"
        f" relative = false, window = {window} }}",
        f"hl.dsp.window.move{{ x = {config.to_logical(x)}, y = {config.to_logical(y)},"
        f" relative = false, window = {window} }}",
        f'hl.dsp.window.pin("title:{PREVIEW_TITLE}")',
    ]


def meter_argv(mic: str) -> list[str]:
    """A second reader of the mic, for the preflight level bar.

    Safe alongside the take: PipeWire allows many readers of one source, measured.
    """
    return [
        "ffmpeg",
        "-hide_banner",
        "-nostdin",
        "-loglevel", "error",
        "-f", "pulse",
        "-stream_name", "record-meter",
        "-i", mic,
        "-af",
        "astats=metadata=1:reset=1:measure_perchannel=none:measure_overall=Peak_level,"
        "ametadata=print:key=lavfi.astats.Overall.Peak_level:file=-",
        "-f", "null", "-",
    ]
