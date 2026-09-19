"""The two audio sources: resolving them, refusing the wrong one, watching the move.

Desktop audio is the monitor of whatever sink is default at preflight, resolved once
here rather than left to ffmpeg's `@DEFAULT_MONITOR@`, so the name can be shown and
tested before the take rolls. The mic is pinned by name, because a headset taking a
call otherwise becomes the default source mid-session.

Neither pin holds once the take has started: PipeWire *moves* an orphaned capture to
another source rather than ending it, with no error, no EOF and a full-length file.
`node.dont-reconnect`, `stream.dont-move` and `PULSE_PROP` were all measured failing to
forbid it. So the move is watched for and shouted about, never prevented.
"""

from __future__ import annotations

import json
import re

import config

_DEFAULT_SINK = re.compile(r"key:'default\.audio\.sink'\s+value:'(?P<value>.*?)'\s+type:")

STREAM_CLASS = "Stream/Input/Audio"
"""What a `-f pulse` input of ours looks like in `pw-dump`."""

MIC_STREAM = "record-mic"
DESKTOP_STREAM = "record-desktop"
"""`-stream_name` on each pulse input, so the watcher can tell the two apart."""

LABELS = {MIC_STREAM: "mic", DESKTOP_STREAM: "desktop audio"}
"""What to call each stream when shouting about it, rather than its wire name."""


def parse_default_sink(metadata: str) -> str | None:
    """The default sink's node name out of `pw-metadata -n default`.

    Deliberately reads `default.audio.sink` and not `default.configured.audio.sink`:
    a configured default that no longer exists falls through to raw priority anyway,
    which on this machine lands on the GPU HDMI outputs `is_blocked` exists to catch.
    """
    match = _DEFAULT_SINK.search(metadata)
    if not match:
        return None
    try:
        name = json.loads(match.group("value")).get("name")
    except json.JSONDecodeError:
        return None
    return name or None


def monitor_of(sink: str) -> str:
    """The monitor source that carries what a sink is playing."""
    return sink if sink.endswith(".monitor") else f"{sink}.monitor"


def is_blocked(source: str) -> bool:
    """Whether preflight must refuse this desktop source.

    An exact test, not a heuristic: the four `pro-output-*` monitors on the GPU's HDMI
    audio are the only thing the default can wrongly fall through to here, nothing ever
    plays to them, and three of them are 8-channel s32le — so a silent take and a
    changed track shape arrive together.
    """
    return source.startswith(config.BLOCKED_DESKTOP_PREFIX)


def _nodes(dump: str) -> list[dict]:
    try:
        objects = json.loads(dump)
    except json.JSONDecodeError:
        return []
    return [obj for obj in objects if isinstance(obj, dict)]


def _props(obj: dict) -> dict:
    info = obj.get("info")
    if not isinstance(info, dict):
        return {}
    props = info.get("props")
    return props if isinstance(props, dict) else {}


def source_exists(dump: str, source: str) -> bool:
    """Whether `pw-dump` still carries this node name.

    A monitor is checked by its sink, since `pw-dump` names the sink node and the
    `.monitor` suffix is the pulse layer's view of it.
    """
    wanted = source[: -len(".monitor")] if source.endswith(".monitor") else source
    return any(_props(obj).get("node.name") in (source, wanted) for obj in _nodes(dump))


def capture_sources(dump: str, pid: int) -> dict[str, str | None]:
    """Our own capture streams mapped to the node currently feeding each.

    Keyed by `media.name`, which is whatever `-stream_name` was handed to ffmpeg, so
    the answer survives the move that renumbers everything else.
    """
    objects = _nodes(dump)
    names = {obj.get("id"): _props(obj).get("node.name") for obj in objects}
    feeders: dict[int, int] = {}
    for obj in objects:
        if not str(obj.get("type", "")).endswith("Link"):
            continue
        info = obj.get("info") or {}
        target = info.get("input-node-id")
        origin = info.get("output-node-id")
        if target is not None and origin is not None:
            feeders[target] = origin

    found: dict[str, str | None] = {}
    for obj in objects:
        props = _props(obj)
        if props.get("media.class") != STREAM_CLASS:
            continue
        if props.get("application.process.id") != pid:
            continue
        stream = props.get("media.name")
        if stream is None:
            continue
        found[stream] = names.get(feeders.get(obj.get("id")))
    return found


def moves(before: dict[str, str | None], after: dict[str, str | None]) -> list[tuple[str, str, str]]:
    """Streams whose source changed under them, as `stream, was, now`.

    A stream appearing, or disappearing, is not a move: only a live capture that was
    on one source and is now on another counts, which is exactly the silent failure.
    """
    changed = []
    for stream, was in before.items():
        now = after.get(stream)
        if was and now and was != now:
            changed.append((stream, was, now))
    return changed


def move_warning(elapsed: str, stream: str, was: str, now: str) -> str:
    """The line the watcher shouts. The take keeps rolling; this says which minute went bad."""
    return f"!! {elapsed}  {LABELS.get(stream, stream)} moved: {was} -> {now}"
