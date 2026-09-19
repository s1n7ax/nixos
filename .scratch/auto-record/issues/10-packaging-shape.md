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
