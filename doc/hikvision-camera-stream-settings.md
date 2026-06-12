# Hikvision Camera Stream Settings

Apply these settings in the Hikvision web UI for each camera.

## Main Stream (channel 101) — record

| Setting          | Value          |
| ---------------- | -------------- |
| Resolution       | 1920×1080      |
| Bit Rate Type    | Variable (VBR) |
| Picture Quality  | Medium         |
| Frame Rate       | 15 fps         |
| Average Bit Rate | 512–768 Kbps   |
| Max Bit Rate     | 1024–1500 Kbps |
| Video Encoding   | H.265+         |
| Profile          | Main (only option) |
| I-Frame Interval | 30             |

## Sub Stream (channel 102) — detect + audio

| Setting          | Value          |
| ---------------- | -------------- |
| Resolution       | 640×480        |
| Bit Rate Type    | Variable (VBR) |
| Picture Quality  | Medium         |
| Frame Rate       | 6 fps          |
| Max Bit Rate     | 256–512 Kbps   |
| Video Encoding   | H.264          |
| Profile          | High           |
| I-Frame Interval | 12             |

## Notes

- H.265+ is Hikvision's proprietary smart encoding — reduces storage by 50–70% vs H.264 with no quality loss.
- Sub stream resolution (640×480) matches the Frigate detect config and minimises letterboxing for the 640×640 Frigate+ model.
- I-Frame Interval is set to 2× the frame rate as recommended by Frigate.
- Average Bit Rate is the long-term target; Max Bit Rate is the hard ceiling. Set average to ~half of max.
- Max Bit Rate for the main stream can be bumped to 2048 Kbps if footage looks blocky during fast motion.
