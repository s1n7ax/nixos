# Where the record command lives in this repo

Type: grilling
Status: open

## Question

- `writeShellApplication` in `system/home-manager/applications/scripts.nix` alongside `camera-connect`, or its own module under `applications/` with a feature flag like the `obs-studio` directory has?
- Is it one command or several — `record` alone, or `record` plus a retained `camera-connect`? Does `camera-connect` survive at all, or fold into `record`?
- Tunables (circle corner and size, output directory, monitor, encoder) — hardcoded in the nix expression, exposed as module options, or read from a config file at runtime?
- Does it want a Hyprland keybind, given ticket 10's answer on how a take starts and stops?
- The output directory `/home/s1n7ax/Videos/Youtube/00 new` does not exist on this machine. Does nix create it, or does the script?

Use `/grilling` and `/domain-modeling`.

**From ticket 11**: the `pactl` worry raised in ticket 05 is retired — the pipeline never needs it.
ffmpeg resolves `@DEFAULT_MONITOR@` server-side on its own, and preflight can read the default sink
with `pw-metadata -n default` + `jq`, both already in `/run/current-system/sw/bin`. Nothing has to
pull `pulseaudio` into the script's PATH.

**From ticket 06**: the thing being packaged is now specified — a **thin supervisor** that
spawns `ffplay` → `wf-recorder` → `gphoto2` → one `ffmpeg`, opens the preview fifo `O_RDWR`
itself (plain `>` deadlocks waiting for a reader), runs a headless ~2 s `gphoto2` warm-up and a
three-way preflight gate before any of it, traps SIGINT into a timed SIGINT/SIGTERM/SIGKILL
ladder, and globs `* UNTITLED.mkv` at startup to name orphaned takes. That is real control flow,
signal handling and a prompt loop — which bears on whether this can be a shell script at all.
