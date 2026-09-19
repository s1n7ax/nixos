# R5 over USB: what feed can we actually get?

Research for issue `.scratch/auto-record/issues/01-r5-usb-video-feed.md`.
Date: 2026-09-19. Every claim below is cited; where no primary source exists for
the R5 *specifically*, that is stated explicitly and a one-command verification
is given instead of a guess.

Current script under review — `system/home-manager/applications/scripts.nix:224`
(`camera-connect`), with `boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ]`
at `system/nixos/core/boot.nix:5`.

---

## 0. Answer in one paragraph

The R5 has **no native UVC webcam mode** — it was never added in any firmware
from 1.1.1 through 2.2.0, so Linux will never enumerate it as a `/dev/video*`.
The only USB video path is the **PTP live-view stream** that `gphoto2
--capture-movie` polls: a sequence of complete JPEG frames on stdout, no
container, no timestamps, around **1024×576 in movie mode** (≈0.6 MP, i.e. a
webcam-grade image, not 4K), at an unpaced ~10–25 fps. It is clean (no AF boxes,
no info overlay) because AF/overlay data travels as *separate* PTP properties
that libgphoto2 discards. There is **no clip-length cap** on this stream — the
29:59 limit applies only to recording onto the card — but the camera heats up and
will shut itself off, and while tethered it ignores its own power-saving menu.
For a circle-masked overlay on a 3440×1440 screen capture, 1024×576 is plenty,
and the `v4l2loopback` hop is pure overhead: pipe gphoto2 straight into the
compositing ffmpeg as a second input.

---

## 1. `gphoto2 --capture-movie`: what it actually is

### 1.1 It is the live-view stream, polled — not the recorded movie

