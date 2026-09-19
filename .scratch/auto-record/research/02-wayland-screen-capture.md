# How a 3440x1440 Hyprland screen reaches an ffmpeg filter graph on NVIDIA

Type: research
Answers: `.scratch/auto-record/issues/02-wayland-screen-capture-into-ffmpeg.md`
Date: 2026-09-19

Every claim below is tagged with the primary source it came from. Where a claim
comes from reading source code, the file URL is given and the relevant lines are
quoted inline.

---

## 0. Verdict up front

| Route | Filterable ffmpeg input? | Works on NVIDIA proprietary + Hyprland? | Dialog every run? |
|---|---|---|---|
| **wf-recorder → pipe** | **Yes** (`-c rawvideo -m rawvideo -f pipe:1`) | **Yes** — no VAAPI in the path | No |
| wf-recorder → v4l2loopback | Yes | Yes | No |
| wl-screenrec | Yes (v4l2loopback / muxer) *in principle* | **No** — hard-fails: needs VAAPI **encode** | No |
| portal + PipeWire (GStreamer) | Yes, but only via a GStreamer bridge | Yes, with extra moving parts | Only on first run *if* a token is kept |
| ffmpeg native PipeWire | **Does not exist** | n/a | n/a |
| ffmpeg `kmsgrab` | Yes | **No** — needs DRM master or root | n/a |

Recommendation is at the bottom.

---

## 1. The machine, established rather than assumed

From this repo:

- `system/nixos/hardware/nvidia.nix:17` — `package = config.boot.kernelPackages.nvidiaPackages.legacy_580;`
  with the comment on line 15: *"GTX 1060 (Pascal) was dropped from the 595.xx 'stable' branch in 26.05; 580.xx is the legacy branch that still supports Pascal."*
  → the GPU is a **GeForce GTX 1060 (Pascal)**, `modesetting.enable = true`, `open = false`, `boot.kernelParams = [ "nvidia_drm.fbdev=1" ]`.
- `system/home-manager/applications/hyprland.nix` — monitor block: `mode = "3440x1440@144.00Hz"`, `scale = 1.25`; env includes `LIBVA_DRIVER_NAME = "nvidia"` and `__GLX_VENDOR_LIBRARY_NAME = "nvidia"`.
- `system/nixos/core/boot.nix:5` — `boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];` (module already available).
- `system/home-manager/applications/scripts.nix:227` — the existing `camera-connect` script already does `sudo modprobe v4l2loopback exclusive_caps=1 max_buffer=2` and feeds it with ffmpeg, i.e. **/dev/video\* is already claimed by the camera**.

Probed locally on this box (`ffmpeg -version`, `-encoders`, `-filters`, `-devices`):

- ffmpeg is **ffmpeg-full 6.1.6**, configured with `--enable-cuda --enable-cuda-llvm --enable-ffnvcodec --enable-nvenc --enable-nvdec --enable-vaapi --enable-vulkan --enable-libdrm`.
- `h264_nvenc`, `hevc_nvenc`, `av1_nvenc` are present.
- `hwupload_cuda`, `scale_cuda`, `overlay_cuda` are all present.
- `ffmpeg -devices` lists exactly: `alsa, caca, fbdev, jack, kmsgrab, lavfi, libcdio, libdc1394, openal, opengl, oss, pulse, sdl2, v4l2, x11grab, xv`. **There is no PipeWire input device.**

GPU capability, from NVIDIA's own support matrix
(<https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new>),
GeForce tab, row `GeForce GTX 1060`:

> `GeForce GTX 1060 | Pascal | 6th Gen | D/M | 1 | 1 | 12 | YES | NO | YES | YES | YES | NO | YES | YES | YES | YES | NO | NO`

against the header

> `BOARD | FAMILY | NVENC Generation | Desktop/Mobile | # OF CHIPS | Total # of NVENC | Max # of concurrent sessions | H.264 (AVC) YUV 4:2:0 | H.264 YUV 4:2:2 | H.264 YUV 4:4:4 | H.264 Lossless | H.265 (HEVC) 4K YUV 4:2:0 | HEVC YUV 4:2:2 | HEVC 4K YUV 4:4:4 | HEVC 4K Lossless | HEVC 8K | HEVC 10-bit support | HEVC B Frame support | AV1 YUV 4:2:0`

So: **1 NVENC engine, 12 concurrent sessions, H.264 4:2:0 and 4:4:4 yes, HEVC up to 8K and 10-bit yes, HEVC B-frames no, AV1 encode NO.** `av1_nvenc` exists in the ffmpeg build but the hardware cannot do it — H.264 or HEVC only.

---

## 2. Does Hyprland implement `wlr-screencopy`? Yes.

Hyprland's tree contains both the protocol XML and an implementation:

- <https://github.com/hyprwm/Hyprland/blob/main/protocols/wlr-screencopy-unstable-v1.xml>
- <https://github.com/hyprwm/Hyprland/blob/main/src/protocols/Screencopy.cpp> — defines `CScreencopyProtocol`, `CScreencopyFrame`, wires `setCopy` → `shareFrame(..., false)` and `setCopyWithDamage` → `shareFrame(..., true)`.

It *also* implements the newer replacement, `ext-image-copy-capture-v1`:
<https://github.com/hyprwm/Hyprland/blob/main/src/protocols/ImageCopyCapture.cpp>.

Nothing in the screencopy implementation is NVIDIA-conditional. The copy is
serviced by the compositor's renderer:

> `if (!withDamage) g_pHyprRenderer->damageMonitor(m_session->monitor());`
> — `Screencopy.cpp`, `CScreencopyFrame::shareFrame`

i.e. a **non-damage** copy request forces a full monitor repaint, then the frame
is handed back. This matters for frame rate (§6).

### The one Hyprland-side gotcha: the permission system

Hyprland gained a permission system with a `screencopy` permission, described at
<https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/advanced-configuration/permissions.md>:

> **screencopy** — Default: **ASK** — Access to your screen _without_ going through xdg-desktop-portal-hyprland. Examples include: `grim`, `wl-screenrec`, `wf-recorder`. If denied, will render a black screen with a "permission denied" text.

Crucially, the same page says it is off unless you turn it on:

> Before setting up permissions, make sure you enable them by setting `hl.config({ ecosystem = { enforce_permissions = true } })`, as it's disabled by default.

`grep -rn "enforce_permissions" /home/s1n7ax/nixos` returns nothing, so this repo
does **not** enable it — `wf-recorder` will not be prompted. If it is ever enabled,
the same page gives the NixOS-specific escape (paths are store paths, so regex is
required):

> ```lua
> hl.permission({ binary = "/nix/store/[a-z0-9]{32}-grim-[0-9.]*/bin/grim", type = "screencopy", mode = "allow" })
> ```

**This is the thing to remember: the "does it pop a dialog" question is not only a
portal question on Hyprland. The direct-protocol route has its own prompt, it is
just currently disabled.**

---

## 3. Route A — `wf-recorder`

Source: <https://github.com/ammen99/wf-recorder>. In nixpkgs unstable as
`wf-recorder` 0.6.0 (via the nixos MCP `info` query).

### Requirements

From the README:

> wf-recorder is a utility program for screen recording of `wlroots`-based compositors (more specifically, those that support `wlr-screencopy-v1` and `xdg-output`).

Enforced at runtime in `src/main.cpp` (`check_has_protos`):

> ```c
> if (screencopy_manager == NULL) { fprintf(stderr, "compositor doesn't support wlr-screencopy-unstable-v1\n"); exit(EXIT_FAILURE); }
> if (xdg_output_manager == NULL) { fprintf(stderr, "compositor doesn't support xdg-output-unstable-v1\n"); exit(EXIT_FAILURE); }
> ```

Hyprland provides both. **No VAAPI, no GBM, no DRM device is touched** unless you
ask for a VAAPI codec — see below. This is why it works on the NVIDIA blob when
`wl-screenrec` does not.

### Can it be an ffmpeg input? Yes — it writes through ffmpeg's own AVIO.

`src/frame-writer.cpp` builds a real libavformat output context and opens the
destination with `avio_open`:

> ```c
> this->outputFmt = av_guess_format(NULL, params.file.c_str(), NULL);
> auto streamFormat = determine_output_format(params);
> avformat_alloc_output_context2(&this->fmtCtx, NULL, streamFormat, params.file.c_str());
> ...
> if (avio_open(&fmtCtx->pb, params.file.c_str(), AVIO_FLAG_WRITE)) { std::cerr << "avio_open failed" ...; }
> ```
> — <https://github.com/ammen99/wf-recorder/blob/master/src/frame-writer.cpp>

