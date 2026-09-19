# Where the record command lives in this repo

Type: grilling
Status: resolved

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

## Answer

### Its own directory, in Python, `callPackage`d — not a shell script in `scripts.nix`

`system/home-manager/applications/record/`, built by `runCommand` + `makeWrapper` over a
`python3` interpreter, exactly as `img-crop/` and `hyprland/voice-indicator/` already are in this
repo. `screen-capture.nix` pulls it in with `(callPackage ./record { })`.

The ticket asked whether this can be a shell script at all. It cannot, and the reason is
specific rather than aesthetic — the supervisor has to:

- hold four children in **separate sessions** so the terminal's Ctrl-C reaches only the
  supervisor, and walk **one** of them down a timed SIGINT → SIGTERM → SIGKILL ladder;
- plumb **two anonymous pipes by file descriptor** into a single ffmpeg (`pipe:7`, `pipe:8`) and
  close all four ends afterwards, while a third child holds a fifo open `O_RDWR`;
- **parse concatenated JPEG headers** out of a live byte stream to measure the camera's geometry
  and rate before anything is spawned;
- run a **poll loop over `pw-dump` JSON** in the background for the whole take;
- and keep a level meter, a prompt and a watcher on the terminal at once.

In shell that is a pile of `trap`, `exec {fd}<>`, `jq` and background subshells with no way to
test any of it. In Python it is eleven small modules and **119 headless tests**, run the way this
repo already runs img-crop's: `python3 -m unittest discover --pattern 'test_*.py'`.

Gated by `features.productivity.video-production.screen-capture.enable`, not
`features.cli.scripts.enable` — it is video production, and that is the flag the destination's
other half (LosslessCut, ticket 09) sits behind.

### One command. `camera-connect` is untouched

`record` alone. `camera-connect` stays exactly as it is: ticket 06 settled that one ffmpeg reads
`gphoto2 --capture-movie` straight off a pipe, so nothing creates a loopback device any more and
the script is dead code — but deleting it is repo tidying, which the map already puts outside
this route.

### Tunables: constants in `config.py`. No options, no config file, no flags

Ticket 04 settled this for the circle ("fixed, not configurable") and it generalises. The
destination is *one `record` command with nothing to configure by hand*; a module option or a
runtime config file is a second thing to get right before a take. Every constant — monitor,
rates, circle geometry, ring colour, the mic's node name, the output folder — lives in one file
with the measurement that fixed it written beside it.

The one flag is `record --check`: preflight only, no take. It answers "is the camera on the
right setting and is the right headset default?" without starting a file, which is the question
you actually have before sitting down.

### No Hyprland keybind

`record` is a foreground process that asks two questions on the terminal — Enter to mark the
start, and the description after Ctrl-C. A keybind would launch it somewhere you are not
looking, and there would be nowhere to type the answer. It is run from a terminal, deliberately.

### The script creates the output directory

`~/Videos/Youtube/00 new` is created with `mkdir -p` at startup. Nix cannot create an empty
directory in `$HOME` without an activation script or a placeholder file, and the script has to
survive the directory being absent anyway — a deleted folder should not be a failed take.

### Reviewed and kept

Two things the spec review flagged as scope creep are deliberate, and stay:

- **`takes.unique()`** invents a ` 2` suffix although ticket 06 says the timestamp is already
  unique. It should never fire. It exists because `Path.rename` overwrites its destination
  silently, and the thing it would overwrite is a take.
- **`--set-config viewfinder=1`** on the gphoto2 command is not preflight driving the camera in
  the sense ticket 06 ruled out. It opens live view, which is the stream being read; the mode
  switch, `liveviewsize` and Movie rec quality stay the human's job, and the gate only ever
  reads them.
