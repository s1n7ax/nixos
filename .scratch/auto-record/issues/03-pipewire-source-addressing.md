# Addressing mic and desktop audio from ffmpeg

Type: research
Status: resolved

## Question

How does the script name the mic and the desktop-audio monitor to ffmpeg so it keeps working across reboots and device changes?

- What do PipeWire node names / PulseAudio-compat source names look like on this machine, and which parts are stable versus regenerated?
- Can ffmpeg's `-f pulse -i <source>` take a stable alias, or does it need an id resolved at runtime via `pactl`/`wpctl`?
- How is "desktop audio" addressed — the sink monitor of whatever is currently the default sink, resolved at start time?
- If the default mic changes (headset plugged in), should the script bind to the default at start time or to a fixed named device?
- How do we read a live mic level for the preflight meter (ticket 05's meter) from the same source without stealing it from the recording?

Answer decides how the two audio tracks are opened and what the preflight actually verifies.

## Answer

Findings: [research/03-pipewire-source-addressing.md](../research/03-pipewire-source-addressing.md) (716 lines, sourced from WirePlumber `alsa.lua`, PipeWire `alsa-udev.c`, ffmpeg's pulse input source, and `strings` over `libpulsecore` in the Nix store).

- **`-f pulse` is the only route.** ffmpeg has no native PipeWire input — verified locally: `ffmpeg -demuxers` lists only alsa/jack/oss/pulse, and the build has `--enable-libpulse` with no libpipewire. ffmpeg passes the `-i` string verbatim to `pa_stream_connect_record`, special-casing only the literal `default`.
- **Source names are `alsa_input|alsa_output.<usb-…|pci-…>.<profile>[.monitor]`**, built from udev `ID_ID`/`ID_PATH`. The device id is stable across reboots for the same USB port / serial and never contains the ALSA card index. Unstable: node ids, `object.serial`, Pulse indices — plus two traps *inside* the name, the profile suffix and the `.2`…`.99` dedup counter.
- **Desktop audio: `@DEFAULT_MONITOR@` resolves server-side**, proven by `strings` — the literal lives in `libpulsecore` and PipeWire's pulse module, not in `pactl` or `libpulse`, and sits on the record-stream path in both. So `ffmpeg -f pulse -i @DEFAULT_MONITOR@` works. Still resolve it explicitly via `pactl get-default-sink` + `.monitor` so preflight can display the device and fail early rather than silently recording the wrong sink.
- **The mic must be pinned to a concrete node name, never `-i default`.** Any supplied name gets re-resolved and written to `target.object`; supplying *no* name leaves it unset, and WirePlumber's `rescan.lua` then re-links the unpinned stream whenever `default.audio.source` changes. A headset plugged in mid-take would silently take over the recording with no gap and no error.
- **Concurrent metering is safe.** Sources allow 256 simultaneous readers (PulseAudio) and `node.exclusive` defaults false (PipeWire), so the preflight meter can read the same mic the recording holds. An `astats` / `ametadata` RMS chain is given in the findings and was verified locally.

**Caveat, now ticket 11**: this session ran on `dev-vm`, which has no PipeWire socket, so no live device listing was captured. The naming rules come from the code that generates the names — authoritative, but one confirming `pactl list short sources` on the desktop is still owed.

Status: resolved
