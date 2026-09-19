# One ffmpeg, or a supervisor over several?

Type: grilling
Status: open

## Question

Is this one `ffmpeg` process with four inputs and a filter graph, or a small supervisor script running several processes?

- A/V sync: three sources (screen, camera, two audio) start at different moments and drift. Does a single ffmpeg with `-itsoffset` handle it, or does sync need explicit handling?
- Failure mid-take: the camera sleeps, overheats, or the USB drops (ticket 01 says how likely). Does the whole recording die, or does the screen keep recording with the circle frozen or gone? Which do you want?
- Ctrl-C handling: a single process gets SIGINT and must finalise a valid container. Several processes need coordinated shutdown.
- Where does the temp file live before the rename, and what guarantees it is a playable file if the machine dies?

Use `/grilling` and `/domain-modeling`.

**From ticket 01**: the camera stream is raw MJPEG with no container and no timestamps, and ffmpeg's raw demuxer fabricates 25 fps for it (`AVFMT_NOTIMESTAMPS`). Whatever shape is chosen has to deal with an input whose declared rate is a lie and whose real rate is unpaced ~10-25 fps.