`avio_open` resolves the string as an ffmpeg URL, so **`pipe:1` is a legal
`--file` value**. Per the ffmpeg protocols manual
(<https://ffmpeg.org/ffmpeg-protocols.html>, §`pipe`):

> `pipe:[number]` … `number` is the number corresponding to the file descriptor of the pipe (e.g. 0 for stdin, 1 for stdout, 2 for stderr).
> … Note that some formats (typically MOV), require the output protocol to be seekable, so they will fail with the pipe output protocol.

`rawvideo` and `nut` are not seekable-only, so both work over a pipe. (Confirmed
present locally: `ffmpeg -muxers` lists `E rawvideo` and `E nut`.)

The README documents the same trick for v4l2:

> To set a specific output format, use the `--muxer` option. For example, to output to a video4linux2 loopback you might use:
> ```
> wf-recorder --muxer=v4l2 --codec=rawvideo --file=/dev/video2
> ```

### The overwrite-prompt trap (this one will bite an unattended script)

`src/main.cpp`:

> ```c
> static bool user_specified_overwrite(std::string filename)
> {
>     struct stat buffer;
>     if (stat (filename.c_str(), &buffer) == 0 && !S_ISCHR(buffer.st_mode))
>     {
>         std::string input;
>         std::cerr << "Output file \"" << filename << "\" exists. Overwrite? Y/n: ";
>         std::getline(std::cin, input);
> ```

Consequences, exactly:

- `--file=pipe:1` → `stat("pipe:1")` fails → **no prompt**. ✅
- `--file=/dev/video2` (a **character** device) → `S_ISCHR` is true → **no prompt**. ✅
- `--file=/tmp/fifo` (a **FIFO**) → `stat` succeeds, `S_ISCHR` false → **it prompts and blocks on stdin**. ❌ unless you pass `-y/--overwrite`.
- `--file=/dev/stdout` when stdout is a pipe → resolves to a FIFO → **prompts**. ❌

So: prefer `pipe:1`; if you must use a named pipe, pass `-y`.

### Pixel format: it will hand you BGR0 untouched if you let it

`frame-writer.cpp`:

> ```c
> AVPixelFormat FrameWriter::handle_buffersink_pix_fmt(const AVCodec *codec)
> {
>     if (params.codec == DEFAULT_CODEC && params.pix_fmt.empty())
>         params.pix_fmt = "yuv420p";
>     if (!params.pix_fmt.empty())
>         return lookup_pixel_format(params.pix_fmt);
>     auto in_fmt = get_input_format();
>     /* For codecs such as rawvideo no supported formats are listed */
>     if (!codec->pix_fmts) return in_fmt;
> ```

and

> ```c
>     /* If the codec supports getting the appropriate RGB format
>      * directly, we want to use it since we don't have to convert data */
>     if (is_fmt_supported(in_fmt, codec->pix_fmts)) return in_fmt;
> ```

`meson_options.txt` sets `default_pixel_format` to `''`
(<https://github.com/ammen99/wf-recorder/blob/master/meson_options.txt>), so with
`-c rawvideo` the yuv420p default does not kick in and the capture format passes
through. Hyprland's shm format for a normal output is `XRGB8888`, which
`frame-writer.cpp`'s `GBM_FORMAT_XRGB8888 → AV_PIX_FMT_BGR0` table maps to **`bgr0`**.
Pass `-x bgr0` anyway so the pipe layout is pinned and does not silently change.

**This is the whole point: no swscale runs, no YUV conversion runs, wf-recorder
becomes a dumb 3440x1440 BGR0 frame pump.**

### CFR: `-r` inserts an `fps` filter

`frame-writer.cpp`, `init_video_filters`:

> ```c
>     if (params.framerate != 0){
>         if (params.video_filter != "null" && params.video_filter.find("fps") == std::string::npos) {
>             params.video_filter += ",fps=" + std::to_string(params.framerate);
>         }
>         else if (params.video_filter == "null"){
>             params.video_filter = "fps=" + std::to_string(params.framerate);
>         }
>     }
> ```

matching the man page
(<https://github.com/ammen99/wf-recorder/blob/master/manpage/wf-recorder.1>):

> `-r, --framerate framerate` — Sets hard constant framerate. Will duplicate frames to reach it. This makes the resulting video CFR.

**This is essential**, because raw video over a pipe carries no timestamps — the
`rawvideo` demuxer on the far side synthesises PTS from `-framerate`
(<https://ffmpeg.org/ffmpeg-formats.html> §`rawvideo`: *"Since there is no header
specifying the assumed video parameters, the user must specify them"*). A VFR
producer into a CFR-assuming consumer desyncs against audio. `-r 60` on
wf-recorder + `-framerate 60` on ffmpeg is a matched pair.

### The VAAPI path is codec-gated (and therefore irrelevant here)

`src/main.cpp` only ever creates a hardware device when the codec name contains
`vaapi`:

> ```c
>     if (params.codec.find("vaapi") != std::string::npos)
>     {
>         std::cerr << "using VA-API, trying to enable DMA-BUF capture..." << std::endl;
> ```

and `frame-writer.cpp` hard-codes the device type:

> ```c
>     int ret = av_hwdevice_ctx_create(&this->hw_device_context,
>         av_hwdevice_find_type_by_name("vaapi"), params.hw_device.c_str(), NULL, 0);
> ```

So `-c h264_nvenc` inside wf-recorder would encode from **software frames** (NVENC
accepts them, see §5) — but for our purpose we do not encode inside wf-recorder at
all. The important fact is that **wf-recorder never initialises VAAPI unless asked
to**, which is exactly why it survives on the NVIDIA blob.

---

## 4. Route B — `wl-screenrec`: dead on this machine

Source: <https://github.com/russelltg/wl-screenrec> (now redirects to
`rosalyntg/wl-screenrec`). In nixpkgs unstable as `wl-screenrec` 0.2.0.

The README's System Requirements section lists, alongside the Wayland protocols:

> * [`vaapi`](https://01.org/temp-linuxgraphics/community/vaapi) **encode** support, consult your distribution for how to set this up. Known good configurations:
>   * Intel iGPUs
>   * Radeon GPUs

It also confirms Hyprland ≥ 0.48 satisfies the protocol side, and states the
design premise:

> Uses dma-buf transfers to get surface, and uses the GPU to do both the pixel format conversion and the encoding, meaning the raw video data never touches the CPU.

**There is no VAAPI encode driver for NVIDIA.** The driver this repo selects with
`LIBVA_DRIVER_NAME = "nvidia"` is `nvidia-vaapi-driver`, whose README opens with:

> This is an VA-API implementation that uses **NVDEC** as a backend.

and, under Codec Support:

> **Hardware decoding only, encoding is [not supported](/../../issues/116).**
> — <https://github.com/elFarto/nvidia-vaapi-driver/blob/master/README.md>

This is not theoretical — it is reported against wl-screenrec on exactly this
stack (Hyprland + NVIDIA proprietary), issue #79
(<https://github.com/rosalyntg/wl-screenrec/issues/79>):

> ```
> Opening libva device from DRM device /dev/dri/renderD128
> [AVHWFramesContext] Failed to create surface: 14 (the requested RT Format is not supported).
> failed to create encoder(s): Failed to create vaapi frame context for capture surfaces of format BGRZ 2560x1440
> ```

and the reporter notes `--no-hw` fails identically — because the *capture-side*
frame context is VAAPI too, not just the encoder. The maintainer's reply:

> This isn't going to work as-is; **there is no vaapi encode driver for Nvidia.**
> However, vulkan encode is supposed to work well on nvidia. … pass `--experimental-vulkan`

That Vulkan work is on a branch. The current README's complete `--help` dump
contains no `--experimental-vulkan` flag, so it is not in a released build.
Vulkan *encode* on a GTX 1060 is also not a given.

Separately, issue #64 (<https://github.com/rosalyntg/wl-screenrec/issues/64>) is
"Fractional scaling does not work on Hyprland", traced by the maintainer to
Hyprland (<https://github.com/hyprwm/Hyprland/issues/4991>). This repo runs
`scale = 1.25`, so even on a supported GPU this would be a live risk.

**Conclusion: wl-screenrec cannot start on this machine.** Its stdout/v4l2
capabilities (it documents `wl-screenrec --ffmpeg-muxer v4l2 -f /dev/video6`) are
moot.

---

## 5. Route C — xdg-desktop-portal + PipeWire

### 5a. ffmpeg cannot read PipeWire. At all.

This is the fact that decides the route. Checked three ways:

1. `ffmpeg -devices` on this box lists no pipewire device (full output in §1).
2. FFmpeg master's `libavdevice/` contains no `pipewire*` source file — the full
   `.c` listing is `alsa, android_camera, avdevice, caca, decklink*, dshow*, fbdev*,
   gdigrab, iec61883, jack, kmsgrab, lavfi, libcdio, libdc1394, openal-dec, oss*,
   pulse*, sndio*, v4l2*, vfwcap, xcbgrab, xv`
   (<https://github.com/FFmpeg/FFmpeg/tree/master/libavdevice>).
3. FFmpeg master's `libavfilter/` contains no `vsrc_pipewiregrab.c`. The complete
   `vsrc_*` list is `amf, cellauto, ddagrab, gfxcapture*, gradients, life,
   mandelbrot, mptestsrc, perlin, sierpinski, testsrc, testsrc_vulkan`
   (<https://github.com/FFmpeg/FFmpeg/tree/master/libavfilter>). Correspondingly,
   `pipewiregrab` does not appear anywhere in <https://ffmpeg.org/ffmpeg-filters.html>.

A `pipewiregrab` filter has been circulated on ffmpeg-devel but **it is not
upstream**, and it is certainly not in the ffmpeg 6.1.6 installed here. Anything
claiming "ffmpeg has native PipeWire screen capture" is wrong.

So the portal route needs **GStreamer as a bridge**:
`gst-launch-1.0 pipewiresrc fd=$FD path=$NODE ! videoconvert ! <fdsink|v4l2sink>`
and then ffmpeg reads the pipe or the loopback device. `pipewiresrc` does have the
properties needed (`fd`, `path` (deprecated), `target-object`) —
<https://github.com/PipeWire/pipewire/blob/master/src/gst/gstpipewiresrc.c>:

> ```c
>   g_object_class_install_property (gobject_class, PROP_FD,
>       g_param_spec_int ("fd", "Fd", "The fd to connect with", -1, G_MAXINT, -1, ...));
>   g_object_class_install_property (gobject_class, PROP_TARGET_OBJECT,
>       g_param_spec_string ("target-object", "Target object", "The source name/serial to connect to (NULL = default)", ...));
> ```

Nothing in this repo installs GStreamer today (`gst-launch-1.0` is not on PATH).

### 5b. On Hyprland the portal is *built on* wlr-screencopy anyway

`xdg-desktop-portal-hyprland` ships `protocols/wlr-screencopy-unstable-v1.xml` and
its ScreenCast backend captures via screencopy, then republishes as a PipeWire
node (<https://github.com/hyprwm/xdg-desktop-portal-hyprland/blob/master/src/portals/Screencopy.cpp>):

> ```cpp
>     if (pSession->sharingData.frameInfoDMA.fmt == DRM_FORMAT_INVALID) {
>         Debug::log(ERR, "[screencopy] Couldn't obtain a format from dma");
>         return;
>     }
>     m_pPipewire->createStream(pSession);
> ```

The offered video format is a plain packed-RGB SPA format — from
`src/shared/ScreencopyShared.cpp`:

> ```cpp
>         case DRM_FORMAT_XRGB8888: return SPA_VIDEO_FORMAT_BGRx;
> ```

i.e. `BGRx` == ffmpeg's `bgr0`, **the same bytes wf-recorder would have handed you
directly**. The portal adds a D-Bus session dance, a PipeWire hop and a GStreamer
process to deliver an identical buffer. On Hyprland it buys nothing but
confinement-friendliness.

### 5c. Does it prompt on every run? No — *if* a token is kept, and *if* the user ticks the box

The spec (<https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html>)
defines, since interface version 4:

> `persist_mode` — "How this session should persist. Default is 0. Accepted values are: 0: Do not persist (default), 1: Permissions persist as long as the application is running, 2: Permissions persist until explicitly revoked"

> `restore_token` — "The token to restore a previous session. If the stored session cannot be restored, this value is ignored and the user will be prompted normally."

> "The restore token is **invalidated after using it once**. To restore the same session again, use the new restore token sent in response to starting this session."

XDPH implements this. In `onSelectSources` it parses `restore_data` and
`persist_mode`, and then:

> ```cpp
>     const bool RESTOREDATAVALID = restoreData.exists &&
>     (
>         (!restoreData.output.empty() && g_pPortalManager->getOutputFromName(restoreData.output)) ||
>         (!restoreData.windowClass.empty() && g_pPortalManager->m_sHelpers.toplevel->handleFromClass(restoreData.windowClass))
>     );
>
>     SSelectionData SHAREDATA;
>     if (RESTOREDATAVALID) {
>         Debug::log(LOG, "[screencopy] restore data valid, not prompting");
>         ...
>         SHAREDATA.allowToken   = true; // user allowed token before
>     } else {
>         Debug::log(LOG, "[screencopy] restore data invalid / missing, prompting");
>         SHAREDATA = promptForScreencopySelection();
>     }
> ```

and in `onStart`:

> ```cpp
>     if (PSESSION->selection.allowToken) {
>         options["restore_data"] = sdbus::Variant{getFullRestoreStruct(PSESSION->selection, PSESSION->cursorMode)};
>         options["persist_mode"] = sdbus::Variant{uint32_t{2}};
>     }
> ```

`allowToken` comes from a checkbox in the picker. `hyprland-share-picker/main.cpp`:

> ```cpp
>     bool allowTokenByDefault = false;
>     ...
>         if (argv[i] == std::string{"--allow-token"}) allowTokenByDefault = true;
>     const auto ALLOWTOKENBUTTON = w.findChild<QCheckBox*>("checkBox");
>     if (allowTokenByDefault) ALLOWTOKENBUTTON->setCheckState(Qt::CheckState::Checked);
> ```

and `--allow-token` is passed only when the XDPH config says so
(`src/shared/ScreencopyShared.cpp`):

> ```cpp
>     static auto* const* PALLOWTOKENBYDEFAULT = ... getConfigValuePtr("screencopy:allow_token_by_default") ...
>     if (**PALLOWTOKENBYDEFAULT) args.emplace_back("--allow-token");
> ```

The defaults are declared in `src/core/PortalManager.cpp`:

> ```cpp
>     m_sConfig.config->addConfigValue("screencopy:max_fps", Hyprlang::INT{120L});
>     m_sConfig.config->addConfigValue("screencopy:allow_token_by_default", Hyprlang::INT{0L});
>     m_sConfig.config->addConfigValue("screencopy:custom_picker_binary", Hyprlang::STRING{""});
>     m_sConfig.config->addConfigValue("screencopy:force_shm", Hyprlang::INT{0L});
>     m_sConfig.config->addConfigValue("screencopy:cursor_mode", Hyprlang::INT{0L});
> ```

**Net answer to the ticket's question:** the portal does *not* have to prompt every
run, but making it not prompt requires (a) the client to persist the returned
`restore_token` to disk, (b) re-send it, (c) request `persist_mode = 2`, and (d) the
user to have ticked "allow token" once (or `screencopy:allow_token_by_default = 1`
to be set). The token is **single-use**, so the `record` script would have to
rewrite its saved token after every take. That is real state to maintain in a
script whose whole selling point is being stateless. Also note **`screencopy:max_fps`
defaults to 120**, which silently caps a 144 Hz monitor:

> ```cpp
>             if (**PFPS <= 0) PSESSION->sharingData.framerate = POUTPUT->refreshRate;
>             else PSESSION->sharingData.framerate = std::clamp(POUTPUT->refreshRate, 1.F, (float)**PFPS);
> ```

---

## 6. Route D — ffmpeg `kmsgrab`: not usable

<https://ffmpeg.org/ffmpeg-devices.html> §`kmsgrab`:

> KMS video input device. Captures the KMS scanout framebuffer associated with a specified CRTC or plane as a DRM object that can be passed to other hardware functions.
> **Requires either DRM master or CAP_SYS_ADMIN to run.**

Hyprland holds DRM master for the session, so a second DRM-master client cannot
exist; the alternative is running ffmpeg as root or with `CAP_SYS_ADMIN`, which is
out of the question for a user `record` command. The documented follow-on filter
chain is also VAAPI-shaped:

> `ffmpeg -crtc_id 42 -framerate 60 -f kmsgrab -i - -vf 'hwmap=derive_device=vaapi,scale_vaapi=...' -c:v h264_vaapi output.mp4`

which brings back the VAAPI-encode problem of §4. Dead end twice over.

---

## 7. Intermediaries: what actually works

### stdout / `pipe:1` — **works, and is the cheapest**

Confirmed by code (`avio_open` in §3) and by the ffmpeg pipe protocol docs.
wf-recorder does not stat `pipe:1`, so no prompt.

### Named FIFO — works, but needs `-y`

Same AVIO machinery. The only difference is `user_specified_overwrite` stats the
FIFO successfully and `S_ISFIFO != S_ISCHR`, so it prompts. Add `-y`. A FIFO buys
nothing over `pipe:1` here — it only matters if the two processes are started
independently.

### v4l2loopback — works, but it is the wrong tool for this job

wf-recorder documents it (`--muxer=v4l2 --codec=rawvideo --file=/dev/video2`), and
the device is a character device so no prompt fires. v4l2loopback's defaults are
adequate for 3440x1440 — from
<https://github.com/umlaeute/v4l2loopback/blob/main/v4l2loopback.c>:

> ```c
> #define V4L2LOOPBACK_SIZE_DEFAULT_MAX_WIDTH 8192
> #define V4L2LOOPBACK_SIZE_DEFAULT_MAX_HEIGHT 8192
> #define V4L2LOOPBACK_DEFAULT_MAX_BUFFERS 2
> ```

But against it, concretely:

- It needs `sudo modprobe` (ticket 08 already tracks this).
- **/dev/video\* is already contested** — `camera-connect` in `scripts.nix` claims the
  first loopback node for the Canon R5. Adding a second producer means pinning
  `video_nr=` for both and keeping them straight.
- `max_buffers = 2` means the consumer must keep up or frames are dropped silently.
- It is an extra kernel-side copy of 19.81 MB/frame for zero gain over a pipe.

Use it only if you also want the screen visible to *other* apps (Zoom-style). For a
single ffmpeg pipeline it is strictly worse than `pipe:1`.

### Combination matrix

| Producer | Intermediary | Filterable ffmpeg input? | Notes |
|---|---|---|---|
| wf-recorder | `pipe:1` | ✅ | `-c rawvideo -m rawvideo -x bgr0`; no prompt |
| wf-recorder | named FIFO | ✅ | needs `-y` or it blocks on a stdin prompt |
| wf-recorder | v4l2loopback | ✅ | needs root modprobe; node collides with the camera |
| wf-recorder | (none, own file) | ❌ | encodes and muxes itself; no overlay possible |
| wl-screenrec | any | ❌ | never starts: VAAPI encode absent on NVIDIA |
| portal+PipeWire | GStreamer → pipe/v4l2 | ✅ | needs GStreamer + a D-Bus dance + token state |
| portal+PipeWire | ffmpeg direct | ❌ | ffmpeg has no PipeWire demuxer or filter |
| kmsgrab | — | ✅ in theory | needs DRM master / root; Hyprland already holds it |

---

## 8. NVENC: can frames stay on the GPU end to end? No — and it does not matter much.

### The zero-copy path does not exist in ffmpeg

To go capture→encode without touching system memory you would need to import the
compositor's DMA-BUF into a CUDA frames context. ffmpeg's CUDA hwcontext can only
be *derived* from one other device type —
<https://github.com/FFmpeg/FFmpeg/blob/master/libavutil/hwcontext_cuda.c>:

> ```c
>     switch (src_ctx->type) {
> #if CONFIG_VULKAN
>     case AV_HWDEVICE_TYPE_VULKAN: { ... src_uuid = vk_idp.deviceUUID; break; }
> #endif
>     default:
>         ret = AVERROR(ENOSYS);
>         goto error;
>     }
> ```

**There is no DRM→CUDA and no VAAPI→CUDA derive path.** The only hardware bridge
into CUDA is Vulkan, and reaching Vulkan requires `kmsgrab` (root, §6) or a custom
capture client — not something `wf-recorder | ffmpeg` can do.

So on this machine **every frame round-trips through system memory**, once. That is
the honest answer.

### What that costs at 3440x1440

3440 × 1440 = 4,953,600 px.

| Format | Bytes/frame | @30 | @60 | @120 | @144 |
|---|---|---|---|---|---|
| `bgr0` (32 bpp) | 19.81 MB | 0.59 GB/s | **1.19 GB/s** | 2.38 GB/s | 2.85 GB/s |
| `nv12` (12 bpp) | 7.43 MB | 0.22 GB/s | 0.45 GB/s | 0.89 GB/s | 1.07 GB/s |

At the target of 60 fps that is **1.19 GB/s** across the pipe and **1.19 GB/s back
up over PCIe** to the GPU. A GTX 1060 sits on PCIe 3.0 x16 (~15.75 GB/s
theoretical), so the upload is under 10 % of the link. The pipe itself is a
memcpy-per-hop; the kernel default pipe capacity is 64 KiB (this box allows up to
`/proc/sys/fs/pipe-max-size` = 1048576), so a 19.81 MB frame streams through in
chunks and the reader applies natural backpressure. 1.2 GB/s through a single pipe
is comfortably within range for modern memory bandwidth; give ffmpeg a large
`-thread_queue_size` so a momentary encoder stall does not stall the capture loop.

### Where the GPU *does* get used

Once the frame is uploaded, everything after it stays on the GPU. Verified against
FFmpeg master source:

- `hwupload_cuda` accepts `bgr0` and `yuva420p` directly —
  <https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_hwupload_cuda.c>:
  > ```c
  >     static const enum AVPixelFormat input_pix_fmts[] = {
  >         AV_PIX_FMT_NV12, AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUVA420P, ...
  >         AV_PIX_FMT_0RGB32, AV_PIX_FMT_0BGR32, AV_PIX_FMT_RGB32, AV_PIX_FMT_BGR32, ...
  > ```
- `scale_cuda` does RGB→YUV **on the GPU** —
  <https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_scale_cuda.c>:
  > ```c
  >     {AV_PIX_FMT_YUV420P,  "planar8"},
  >     {AV_PIX_FMT_NV12,     "semiplanar8"},
  >     {AV_PIX_FMT_0RGB32,   "bgr0"},
  > ```
  So `hwupload_cuda,scale_cuda=format=yuv420p` replaces what would otherwise be a
  multi-core swscale job.
- `overlay_cuda` can alpha-blend, but only in one specific combination —
  <https://ffmpeg.org/ffmpeg-filters.html> §`overlay_cuda`:
  > "This is the CUDA variant of the overlay filter. It only accepts CUDA frames. The underlying input pixel formats have to match."

  and <https://github.com/FFmpeg/FFmpeg/blob/master/libavfilter/vf_overlay_cuda.c>:
  > ```c
  > static const enum AVPixelFormat supported_main_formats[]    = { AV_PIX_FMT_NV12, AV_PIX_FMT_YUV420P, AV_PIX_FMT_NONE };
  > static const enum AVPixelFormat supported_overlay_formats[] = { AV_PIX_FMT_NV12, AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUVA420P, AV_PIX_FMT_NONE };
  > ```
  > ```c
  >     case AV_PIX_FMT_YUV420P:
  >         return format_overlay == AV_PIX_FMT_YUV420P || format_overlay == AV_PIX_FMT_YUVA420P;
  > ```

  **The circle overlay therefore requires: main = `yuv420p` (not `nv12`), overlay =
  `yuva420p`.** `nv12` main only accepts `nv12` overlay, which has no alpha. This is
  a hard constraint on ticket 04's filter graph.
- `h264_nvenc` / `hevc_nvenc` accept CUDA frames —
  <https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/nvenc.c>:
  > ```c
  > const enum AVPixelFormat ff_nvenc_pix_fmts[] = {
  >     AV_PIX_FMT_YUV420P, AV_PIX_FMT_NV12, ... AV_PIX_FMT_0RGB32, AV_PIX_FMT_RGB32, AV_PIX_FMT_0BGR32, AV_PIX_FMT_BGR32, ...
  >     AV_PIX_FMT_CUDA, ...
  > ```
  > ```c
  > const AVCodecHWConfigInternal *const ff_nvenc_hw_configs[] = {
  >     HW_CONFIG_ENCODER_FRAMES(CUDA,  CUDA),
  > ```

So the graph `[pipe bgr0] → hwupload_cuda → scale_cuda=format=yuv420p →
overlay_cuda → h264_nvenc` uploads **once** and never comes back down.

Availability check: FFmpeg's `configure` gates these filters —
<https://github.com/FFmpeg/FFmpeg/blob/master/configure>:

> ```
> overlay_cuda_filter_deps="ffnvcodec"
> overlay_cuda_filter_deps_any="cuda_nvcc cuda_llvm"
> ```

and the installed build has `--enable-ffnvcodec --enable-cuda-llvm`, and
`ffmpeg -filters` lists all three. ✅ Nothing to add to the package set.

(In nixpkgs terms this is not luck: `pkgs.ffmpeg` sets
`withNvenc ? withHeadlessDeps && withNvcodec` and `withCudaLLVM ? withHeadlessDeps`,
and the default `small` variant implies `withHeadlessDeps`. —
<https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/libraries/ffmpeg/generic.nix>)

---

## 9. Sustainable frame rate at 3440x1440

Three ceilings, in order of how soon you hit them.

**(a) The protocol is a serial request/reply.** `wlr-screencopy-unstable-v1`
(<https://github.com/hyprwm/Hyprland/blob/main/protocols/wlr-screencopy-unstable-v1.xml>)
describes one frame per frame-object:

> "This object represents a single frame. When created, a series of buffer events will be sent… The client will then be able to send a 'copy' request. If the capture is successful, the compositor will send a 'flags' followed by a 'ready' event… Once either a 'ready' or a 'failed' event is received, the client should destroy the frame."

wf-recorder's main loop honours that literally
(<https://github.com/ammen99/wf-recorder/blob/master/src/main.cpp>):

> ```c
>     while(!exit_main_loop)
>     {
>         while(buffers.capture().ready_capture() != true) { std::this_thread::sleep_for(std::chrono::microseconds(500)); }
>         buffer_copy_done = false;
>         request_next_frame();
>         while (!buffer_copy_done && !exit_main_loop && wl_display_dispatch(display) != -1) { }
> ```

One outstanding capture at a time, blocking on the compositor round trip. There is
no pipelining, so capture rate ≤ 1 / (render + copy + two IPC round trips).

**(b) The compositor's render cycle.** Hyprland fulfils a non-damage copy by
dirtying the monitor and waiting for the next paint (`damageMonitor` in
`Screencopy.cpp`, §2). So the hard ceiling is the monitor's **144 Hz**, and you
only ever get frames when Hyprland paints.

**(c) Readback + pipe bandwidth.** §8's table. At 144 fps in `bgr0` that is 2.85
GB/s of GPU→CPU readback *plus* 2.85 GB/s through the pipe *plus* 2.85 GB/s back
over PCIe — all while the compositor is also trying to render. At 60 fps it is
1.19 GB/s on each leg, which is a different proposition entirely.

**What holds:** target **60 fps** and leave damage-based capture on (the default).
Damage-based capture means a static screen costs nothing, and wf-recorder's
`fps=60` filter duplicates to keep the output CFR. 120 fps is probably reachable
in bursts but doubles every number above and leaves no headroom for the camera
decode, two audio captures and NVENC that share this box. 144 fps is not a
sensible target for a talking-head screencast and YouTube will not thank you for it.

**The one thing to watch:** libavfilter's `fps` filter only emits when a new input
frame arrives. With damage-based capture and a completely static screen,
wf-recorder receives nothing, so the duplicated frames are emitted late in a burst
when the screen next changes rather than smoothly in real time. The frame *count*
stays correct, so a file stays in sync, but if you see drift, `-D/--no-damage`
forces a continuous stream —
<https://github.com/ammen99/wf-recorder/blob/master/manpage/wf-recorder.1>:

> `-D, --no-damage` — By default, wf-recorder will request a new frame from the compositor only when the screen updates… When this option is on, wf-recorder does not use this optimization and continuously records new frames, even if there are no updates on the screen.

The cost of `-D` is that Hyprland repaints and copies at the full 144 Hz even
though `fps=60` throws half of it away. **Prefer damage-based; keep `-D` in the back
pocket.** (This is worth a measurement during ticket 06.)

Also note `scale = 1.25` is not a problem for a whole-output capture:
`capture_output` returns the output's buffer, i.e. the **physical 3440x1440**, not
the 2752x1152 logical size. Only `-g/--geometry` regions are expressed in logical
coordinates ("The region is given in output logical coordinates, see
xdg_output.logical_size" — protocol XML). Capture the whole output and the scale
factor never enters the arithmetic.

---

## 10. Partial local validation

The ffmpeg half of the recommended pipeline was run on this machine, feeding a
synthetic 3440x1440 `bgr0` rawvideo stream through a pipe into an alpha circle
overlay:

```
ffmpeg -f lavfi -i "testsrc2=size=3440x1440:rate=60:duration=1" -pix_fmt bgr0 -f rawvideo pipe:1 \
| ffmpeg -thread_queue_size 64 -f rawvideo -pixel_format bgr0 -video_size 3440x1440 -framerate 60 -i pipe:0 \
    -f lavfi -i "testsrc=size=320x320:rate=60" \
    -filter_complex "[1:v]format=yuva420p,geq=...a=255*lt(...)[ov];[0:v][ov]overlay=x=40:y=40,format=yuv420p[v]" \
    -map "[v]" -c:v libx264 -preset ultrafast -t 1 -f null -
```

→ `frame=60`, clean exit. The rawvideo-over-pipe input contract and the
circle-alpha composite both work as described.

The CUDA/NVENC leg could **not** be executed from this agent's sandbox — it has no
`/dev/nvidia*` and no `libcuda.so.1` on the loader path, so `hwupload_cuda` failed
with `Cannot load libcuda.so.1`. That is a sandbox artefact, not a finding about the
machine. **Re-run the CUDA variant in a real session before committing to it**; the
source-level evidence in §8 says it should work, but that is inference, not a
measurement.

---

## 11. Loose ends worth knowing

- **`gpu-screen-recorder`** is listed on Hyprland's own recording page
  (<https://github.com/hyprwm/hyprland-wiki/blob/main/content/useful-utilities/screenshots-and-recording.md>)
  and is the only tool in that list built around NVIDIA specifically. It is a
  self-contained recorder (writes its own file), so it does not satisfy the
  "filterable ffmpeg input" requirement any better than wf-recorder does, and it
  would replace the pipeline rather than feed it. Not pursued.
- **`av1_nvenc` is a trap on this box** — the encoder exists in ffmpeg but the
  GTX 1060 cannot do AV1 (§1). Use `h264_nvenc`; `hevc_nvenc` is available (and 10-bit
  capable) if the container/consumer allows it, but YouTube plus LosslessCut plus
  "no re-encode on trim" argues for H.264 in MP4.
- **NVENC session count is not a constraint** — 12 concurrent sessions on this card
  (§1), and the pipeline needs one.
- **`hevc_nvenc` B-frames are not available** on Pascal (matrix row: HEVC B Frame
  support = NO). Do not set `-bf` on the HEVC path.

---

## Recommendation

**Use `wf-recorder` as a raw BGR0 frame pump into `ffmpeg` over stdout.**

It is the only one of the three routes that (a) runs at all on the NVIDIA
proprietary driver under Hyprland, (b) can be an ffmpeg *input* rather than a
self-contained recorder, (c) needs no root, no kernel module, no extra daemon and
no persisted permission token, and (d) hands over the compositor's bytes with zero
CPU conversion, leaving the RGB→YUV to `scale_cuda` on the GPU.

`wl-screenrec` cannot start (no VAAPI encode on NVIDIA). The portal/PipeWire route
requires a GStreamer bridge ffmpeg does not have natively, plus single-use token
bookkeeping, to deliver the identical `BGRx` buffer that wf-recorder gives up for
free. `kmsgrab` needs DRM master. v4l2loopback is a strictly more expensive pipe
whose device node is already contested by the camera.

### The exact ffmpeg input invocation this implies

```sh
wf-recorder \
    --output DP-1 \
    --framerate 60 \
    --codec rawvideo \
    --muxer rawvideo \
    --pixel-format bgr0 \
    --file pipe:1 \
  | ffmpeg \
      -thread_queue_size 512 \
      -f rawvideo -pixel_format bgr0 -video_size 3440x1440 -framerate 60 \
      -i pipe:0 \
      ...
```

That first `-i` is the screen. It is input `0`, it is `bgr0`, it is CFR at exactly
60 fps, and it is filterable — the rest of the graph attaches to `[0:v]`.

Substitute the real output name for `DP-1` (`wf-recorder -L` lists them). Drop
`--output` entirely only if there is exactly one monitor connected at the time.

For the GPU-side continuation (ticket 04 / 07 own this, but the constraints are
fixed by §8): main must be `yuv420p` and the overlay must be `yuva420p` for
`overlay_cuda` to alpha-blend —

```sh
      -filter_complex "\
        [0:v]hwupload_cuda,scale_cuda=format=yuv420p[main]; \
        [<cam>]<circle mask>,format=yuva420p,hwupload_cuda[ov]; \
        [main][ov]overlay_cuda=x=...:y=...[v]" \
      -map "[v]" -c:v h264_nvenc
```

**Verify before building on it:** run that CUDA leg once in a real session
(§10 could not), and confirm `wf-recorder --file pipe:1` does not trip the
overwrite prompt in practice. If a named pipe is ever used instead of `pipe:1`, add
`-y`.
