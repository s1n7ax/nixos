# Addressing the mic and desktop-audio monitor from ffmpeg

Research for ticket `03-pipewire-source-addressing`. Every claim below is cited to a
primary source: upstream man pages shipped in this machine's Nix store, upstream source
code, or official project documentation.

## How this was verified — and one honest limitation

The recording rig is the **`desktop`** profile. The machine this research ran on is
**`dev-vm`** (`hostname` → `dev-vm`), where PipeWire is **not running**: there is no
`pipewire-0` or `pulse/native` socket under `/run/user/1000`, and `systemctl --user
list-unit-files` lists no pipewire/wireplumber units. `pactl`, `wpctl` and `pw-cli` are
not on `PATH` here either.

**Consequence: no live device names were captured.** `wpctl status` / `pactl list short
sources` could not be run against the real rig. Everything about naming below is derived
from the *code that generates those names* (WirePlumber's naming script and PipeWire's
ALSA udev plugin, both read from the Nix store), which is strictly more authoritative
than a sample listing — but the concrete strings for the desktop's actual hardware still
need one confirming run of `pactl list short sources` on the desktop.

What *was* verified live on this machine:

- `ffmpeg` 6.1.6 is present and its compiled-in device list was read directly.
- The `astats`/`ametadata` level-meter chain was executed and produces output (see
  [Level metering](#5-reading-a-mic-level-without-stealing-the-device)).
- Upstream `pactl(1)` and `wpctl(1)` man pages were read from the store.
- PipeWire 1.6.8 and WirePlumber 0.5.14 binaries/scripts were inspected in the store.

Audio is enabled for the desktop profile — `profile/desktop/options.nix:34` sets
`audio.enable = true`, and `system/nixos/core/pipewire.nix` turns on `services.pipewire`
with `audio.enable`, `pulse.enable` and `wireplumber.enable`. So the PulseAudio
compatibility layer (`libpipewire-module-protocol-pulse.so`) is active on the rig.

---

## 1. Does ffmpeg have a native PipeWire input?

**No. `-f pulse` is the only route.**

This build's device list, read live:

```
$ ffmpeg -hide_banner -devices
 DE alsa            ALSA audio output
 D  jack            JACK Audio Connection Kit
 DE oss             OSS (Open Sound System) playback
 DE pulse           Pulse audio output
 ...
```

`$ ffmpeg -hide_banner -demuxers | grep -iE 'pulse|pipewire|alsa|jack'` returns exactly
four audio inputs — `alsa`, `jack`, `oss`, `pulse` — and **no `pipewire`**. The build
configuration confirms why: it contains `--enable-libpulse`, `--enable-alsa` and
`--enable-libjack`, but no libpipewire flag of any kind.

This is not a packaging gap. FFmpeg's official device documentation lists no PipeWire
input device at all; the audio input devices documented are `alsa`, `jack`, `openal`,
`oss`, `pulse` and `sndio`.
Source: <https://ffmpeg.org/ffmpeg-devices.html>

So the addressing question is entirely a question about **PulseAudio-compat source
names**, which PipeWire serves through `module-protocol-pulse`.

### What the `pulse` demuxer accepts

> "The filename to provide to the input device is a source device or the string
> `default`"
>
> "To list the PulseAudio source devices and their properties you can invoke the command
> `pactl list sources`."

Source: <https://ffmpeg.org/ffmpeg-devices.html>

Options relevant here (read live from `ffmpeg -h demuxer=pulse`, and documented at the
same URL):

| Option | Default | Note |
| --- | --- | --- |
| `-sample_rate` | 48000 | Hz |
| `-channels` | 2 | request N channels; the server remixes |
| `-fragment_size` | -1 | buffering size; affects latency |
| `-wallclock` | 1 | "Set the initial PTS using the current time" |
| `-frame_size` | 1024 | "This option does nothing and is deprecated" |

All of these must appear **before** the `-i` they apply to.

### Critical: ffmpeg passes the name straight through

From `libavdevice/pulse_audio_dec.c`:

```c
if (s->url[0] != '\0' && strcmp(s->url, "default"))
    device = s->url;
```

```c
ret = pa_stream_connect_record(pd->stream, device, &attr,
                                PA_STREAM_INTERPOLATE_TIMING
                                |PA_STREAM_ADJUST_LATENCY
                                |PA_STREAM_AUTO_TIMING_UPDATE);
```

Source: <https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/libavdevice/pulse_audio_dec.c>

Two consequences that drive the whole recommendation:

1. **ffmpeg does no name resolution of its own.** Only the literal string `default` (and
   the empty string) is special-cased, and it becomes `NULL`. Every other string is
   handed verbatim to the server. Whatever the *server* understands, ffmpeg can address.
2. **ffmpeg does not pass `PA_STREAM_DONT_MOVE`.** The stream is therefore movable by the
   session manager — which matters for the mic question in §4.

---

## 2. What the names look like, and which parts are stable

### The generating rule

Node names are built by WirePlumber, not by PipeWire core. From
`.../wireplumber-0.5.14/share/wireplumber/scripts/monitors/alsa.lua`, the node name
(line 241 ff.):

```lua
local name =
    (stream == "capture" and "alsa_input" or "alsa_output")
    .. "." ..
    (dev_props["device.name"]:gsub("^alsa_card%.(.+)", "%1") or ...)
    .. "." ..
    profile
name = name:gsub("([^%w_%-%.])", "_")   -- sanitize
```

and the device name it feeds on (line 413 ff.):

```lua
local name = "alsa_card." ..
  (properties["device.name"] or
   properties["device.bus-id"] or
   properties["device.bus-path"] or
   tostring(id)):gsub("([^%w_%-%.])", "_")
```

So the shape is:

```
alsa_input.<device-id>.<profile>       # capture / mic
alsa_output.<device-id>.<profile>      # playback / sink
alsa_output.<device-id>.<profile>.monitor   # desktop audio
```

### Where `<device-id>` comes from — the stability answer

`device.bus-id` and `device.bus-path` are set by PipeWire's ALSA udev plugin from udev
properties:

```c
str = udev_device_get_property_value(udev_device, "ID_PATH");
if (!(str && *str))
	str = udev_device_get_syspath(udev_device);
if (str && *str)
	items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_BUS_PATH, str);
```

```c
if ((str = udev_device_get_property_value(udev_device, "ID_ID")) && *str)
	items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_DEVICE_BUS_ID, str);
```

Source: <https://raw.githubusercontent.com/PipeWire/pipewire/master/spa/plugins/alsa/alsa-udev.c>

Mapping: `ID_PATH` → `device.bus-path`, `ID_ID` → `device.bus-id`, `ID_SERIAL` →
`device.serial`.

That is the crux: **the name is derived from the USB/PCI topology and the device's own
serial — never from the ALSA card index.** `ID_ID` for a USB audio device looks like
`usb-Vendor_Model_SERIAL-00`; `ID_PATH` for onboard audio looks like
`pci-0000_00_1f.3`. Hence the familiar forms:

```
alsa_input.usb-Blue_Microphones_Yeti_Stereo_Microphone_REV8-00.analog-stereo
alsa_output.pci-0000_00_1f.3.analog-stereo
alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
```

The ALSA card index *is* recorded, but in a separate property (`api.alsa.card`), not in
the node name.

#### Stable across reboots

- The `alsa_input.` / `alsa_output.` prefix.
- The `usb-…` / `pci-…` device id, **provided the device stays in the same USB port**
  (`ID_PATH` is topological) or exposes a serial (`ID_ID` embeds it).
- The `.monitor` suffix.

#### NOT stable — never hardcode these

- **ALSA card indices** (`hw:1`, `card 1`). Reordered by driver probe order at boot. They
  do not appear in node names, but they do appear in `aplay -l` and in `-f alsa` device
  strings — which is a good reason not to use `-f alsa`.
- **PipeWire object ids / node ids** (the numbers in `wpctl status`). Per-session.
- **`object.serial`.** The upstream definition is: *"a 64 bit object serial number. This
  is a number incremented for each object that is created. The lower 32 bits are
  guaranteed to never be SPA_ID_INVALID."*
  Source: <https://docs.pipewire.org/group__pw__keys.html>
  It is a counter local to a daemon instance — unique and monotonic *within* a session,
  and reset when PipeWire restarts. Useful as a within-session handle, useless as a
  config constant.
- **PulseAudio source indices** (the leading integer in `pactl list short sources`).

#### Stable across reboots but NOT across device changes — the trap

Two moving parts sit inside an otherwise stable name:

1. **The profile suffix.** `analog-stereo`, `mono-fallback`, `iec958-stereo`, `pro-audio`
   — this is the *currently selected card profile*. Change the profile and the node name
   changes. For a Bluetooth headset this is the well-known A2DP↔HFP flip; the repo
   already pins `bluetooth.autoswitch-to-headset-profile = false` in
   `system/nixos/core/pipewire.nix`, which avoids the mid-call variant of this, but a
   manual profile change still renames the node.
2. **The dedup counter.** Both the device and node naming loops append `.2` … `.99` on
   collision (`alsa.lua` lines 259-265 and 422-428). Two identical USB capture devices
   with no distinguishing serial can therefore swap which one is plain and which one is
   `.2` across reboots.

Bluetooth devices follow a parallel scheme — `libspa-bluez5.so` contains the template
`bluez_card.%s` (MAC address, `:` → `_`), yielding `bluez_input.AA_BB_CC_DD_EE_FF.<profile>`.

---

## 3. Desktop audio: the `.monitor` source of the default sink

### Monitor naming is mechanical

Every sink has a monitor source named by appending `.monitor` to the sink name. From
PipeWire's Pulse server:

```c
if (!pw_manager_object_is_source(peer)) {
    size_t len = (name ? strlen(name) : 5) + 10;
    if (len <= MAX_NAME) {
        peer_name = tmp = alloca(len);
        spa_scnprintf(tmp, len, "%s.monitor", name ? name : "sink");
    }
}
```

Source: <https://raw.githubusercontent.com/PipeWire/pipewire/master/src/modules/module-protocol-pulse/pulse-server.c>

Corroborated on disk — `strings libpipewire-module-protocol-pulse.so` contains the
literals `%s.monitor`, `Monitor of %s` and `node.name.monitor`.

### Resolving "whatever the default sink is right now" in one command

There are two ways, and the better one needs **no shell command at all**.

#### Option A (preferred): `@DEFAULT_MONITOR@` — resolved server-side

`pactl(1)`, shipped at
`/nix/store/…-pulseaudio-17.0/share/man/man1/pactl.1.gz`, states:

> "When supplied as arguments to the commands below, the special names @DEFAULT_SINK@,
> @DEFAULT_SOURCE@ and @DEFAULT_MONITOR@ can be used to specify the default sink, source
> and monitor respectively."

The reflex is to assume that is pactl-side sugar. **It is not.** Checking the binaries
directly:

```
$ strings .../pulseaudio-17.0/bin/pactl | grep -xE '@DEFAULT_SINK@|@DEFAULT_SOURCE@|@DEFAULT_MONITOR@'
(no output — pactl holds them only inside its help sentence)

$ strings .../pulseaudio-17.0/lib/pulseaudio/libpulsecore-17.0.so | grep -xE '@DEFAULT_.*@'
@DEFAULT_SINK@
@DEFAULT_SOURCE@
@DEFAULT_MONITOR@

$ strings .../pipewire-1.6.8/lib/pipewire-0.3/libpipewire-module-protocol-pulse.so | grep -iE '@DEFAULT'
@DEFAULT_MONITOR@
@DEFAULT_SINK@
@DEFAULT_SOURCE@

$ strings .../libpulseaudio-17.0/lib/libpulse.so.0 | grep -E '@DEFAULT'
(no output — the client library does not resolve them either)
```

The names are resolved **by the server**. In PulseAudio proper, `pa_namereg_get`:

```c
} else if (type == PA_NAMEREG_SOURCE && name && pa_streq(name, "@DEFAULT_MONITOR@")) {
    if (c->default_sink)
        return c->default_sink->monitor_source;
    else
        return NULL;
}
```

Source: <https://raw.githubusercontent.com/pulseaudio/pulseaudio/master/src/pulsecore/namereg.c>

and that function is on the record-stream path — `command_create_record_stream` resolves
a client-supplied name with
`pa_namereg_get(c->protocol->core, source_name, PA_NAMEREG_SOURCE)`.
Source: <https://raw.githubusercontent.com/pulseaudio/pulseaudio/master/src/pulsecore/protocol-native.c>

PipeWire implements the same contract in `find_device()`:

```c
if (spa_streq(name, DEFAULT_MONITOR)) {
    if (sink)
        return NULL;
    sink = true;
    find_default = true;
    monitor = true;
    allow_monitor = true;
}
```

and `find_device()` is called from `do_create_record_stream()` as
`o = find_device(client, source_index, source_name, false, &is_monitor);`.
Source: <https://raw.githubusercontent.com/PipeWire/pipewire/master/src/modules/module-protocol-pulse/pulse-server.c>

**Therefore `ffmpeg -f pulse -i @DEFAULT_MONITOR@` works**, because ffmpeg passes the
literal string through (§1) and the server resolves it against the current default sink
at connect time.

> Caveat worth stating: this was established from source and from the binaries on disk,
> not executed against a live server (no PipeWire on `dev-vm`). It should be smoke-tested
> once on the desktop.

#### Option B: resolve explicitly in the shell

`pactl get-default-sink` — *"Returns the symbolic name of the default sink"* (`pactl(1)`)
— plus the mechanical suffix:

```sh
DESKTOP_SRC="$(pactl get-default-sink).monitor"
```

Option B is worth doing **anyway**, not instead: it gives the preflight a concrete name to
display and log, so the take record shows which sink was captured. Use B to *report*, and
either B's result or `@DEFAULT_MONITOR@` to *capture*.

`wpctl` cannot substitute here. Its special identifiers are `@DEFAULT_SINK@`,
`@DEFAULT_AUDIO_SINK@`, `@DEFAULT_SOURCE@`, `@DEFAULT_AUDIO_SOURCE@`,
`@DEFAULT_VIDEO_SOURCE@` (`wpctl(1)`, SPECIAL IDENTIFIERS) — there is **no
`@DEFAULT_MONITOR@` in wpctl**, and `wpctl status` prints a tree meant for humans, not a
parseable name list.

---

## 4. Mic: bind to the default, or to a fixed name?

This is genuinely a choice between two different failure modes, and the source code makes
the difference precise.

### The mechanism

In `do_create_record_stream`, PipeWire's Pulse server decides whether to pin the stream:

```c
} else if (source_name != NULL) {
    if ((id = atoi(source_name)) != 0)
        source_index = id;
}
if (source_index != SPA_ID_INVALID && source_index != 0) {
    pw_properties_setf(props, PW_KEY_TARGET_OBJECT, "%u", source_index);
} else if (source_name != NULL) {
    if (o != NULL)
        source_name = pw_properties_get(o->props, PW_KEY_NODE_NAME);
    if (spa_strendswith(source_name, ".monitor")) {
        is_monitor = true;
        pw_properties_setf(props, PW_KEY_TARGET_OBJECT,
                "%.*s", (int)strlen(source_name)-8, source_name);
    } else {
        pw_properties_set(props, PW_KEY_TARGET_OBJECT, source_name);
    }
}
```

Source: <https://raw.githubusercontent.com/PipeWire/pipewire/master/src/modules/module-protocol-pulse/pulse-server.c>

Read carefully, this says:

- **If the client supplies *any* name** — including `@DEFAULT_SOURCE@` — the name is
  re-resolved to the concrete node's `node.name` and written to `target.object`. The
  stream is **pinned to the device that happened to be default at connect time**.
- **If the client supplies no name at all** (ffmpeg `-i default` → `device = NULL`),
  neither branch runs and `target.object` is left unset — the session manager owns the
  choice.
- For a monitor, `target.object` is set to the **sink's** node name (the trailing
  `.monitor`, 8 chars, is stripped) with an `is_monitor` flag. The monitor is addressed as
  "the sink, monitor side", not as a separate node.

### What the session manager does with an unpinned stream

WirePlumber re-runs target selection whenever the default changes. From
`.../scripts/linking/rescan.lua`:

```lua
    -- on any "default" target changed
    EventInterest {
      Constraint { "event.type", "=", "metadata-changed" },
      Constraint { "metadata.name", "=", "default" },
      Constraint { "event.subject.key", "c", "default.audio.source",
          "default.audio.sink", "default.video.source" },
    },
```
→ `source:call ("schedule-rescan", "linking")`

and `find-default-target.lua` supplies the new default to any stream that has not already
had a target picked.

### So: what breaks in each case

**`-i default` (follows the default):** a headset plugged in mid-session that becomes the
new default causes WirePlumber to **move the live recording onto the headset mic**. The
ffmpeg process does not notice and the file does not break — there is no gap, no stream
restart. But the voice changes character mid-take, silently, and nothing in the output
says so. For a recording you intend to publish, that is the worse failure: it is invisible
until playback.

**`-i <fixed name>` (pinned):** plugging in a headset changes nothing; the take continues
on the chosen mic. This is the behaviour you want for a deliberate recording.

The pin is not absolute, though, and it is worth knowing the edge: `target.object` is
matched by name, not by serial. `find-defined-target.lua` looks up a non-numeric
`target.object` against `node.name`/`object.path`:

```lua
    elseif target_value then
      for lnkbl in om:iterate { type = "SiLinkable" } do
        local target_props = lnkbl.properties
        if (target_props ["node.name"] == target_value or
            target_props ["object.path"] == target_value) and ...
```

If the pinned device is **unplugged** mid-take, that lookup fails, `has_defined_target`
is set false, and — because ffmpeg cannot set `node.dont-fallback` (the property that
makes WirePlumber *wait* rather than fall back; `find-defined-target.lua:116`) — the
chain falls through to `find-default-target` and the capture moves to the current
default. Name-based pinning also means the stream can re-attach if the same-named device
returns.

Note also that ffmpeg never sets `PA_STREAM_DONT_MOVE` (§1), so
`PW_STREAM_FLAG_DONT_RECONNECT` is never applied — the stream is always movable in
principle.

**Recommendation: resolve at start time, then pin.** Run `pactl get-default-source` once
during preflight, show the operator the resolved name, and pass that concrete name to
ffmpeg. This gets the pinned behaviour while still honouring "whatever mic I have
selected right now", and the preflight display makes the choice visible before the take
starts — which is exactly what ticket 05's preview is for.

Do **not** hardcode a mic name into the Nix config. The name embeds a USB serial and a
profile suffix (§2); it will break the day the mic moves ports or its profile changes,
and it will break silently in a config file where nobody is looking.

---

## 5. Reading a mic level without stealing the device

**Yes — a preflight meter can read the mic while ffmpeg records from it. Sources are
shared by default in both implementations.**

### PulseAudio

`pa_source` tracks recording streams in an idxset and caps them at:

```c
#define PA_MAX_OUTPUTS_PER_SOURCE 256
```

Source: <https://raw.githubusercontent.com/pulseaudio/pulseaudio/master/src/pulsecore/source.h>

256 simultaneous source-outputs per source. Sharing is the design, not a special case —
it is how `pavucontrol`'s meters coexist with running recordings.

### PipeWire

Exclusivity is opt-in and off by default. `node.exclusive`:

> "If this node wants to be linked exclusively to the sink/source." — default `false`

Source: <https://docs.pipewire.org/page_man_pipewire-props_7.html>

And `libpipewire-module-protocol-pulse.so` does **not** contain the string
`node.exclusive` at all (verified with `strings`), so a Pulse-protocol client such as
ffmpeg never requests exclusivity. Two ffmpeg processes on the same source simply produce
two links from the same node.

This also means the monitor source can be read by the recorder and a meter at once, and
that a second `-f pulse` input in the *same* ffmpeg invocation is fine.

### How to read the level

Four candidates, assessed:

| Tool | Verdict |
| --- | --- |
| `pactl` | **No meter.** `pactl(1)`'s full command list has `get-source-volume` (the *fader* setting, not signal level) and `subscribe` (events, not levels). No peak/RMS readout. |
| `wpctl` | **No meter.** `wpctl(1)` offers `status`, `get-volume`, `set-volume`, `inspect`, `set-default`. `get-volume` is again the fader, not the signal. |
| `pw-cat` / `pw-record` | Can capture concurrently — `--target` accepts *"The object.serial or the node.name of a target node"* (<https://docs.pipewire.org/page_man_pw-cat_1.html>) — but it only writes a file/stream. You would still need to compute a level from the samples. |
| **ffmpeg `astats`** | **Best fit.** Already a dependency, already knows how to open the source, emits a numeric level per frame. |

`ebur128` also works and is arguably more correct perceptually (it prints M/S/I loudness
in LUFS), but it is built for programme loudness over time, not a fast-responding preflight
bar. `astats` with `reset=1` gives a per-window RMS, which is what a meter wants.

**Verified live on this machine:**

```sh
$ ffmpeg -hide_banner -loglevel error \
    -f lavfi -i "sine=frequency=440:duration=1:sample_rate=48000" \
    -af "astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-" \
    -f null -
frame:0    pts:0       pts_time:0
lavfi.astats.Overall.RMS_level=-21.039359
frame:1    pts:1024    pts_time:0.0213333
lavfi.astats.Overall.RMS_level=-21.101955
...
```

Swap the `lavfi` input for `-f pulse -i "$MIC_SRC"` and this is the preflight meter. The
`RMS_level` value is in dBFS (negative; `-inf` on digital silence), so a bar is a simple
clamp of, say, −60…0 dB.

`astats` options confirmed from `ffmpeg -h filter=astats` on this build: `metadata`
(inject metadata into the filtergraph, default false), `reset` (frames between cumulative
resets, default 0), `length` (window length, default 0.05 s).

One practical note: the meter is a *separate* ffmpeg process from the recorder. Because
sources are shared, it can keep running during the take to satisfy the map's "preview
both … and during it" requirement — no need to tear it down when recording starts.

---

## 6. Two separate tracks, never mixed

Each `-f pulse -i …` is its own input. Mapping each one's audio into the output with its
own `-map` yields two independent streams; no filter graph, so no possibility of
accidental mixing.

> "Each input or output can, in principle, contain any number of elementary streams of
> different types (video/audio/subtitle/attachment/data), though the allowed stream counts
> and/or types may be limited by the container format."

Source: <https://ffmpeg.org/ffmpeg.html>

Matroska handles multiple audio tracks without reservation and supports per-track
`title` metadata, which makes the two tracks self-describing in LosslessCut. Container
choice belongs to ticket 07; the mapping shown below is container-independent.

Add `-thread_queue_size` on each input: with several live capture inputs feeding one
muxer, the default queue is easy to overrun and ffmpeg warns about it.

---

## Recommendation

### Resolving both source names at runtime

Both sources resolved in one command each, at start time, then pinned. Written for
**fish** (this machine's shell per the environment; `pactl` is invoked directly):

```fish
# --- resolve both audio sources at start time -------------------------------
# Mic: whatever is the default capture device right now, pinned for the take.
set -l MIC_SRC (pactl get-default-source)
# Desktop: the monitor source of whatever is the default sink right now.
set -l DESKTOP_SRC (pactl get-default-sink).monitor

# Fail loudly in preflight rather than recording silence.
if test -z "$MIC_SRC" -o "$MIC_SRC" = "@NONE@"
    echo "No default audio source (mic). Pick one with wpctl set-default." >&2
    exit 1
end
if test -z "$DESKTOP_SRC" -o "$DESKTOP_SRC" = "@NONE@.monitor"
    echo "No default audio sink, so no desktop-audio monitor." >&2
    exit 1
end

# Confirm both exist as real sources before the take starts.
set -l SOURCES (pactl list short sources | cut -f2)
contains -- "$MIC_SRC" $SOURCES; or begin
    echo "Mic source vanished: $MIC_SRC" >&2; exit 1
end
contains -- "$DESKTOP_SRC" $SOURCES; or begin
    echo "Monitor source not found: $DESKTOP_SRC" >&2; exit 1
end

echo "mic     : $MIC_SRC"
echo "desktop : $DESKTOP_SRC"
```

POSIX-sh equivalent, if the script ends up as `#!/usr/bin/env bash`:

```sh
MIC_SRC="$(pactl get-default-source)"
DESKTOP_SRC="$(pactl get-default-sink).monitor"
[ -n "$MIC_SRC" ] && [ "$MIC_SRC" != "@NONE@" ] || { echo "no default mic" >&2; exit 1; }
pactl list short sources | cut -f2 | grep -qxF "$DESKTOP_SRC" \
  || { echo "monitor source not found: $DESKTOP_SRC" >&2; exit 1; }
```

`pactl` must be on `PATH` — add `pulseaudio` (for the `pactl` binary) or
`pipewire.pulse` tooling to the record command's `buildInputs`/wrapper in ticket 10's
packaging. It is **not** currently in the user profile.

### ffmpeg input flags — two separate tracks

```sh
ffmpeg \
  -thread_queue_size 1024 -f pulse -sample_rate 48000 -channels 1 -i "$MIC_SRC" \
  -thread_queue_size 1024 -f pulse -sample_rate 48000 -channels 2 -i "$DESKTOP_SRC" \
  \
  <video input(s) here — see tickets 01/02> \
  \
  -map 0:a -map 1:a \
  -c:a aac -b:a 192k \
  -metadata:s:a:0 title="Mic" \
  -metadata:s:a:1 title="Desktop" \
  "$OUT"
```

Notes on the flags:

- `-channels 1` on the mic gives a genuine mono track instead of a duplicated stereo pair
  (the demuxer default is 2). `-channels 2` keeps desktop audio in stereo. Both must
  precede their `-i`.
- `-sample_rate 48000` matches the demuxer default and PipeWire's usual graph rate; stating
  it explicitly avoids a surprise resample if the default ever changes.
- `-map 0:a -map 1:a` is what keeps them separate. There is no `amix`/`amerge` anywhere in
  the chain, so the two tracks cannot be combined by accident.
- Once the video inputs are added, the video input indices shift. Keep the two audio
  inputs **first** so `0:a` and `1:a` stay correct, or switch to named maps.

### Substitutions worth considering

- **Desktop audio** can be `-i @DEFAULT_MONITOR@` instead of the resolved string — the
  server resolves it (§3), so it survives even if `pactl` is unavailable. Resolving it in
  the shell is still preferable because it lets the preflight *display* the sink name and
  fail before ffmpeg starts. Smoke-test `@DEFAULT_MONITOR@` on the desktop before relying
  on it.
- **Mic** should *not* use `-i default`. That is the one form that leaves the stream
  unpinned and lets a mid-take headset silently take over the recording (§4).

### Preflight meter (runs alongside the take)

```sh
ffmpeg -hide_banner -loglevel error \
  -f pulse -channels 1 -i "$MIC_SRC" \
  -af "astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-" \
  -f null -
```

Safe to run concurrently with the recording — sources permit up to 256 simultaneous
readers on PulseAudio and are non-exclusive by default on PipeWire (§5).

### What the preflight should actually verify

1. `pactl info` succeeds — the server is up at all.
2. `pactl get-default-source` and `get-default-sink` return non-empty, non-`@NONE@`.
3. Both resolved names appear in `pactl list short sources`.
4. The mic is not muted: `pactl get-source-mute "$MIC_SRC"`.
5. The meter shows signal above a floor (say −50 dBFS) while the operator speaks — this
   is the check that catches a muted-in-hardware mic, which none of the above will.

---

## Open items for the desktop machine

These could not be closed from `dev-vm` and need one session on the rig:

- Capture the real output of `pactl list short sources`, `pactl info` and `wpctl status`
  and record the concrete mic/sink names, to confirm the naming derivation in §2 against
  actual hardware.
- Smoke-test `ffmpeg -f pulse -i @DEFAULT_MONITOR@` (established from source, not executed).
- Confirm `pactl` is added to the record command's runtime closure (ticket 10).

## Sources

**Executed on this machine**
- `ffmpeg -hide_banner -devices`, `-demuxers`, `-version`, `-h demuxer=pulse`,
  `-h filter=astats`, `-h filter=ebur128`, `-sources pulse` — ffmpeg 6.1.6
- `astats`/`ametadata` meter chain against a synthetic `lavfi` sine (output quoted in §5)

**Upstream man pages read from the Nix store**
- `pactl(1)` — `/nix/store/0950c80dzljpyp6qx6bqslp65mnf2fgn-pulseaudio-17.0/share/man/man1/pactl.1.gz`
- `wpctl(1)` — `/nix/store/n6in5bks4mv075xdnl5g7rx4npr03z1g-wireplumber-0.5.14/share/man/man1/wpctl.1.gz`

**Upstream scripts and binaries read from the Nix store**
- `.../wireplumber-0.5.14/share/wireplumber/scripts/monitors/alsa.lua`
- `.../wireplumber-0.5.14/share/wireplumber/scripts/linking/{rescan,find-default-target,find-defined-target}.lua`
- `.../pipewire-1.6.8/lib/pipewire-0.3/libpipewire-module-protocol-pulse.so` (`strings`)
- `.../pipewire-1.6.8/lib/spa-0.2/alsa/libspa-alsa.so`, `.../bluez5/libspa-bluez5.so` (`strings`)
- `.../pulseaudio-17.0/lib/pulseaudio/libpulsecore-17.0.so`, `bin/pactl`,
  `.../libpulseaudio-17.0/lib/libpulse.so.0` (`strings`)

**Official documentation**
- FFmpeg device documentation — <https://ffmpeg.org/ffmpeg-devices.html>
- FFmpeg CLI documentation — <https://ffmpeg.org/ffmpeg.html>
- PipeWire property keys — <https://docs.pipewire.org/group__pw__keys.html>
- PipeWire `pipewire-props(7)` — <https://docs.pipewire.org/page_man_pipewire-props_7.html>
- PipeWire `pw-cat(1)` — <https://docs.pipewire.org/page_man_pw-cat_1.html>
- WirePlumber linking policy — <https://pipewire.pages.freedesktop.org/wireplumber/policies/linking.html>

**Upstream source code**
- `libavdevice/pulse_audio_dec.c` — <https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/libavdevice/pulse_audio_dec.c>
- `src/modules/module-protocol-pulse/pulse-server.c` — <https://raw.githubusercontent.com/PipeWire/pipewire/master/src/modules/module-protocol-pulse/pulse-server.c>
- `spa/plugins/alsa/alsa-udev.c` — <https://raw.githubusercontent.com/PipeWire/pipewire/master/spa/plugins/alsa/alsa-udev.c>
- `src/pulsecore/namereg.c` — <https://raw.githubusercontent.com/pulseaudio/pulseaudio/master/src/pulsecore/namereg.c>
- `src/pulsecore/protocol-native.c` — <https://raw.githubusercontent.com/pulseaudio/pulseaudio/master/src/pulsecore/protocol-native.c>
- `src/pulsecore/source.h` — <https://raw.githubusercontent.com/pulseaudio/pulseaudio/master/src/pulsecore/source.h>

**Repo config consulted**
- `system/nixos/core/pipewire.nix`, `profile/desktop/options.nix`