`--capture-movie` is implemented in `action_camera_capture_movie()` in
[gphoto2/gphoto2/actions.c](https://github.com/gphoto/gphoto2/blob/master/gphoto2/actions.c).
The whole function is a `while (1)` loop around **`gp_camera_capture_preview()`**;
it opens `stdout` (with `--stdout`) via `gp_file_new_from_fd()` and lets each
preview call append straight to that fd. There is no muxer, no pacing, no sleep
and no timestamping anywhere in the loop:

```c
CR (gp_file_new_from_fd (&file, fd));
while (1) {
        r = gp_camera_capture_preview (p->camera, file, p->context);
        ...
        gp_file_get_mime_type (file, &mime);
        if (strcmp (mime, GP_MIME_JPEG)) {
                cli_error_print(_("Movie capture error... Unhandled MIME type '%s'."), mime);
                break;
        }
```

So the output is **concatenated baseline JPEGs** — an MJPEG *elementary stream*.
The default filename when `--stdout` is absent is literally `movie.mjpg`
([same file](https://github.com/gphoto/gphoto2/blob/master/gphoto2/actions.c)).

On the camera side, `camera_capture_preview()` in
[libgphoto2/camlibs/ptp2/library.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/library.c)
takes the Canon EOS branch and:

1. sets `PTP_DPC_CANON_EOS_EVFMode = 1` (live view on),
2. sets `PTP_DPC_CANON_EOS_EVFOutputDevice = 2` ("PC") if no output bit is set,
3. calls `camera_keep_device_on()` — commented *"Otherwise the camera will auto-shutdown"*,
4. loops on `ptp_canon_eos_get_viewfinder_image()`.

The reply is a chain of `uint32 len / uint32 type / data` blobs. libgphoto2 keeps
only the image blob and **discards every other blob**:

```c
case 9: case 1: case 11:
        gp_file_append ( file, (char*)xdata+8, len-8 );
        /* type 1 is JPEG (regular), type 9 is in movie mode */
        gp_file_set_mime_type (file, ((type == 1) || (type == 11)) ? GP_MIME_JPEG : GP_MIME_RAW);
```

The R5 is a supported body — `{"Canon:EOS R5", 0x04a9, 0x32f4, PTP_CAP|PTP_CAP_PREVIEW}`
in the camera table of
[library.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/library.c) —
added in libgphoto2 **2.5.26** ("Cameras added to id list: … Canon EOS 1D X Mark III,
R5, R6", [NEWS](https://github.com/gphoto/libgphoto2/blob/master/NEWS)).

> **Latent failure mode, straight from the source above:** blob `type == 9` is
> tagged `GP_MIME_RAW`, and `actions.c` *aborts the whole capture* on any MIME type
> that is not JPEG. The in-source comment says type 9 is "in movie mode". If
> `camera-connect` ever dies instantly with `Movie capture error... Unhandled MIME
> type`, this is why, and the fix is a camera mode change, not an ffmpeg flag.
> (Compare [libgphoto2#984](https://github.com/gphoto/libgphoto2/issues/984), where
> the R5 C hard-locks on `--set-config viewfinder=1` in video mode.)

### 1.2 Resolution

The resolution is **not** selectable as a width/height. It is a side effect of the
Canon `EVFOutputDevice` property, exposed by libgphoto2 as the `output` config.
The value is a bitmask — `1 = TFT, 2 = PC, 4 = MOBILE, 8 = MOBILE2` — see
`canon_eos_cameraoutput[]` in
[camlibs/ptp2/config.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/config.c);
the same file maps those bits onto `Large` / `Medium` / `Small` in
`_get_Canon_LiveViewSize()`. Bigger bit = smaller image. **`PC` (2) is the large one.**

Measured sizes reported by the libgphoto2 maintainer and users in
[gphoto/libgphoto2#567](https://github.com/gphoto/libgphoto2/issues/567):

| Body | Live-view JPEG size | Note |
|---|---|---|
| EOS 100D, 1000D | 960×640 | only size offered |
| EOS 750D | 960×640 / 480×320 / 192×128 | PC / MOBILE / MOBILE2 |
| EOS 500D | 928×616 | `--capture-preview` and `--capture-movie` |
| EOS M50 | 1024×576 (movie mode), 960×640 (stills) | with `viewfinder=1` |
| **EOS RP** | **1024×576** with `output ∈ {0,1,2,3}`; 512×288 with `{4,5,8,9}` | in movie mode |
| EOS 1200D | 1056×704 | [taylorsay/eos-webcam-linux](https://github.com/taylorsay/eos-webcam-linux) |

The same issue records that `PC + MOBILE` combinations **alternate frame sizes
between the two**, and that on an EOS RP those combinations "cause the camera to
display an error that requires pulling the battery to reset" — so `PC` or
`TFT + PC` only.

> **Honest gap:** I found **no primary report of the R5's own live-view dimensions.**
> The RP is the closest documented body on the same EOS-R PTP generation, so
> **expect 1024×576 in movie mode and ~960×640 in stills mode**, but treat that as
> an inference, not a fact. Verify in one command before designing around a number:
>
> ```sh
> gphoto2 --set-config viewfinder=1 --capture-preview && file capture_preview.jpg
> gphoto2 --get-config output      # shows which sizes this body offers
> ```
>
> Note from [#567](https://github.com/gphoto/libgphoto2/issues/567): the **first few
> frames of a `--capture-movie` run can be a smaller size than the rest**, and
> "ffmpeg uses the resolution of the first jpg" — so the stream can lock to the
> wrong geometry. That is a real hazard for the current one-shot script.

Either way this is a **~0.5–0.6 megapixel** source. It is not 4K, not 1080p, and
nothing on the USB path can make it so.

### 1.3 Frame rate

There is no frame-rate setting and no pacing. The loop in `actions.c` (§1.1) runs
as fast as the PTP round trip allows, so fps is an emergent property of the body
and the link. Evidence for the achievable band:

- libgphoto2 `NEWS` records the EOS viewfinder path being fixed from
  "2 images/s -> 20 i/s" — so ~20/s is the code path's demonstrated ceiling
  ([NEWS](https://github.com/gphoto/libgphoto2/blob/master/NEWS)).
- [taylorsay/eos-webcam-linux](https://github.com/taylorsay/eos-webcam-linux)
  measures "~9fps over USB/PTP on most Canon EOS bodies" (confirmed on a 1200D).

The R5's digital terminal is "SuperSpeed Plus USB (USB 3.1 Gen 2) equivalent"
([Canon, EOS R5 Specifications](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0100.html)),
so it should sit at the upper end rather than at 9 fps — but **this must be
measured, not assumed.** Measure with:

```sh
gphoto2 --stdout --set-config viewfinder=1 --capture-movie 10s > /tmp/r5.mjpg
# gphoto2 prints "Movie capture finished (N frames)" -> N/10 = real fps
```

### 1.4 Pixel format / codec on stdout

Baseline JPEG, 8-bit, 3 components, YCbCr — i.e. ffmpeg decodes it as `mjpeg` /
`yuvj420p`. **Not raw.** There is no container and, critically, **no timestamps**.

---

## 2. `-vcodec copy` into v4l2loopback: viable, but wrong for this pipeline

### 2.1 Mechanically it works

ffmpeg's v4l2 *output* device does accept MJPEG passthrough:

- `libavdevice/v4l2-common.c` maps `AV_CODEC_ID_MJPEG → V4L2_PIX_FMT_MJPEG`
  ([source](https://github.com/FFmpeg/FFmpeg/blob/master/libavdevice/v4l2-common.c)).
- `libavdevice/v4l2enc.c` `write_header()` takes the non-rawvideo path
  (`ff_fmt_ff2v4l(AV_PIX_FMT_NONE, par->codec_id)`) and then just `write()`s each
  packet unchanged in `write_packet()`
  ([source](https://github.com/FFmpeg/FFmpeg/blob/master/libavdevice/v4l2enc.c);
  identical in [n6.1](https://github.com/FFmpeg/FFmpeg/blob/n6.1/libavdevice/v4l2enc.c),
  which is the `ffmpeg 6.1.6` on this machine).
- v4l2loopback negotiates whatever format the producer sets, and advertises
  per-device caps via sysfs
  ([README](https://github.com/umlaeute/v4l2loopback/blob/main/README.md)).

The `"V4L2 output device supports only a single raw video stream"` error in
`v4l2enc.c` is a check on *stream count and media type*, not on codec — it does
not block MJPEG.

### 2.2 But the timing is fabricated

ffmpeg probes the stdin stream with `mjpeg_probe()` and uses the **raw video
demuxer**, whose only frame-rate knob is an AVOption defaulting to a hard-coded
`"25"`:

```c
static const AVOption rawvideo_options[] = {
    { "framerate", "", OFFSET(framerate), AV_OPT_TYPE_VIDEO_RATE, {.str = "25"}, 0, INT_MAX, DEC},
```

— [libavformat/rawdec.c](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/rawdec.c)
(same in [n6.1](https://github.com/FFmpeg/FFmpeg/blob/n6.1/libavformat/rawdec.c)),
and the demuxer is declared `AVFMT_NOTIMESTAMPS`
([rawdec.h](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/rawdec.h)).

So **ffmpeg believes the R5 delivers exactly 25 fps** no matter what it really
delivers. If the true rate is ~12 fps, everything downstream that trusts the
timestamps drifts. For a recording that must stay in sync with a screen capture
and two audio tracks, that is the single most important fact in this document.
Mitigation: `-f mjpeg -framerate <measured>` on the input, or `-use_wallclock_as_timestamps 1`,
or (best) let the compositing ffmpeg resample the camera input onto the screen
capture's clock.

### 2.3 And the hop is redundant here

The target pipeline masks the camera to a circle and overlays it — which means
ffmpeg decodes the JPEG regardless. The current shape is
`gphoto2 → ffmpeg → v4l2loopback → ffmpeg`: an extra copy, an extra process, an
extra kernel module, a `sudo`, and a second place for the resolution to be wrong.
Feeding gphoto2's stdout directly into the compositing ffmpeg as a second `-i`
removes all of it. Keep v4l2loopback **only** if something outside ffmpeg (a
browser, a preview app) must also see the camera.

### 2.4 Two concrete bugs in the current script

```sh
sudo modprobe v4l2loopback exclusive_caps=1 max_buffer=2
```

1. **`max_buffer` is not a parameter.** The module parameter is `max_buffers`
   (plural) — `module_param(max_buffers, int, S_IRUGO)` in
   [v4l2loopback.c](https://github.com/umlaeute/v4l2loopback/blob/main/v4l2loopback.c).
   Confirmed on this machine: `modinfo v4l2loopback` (v0.15.3) lists
   `max_buffers:how many buffers should be allocated [DEFAULT: 2]`. `modprobe`
   rejects unknown parameters, so this line fails — and because the script runs
   `set -euo pipefail`, it dies before gphoto2 ever starts. Also note the default
   is already 2, so the parameter is redundant even when spelled correctly.

2. **`"/dev/$(ls -1 /sys/devices/virtual/video4linux)"`** expands to *all* virtual
   V4L2 nodes. With one loopback that is fine; with two (or with anything else
   virtual present) it silently produces a broken path. Pin it with
   `video_nr=` on the modprobe line instead
   ([README](https://github.com/umlaeute/v4l2loopback/blob/main/README.md)).

---

## 3. Is the feed clean?

**Yes — the PTP live-view JPEG carries no AF boxes and no info overlay**, for a
structural reason: Canon sends focus/AF-frame state as *separate* PTP device
properties, not painted into the image.

- `PTP_DPC_CANON_EOS_FocusInfoEx` (0xD1d3) and `PTP_DPC_CANON_EOS_PropFinderAFFrame`
  (0xD214) are distinct properties in
  [camlibs/ptp2/ptp.h](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/ptp.h),
  and libgphoto2 surfaces the first as a read-only string config named `focusinfo`
  ([config.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/config.c)).
- The viewfinder reply is a *chain* of typed blobs and libgphoto2 appends **only**
  the image blob to the file, skipping the rest (`default: xdata = xdata+len; continue;`
  in [library.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/library.c)).
  Desktop tethering apps draw the AF rectangle themselves from those properties.

The camera-side menu that people reach for — **`[Shooting info. disp.]`** with its
`Screen info. settings` / `VF info/toggle settings` / `Grid display` / `Histogram`
options — governs **the camera's own screen and viewfinder only**
([Canon, EOS R5: Shooting Information Display](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-1_0370.html)).
It is the setting that matters for the **HDMI** route (§5), not for USB.

Two things *are* baked into the live-view image and are worth knowing, both from
[Canon, EOS R5: General Movie Recording Precautions](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0160.html):
"Movies are recorded almost exactly as they appear on the screen" — i.e. Picture
Style, Exposure Simulation and Canon Log View Assist all affect what you get. If
Canon Log is on, expect a flat image over USB too.

*Not established:* whether **Zebras** (`[Zebra settings]`) appear in the PTP
stream. I found no primary source either way. Leave zebras off, or check once.

---

## 4. Hard limits

### 4.1 Clip length — the 29:59 cap does **not** apply

Canon's limit is on **recording to the card**: "The maximum recording time per
movie is 29 min. 59 sec. Once 29 min. 59 sec. is reached, recording automatically
stops" (7 min 29 sec for High Frame Rate)
([Canon, EOS R5: Movie Recording Quality → Movie Recording Time Limit](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0040.html)).
The USB live-view stream is not a recording and is not subject to it. There is no
counter, timer or frame budget anywhere in the `--capture-movie` loop
([actions.c](https://github.com/gphoto/gphoto2/blob/master/gphoto2/actions.c)) —
without `-frames`/`-seconds` it is `MOVIE_ENDLESS`.

A **30-minute cap does exist on the HDMI path**, and it is really the auto-power-off
timer: "To continue HDMI output for longer than 30 min., select [Camera+External
monitor], then set [Auto power off] in [Power saving] to [Disable]"
([Canon, EOS R5: Other Menu Functions](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0150.html)).

### 4.2 Overheating — this is the real limit, and live view is what causes it

Canon is explicit that **live view display, not just recording, is a heat source**:

- "A red [thermometer] icon may be displayed if repeated movie recording **or
  extended use of Live View display** increases the camera's internal temperature…
  **The camera will turn off automatically** if you continue recording while a red
  icon is displayed. The camera may also turn off automatically if you continue
  using Live View display while a red icon is displayed."
  ([General Movie Recording Precautions](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0160.html))
- "The camera's internal temperature may rise and less recording time may be
  available after extended movie playback **or Live View display**."
  ([Movie Recording Quality](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0040.html))
- After an automatic shutdown "you will be unable to record movies or shoot still
  photos until the camera has cooled down."

Mitigations, all first-party:

- **`[Auto pwr off temp.] = High`** — "Set to [High] to reduce the frequency of the
  camera automatically turning off due to high card temperature"
  ([Other Menu Functions](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0150.html)).
  Added in **firmware 1.6.0**: "When [High] is selected, the camera will not
  automatically turn off when the temperature of the camera body and card become
  high… Note that the temperature of the bottom surface of the camera may increase"
  ([Canon, EOS R5 Firmware history](https://sg.canon/en/support/0401059502)).
- **`[Standby: Low res.] = On`** — "Set to [On] to conserve battery power and
  control the rise of camera temperature during standby. As a result, it may enable
  you to record movies over a longer period."
  ([Other Menu Functions](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0150.html)).
  Note it "may differ from image quality on the screen during movie recording" —
  for a small circular overlay that trade is free.
- **Take the card out / don't record to card.** The R5's heat budget is dominated
  by 8K/4K encoding, which we are not asking it to do: "8K/4K or High Frame Rate
  movie recording greatly increases the processing load, which may increase the
  internal camera temperature faster or higher than for regular movies"
  ([Movie Recording Quality](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0040.html)).
  Live view alone is a much lighter load, which is why long tethered sessions are
  usually fine where 8K recording is not — **but no Canon document states a
  live-view-only time limit, so this needs a real soak test before you trust it
  for a long take.**

### 4.3 Auto power off — gphoto2 already defeats it, and the menu stops working

libgphoto2 pings the body roughly every 10 s for exactly this reason:

```c
/* Otherwise the camera will auto-shutdown */
CR (camera_keep_device_on (camera));
```

and `camera_keep_device_on()` issues `PTP_OC_CANON_EOS_KeepDeviceOn` at most once
per 10 s, with the maintainer's note that "the EOS R8 has an Auto Power Off timer
that can be set to 15s minimum but it does not power off for at least several
minutes while still connected to USB, even without any traffic"
([library.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/library.c),
[config.c](https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/config.c)).

The flip side, reported for **this exact body** in
[gphoto/libgphoto2#1171](https://github.com/gphoto/libgphoto2/issues/1171):

> "the power consumption of the R5 while connected to gphoto2, sitting there doing
> nothing, is almost 10W… the camera continuously operates the viewfinder/display,
> meaning it is reading out the sensor at 30 or 60 fps… **the power saving options
> accessible via the camera menu seem completely disabled while tethered with
> gphoto2.**"

and, from the follow-up, closing the screen does not help — the EVF then runs
instead and draws *more*. So: expect ~10 W continuous, the camera's own
`[Power saving]` / `[Eco mode]` settings
([Power Saving](https://cam.start.canon/en/C003/manual/html/UG-07_Set-up_0160.html),
[Eco Mode](https://cam.start.canon/en/C003/manual/html/UG-07_Set-up_0170.html))
to be ignored while the session is up, and the stream not to die on a timer.

### 4.4 Power: USB-C does **not** power the R5 on its own

This trips people up. The R5's USB-C port can charge/power **only via Canon's USB
Power Adapter PD-E1**, and "**The camera cannot be powered unless a battery pack is
in it**"
([Canon, EOS R5: Using a USB Power Adapter to Charge/Power the Camera](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0030.html)).
The specifications list the digital terminal's applications as "For computer
communication / For in-camera charging / powering the camera with USB Power Adapter
PD-E1"
([Specifications](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0100.html)).
A generic USB-C PD charger is not guaranteed; firmware 1.3.1 even had to fix "a
phenomenon in which the power may become suspended when the camera is powered via
USB for an extended period of time"
([firmware history](https://sg.canon/en/support/0401059502)).

**The reliable option is mains: AC Adapter AC-E6N + DC Coupler DR-E6**, both listed
under Power source in the
[Specifications](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0100.html).
That is the dummy-battery route, and it removes the battery as a limit entirely.

For reference, battery-only endurance with an LP-E6NH is "Time available for Live
View shooting … Approx. 3 hr. 50 min." at 23 °C
([Specifications](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0100.html)).
**Mains power does not change the thermal limit — only the battery limit.**

---

## 5. Native UVC: the R5 does not have it

### 5.1 What "having it" looks like on Canon bodies that do

Canon ships UVC/UAC as a *documented menu item* with its own manual page:

- **EOS R50 V**: a page titled "USB (UVC/UAC) Streaming" — "Select [Network:
  USB (UVC/UAC) streaming]… Select this option if you will use UVC/UAC-compatible
  applications over a USB connection"
  ([Canon, EOS R50 V manual](https://cam.start.canon/en/C021/manual/html/UG-07_Network_0260.html)).
- **EOS R6 Mark III**: same page title
  ([Canon, EOS R6 Mark III manual](https://cam.start.canon/en/C022/manual/html/UG-07_Network_0090.html)).
- **EOS R5 Mark II**: "App Selection for USB Connections", offering *Photo
  Import/Remote Control*, *Video calls/streaming* (UVC/UAC), and *Canon app(s) for
  iPhone* — with the stream spec stated outright: "**The resolution and frame rate
  of image output is 2K (1920×1080) at 30 fps**", audio LPCM/16bit/2CH
  ([Canon, EOS R5 Mark II manual](https://cam.start.canon/en/C017/manual/html/UG-06_Network_0300.html)).

### 5.2 The R5 has none of that

- Its manual's **complete table of contents contains no UVC, no UAC and no
  streaming page** — the Network chapter is Wi-Fi/Bluetooth/FTP only, and the
  Set-up chapter has no USB-mode item
  ([Canon, EOS R5 Advanced User Guide contents](https://cam.start.canon/en/C003/manual/html/index.html)).
  Note Canon updates this guide with each firmware ("Users manual in the WEB is
  updated accordingly", [firmware page](https://sg.canon/en/support/0401059502)), so
  its absence is current, not stale.
- The **Specifications** list the digital terminal's applications as computer
  communication, in-camera charging and PD-E1 power — no streaming mode
  ([Specifications](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0100.html)).
- Its **Software** page lists only EOS Utility, Digital Photo Professional and
  Picture Style Editor
  ([Software](https://cam.start.canon/en/C003/manual/html/UG-00_Before_0100.html)).
- **The entire published firmware history — 1.1.1, 1.2.0, 1.3.1, 1.4.0, 1.5.0,
  1.5.1, 1.5.2, 1.6.0, 1.7.0, 1.8.1, 1.9.0, 2.0.0, 2.1.0, 2.2.0 — never mentions
  UVC, UAC or streaming.** The USB-related entries are EDSDK/CCAPI support (1.9.0,
  2.2.0), a USB-power fix (1.3.1) and servo-zoom remote control (2.0.0). Full text:
  [Canon, EOS R5 Firmware Update Version 2.2.0 incl. history](https://sg.canon/en/support/0401059502)
  and [Version 1.9.0 incl. history](https://asia.canon/en/support/0400881602).

Canon's answer for the R5 is the host-side **EOS Webcam Utility**, which is a
Windows/macOS driver — "Supported OS: Windows 10 (64-bit & 32-bit), Windows 11
(64-bit)" for the Windows build, with a separate macOS build and **no Linux build
at all** ([Canon, EOS Webcam Utility](https://my.canon/en/support/0200625404)).
It talks the same vendor PTP the camera already speaks; there is nothing for
`uvcvideo` to bind to.

### 5.3 If it *did* have it, Linux would just work

This is worth stating because it means no kernel work would ever be the blocker.
`uvcvideo` matches by **interface class**, not by vendor/product:

```c
/* Generic USB Video Class */
{ USB_INTERFACE_INFO(USB_CLASS_VIDEO, 1, UVC_PC_PROTOCOL_UNDEFINED) },
{ USB_INTERFACE_INFO(USB_CLASS_VIDEO, 1, UVC_PC_PROTOCOL_15) },
```

— the tail of `uvc_ids[]` in
[drivers/media/usb/uvc/uvc_driver.c](https://github.com/torvalds/linux/blob/master/drivers/media/usb/uvc/uvc_driver.c).
There is **no Canon vendor id (0x04a9) anywhere in that quirk table**, and none is
needed: a standards-compliant UVC interface binds generically. So on an R5 Mark II
or an R50 V this is a plain `/dev/video*` with no gphoto2, no v4l2loopback and no
sudo — it simply is not an option on the R5.

---

## 6. The third route: HDMI + capture card

For completeness, since it is the only way to get more than ~0.6 MP off this body.

- Terminal: "HDMI micro OUT terminal (Type D)", "HDMI output of 8K movies not
  supported"
  ([Specifications](https://cam.start.canon/en/C003/manual/html/UG-09_Reference_0100.html)).
  Movie-mode "Movie output itself corresponds to the [Movie rec. size] setting"
  ([Other Menu Functions](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0150.html)).
- **Clean output is a documented setting.** `[HDMI display]` has a mode that
  "Deactivates the camera screen during output via HDMI"; and "Shooting
  information, AF points, and other information is shown on the external device via
  HDMI, but **you can stop output of this information by pressing the INFO button**…
  Before recording movies externally, confirm that no information is being sent by
  the camera"
  ([same page](https://cam.start.canon/en/C003/manual/html/UG-03_Shooting-2_0150.html)).
  Caveat from Canon: clean output "prevents display of warnings about the card
  space, battery level, or high internal temperature".
- 30-minute cap unless `[Auto power off] = Disable` (§4.1).
- Cost: a UVC capture dongle (which `uvcvideo` binds generically, §5.3), a micro-HDMI
  cable, and the same thermal ceiling.

---

## 7. What this means for the circle overlay

The overlay is a small circle on a 3440×1440 canvas. A sensible circle diameter is
~400–500 px. A 1024×576 source center-cropped to 576×576 and scaled to 450×450 is
a **downscale** — the PTP live view is already more resolution than the overlay
consumes. Chasing HDMI capture for this pipeline buys nothing visible and adds
hardware, a 30-minute timer and another device to enumerate.

What *does* matter, in order:

1. **Measured fps**, because ffmpeg will otherwise assert 25 (§2.2) and the take
   will drift against the screen capture and the two audio tracks.
2. **The first-frame resolution lock** (§1.2) — set `output`/`viewfinder` and let
   the stream settle before the take, or pin `-video_size`.
3. **Thermals over a long take** (§4.2) — soak-test with `[Auto pwr off temp.] = High`
   and `[Standby: Low res.] = On`, no card, AC-E6N + DR-E6 on mains.

---

## Recommendation

**Use `gphoto2 --capture-movie` piped directly into the compositing ffmpeg as a
second input. Drop v4l2loopback from the pipeline.**

- It is the **only** USB video route the R5 offers — native UVC does not exist on
  this body in any firmware through 2.2.0 (§5.2), and Canon's own webcam software is
  Windows/macOS-only (§5.2).
- The stream is **clean by construction** (§3) and, at ~1024×576, already exceeds
  what a circular overlay on a 3440×1440 canvas consumes (§7).
- The `v4l2loopback` hop is **pure overhead** for a pipeline that decodes the JPEG
  anyway (§2.3) — it costs a `sudo`, a kernel module, an extra process and an extra
  place for the geometry to go wrong, and it buys nothing unless a non-ffmpeg
  consumer also needs the camera. It also currently *fails outright* because
  `max_buffer` is not a valid module parameter (§2.4).
- `-vcodec copy` is technically viable (MJPEG → `V4L2_PIX_FMT_MJPEG`, §2.1) and is
  the right choice **if** the loopback is kept for another consumer — but either way
  the input must be opened as `-f mjpeg -framerate <measured>`, because ffmpeg's raw
  demuxer hard-defaults to 25 fps with no timestamps (§2.2).
- **Keep HDMI + a UVC capture dongle as the documented fallback**, not the default:
  it is the only path to a full-resolution clean feed (§6), it needs a clean-output
  menu setting and `[Auto power off] = Disable` to survive past 30 minutes, and it
  adds hardware this pipeline does not otherwise need.
- Power it from **AC-E6N + DC Coupler DR-E6**, not from the USB-C port — the R5
  cannot be USB-powered without a battery and only via Canon's PD-E1 (§4.4).

**Before building on any number in this document, run the two verification commands
in §1.2 and §1.3 against the actual body.** The R5's exact live-view geometry and
frame rate are the one thing here I could not confirm from a primary source.
