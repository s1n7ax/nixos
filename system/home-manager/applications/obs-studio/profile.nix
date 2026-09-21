/**
  Builds the OBS profile: `basic.ini` (canvas, output, hotkeys) plus the
  `recordEncoder.json` the advanced recording encoder reads its settings from.

  Targets YouTube uploads off a GTX 1060: 1440p60 gets VP9 rather than AVC once
  YouTube re-encodes it, which is what keeps terminal text legible, and the
  card's NVENC handles it without touching the CPU the screen capture is
  sharing with everything being demoed.
*/
{
  canvas,
  recordingPath,
  profileName,
}:
let
  inherit (canvas) width height fps;

  /**
    Hybrid MP4 writes an MP4 that stays playable if OBS dies mid-recording and
    still carries several audio tracks and chapter markers, so there is no
    remux step between recording and editing.
  */
  container = "hybrid_mp4";

  /**
    Pascal has no AV1 encoder and its HEVC block cannot do B-frames, so H.264
    is both the faster and the more editable choice here.
  */
  recordEncoderId = "obs_nvenc_h264_tex";

  audioTrackBitrate = 256;

  hotkeys = {
    "OBSBasic.StartRecording" = "OBS_KEY_F9";
    "OBSBasic.StopRecording" = "OBS_KEY_F9";
    "OBSBasic.PauseRecording" = "OBS_KEY_F10";
    "OBSBasic.UnpauseRecording" = "OBS_KEY_F10";
    "OBSBasic.SplitFile" = "OBS_KEY_F11";
    "OBSBasic.AddChapterMarker" = "OBS_KEY_F12";
  };

  hotkeyLines = builtins.concatStringsSep "\n" (
    builtins.attrValues (builtins.mapAttrs (action: key: ''${action}=[{"key":"${key}"}]'') hotkeys)
  );
in
{
  basicIni = ''
    [General]
    Name=${profileName}

    [Output]
    Mode=Advanced
    FilenameFormatting=%CCYY-%MM-%DD_%hh-%mm-%ss
    DelayEnable=false
    Reconnect=true
    RetryDelay=2
    MaxRetries=25
    BindIP=default
    IPFamily=IPv4+IPv6
    NewSocketLoopEnable=false
    LowLatencyEnable=false

    [AdvOut]
    RecType=Standard
    RecFilePath=${recordingPath}
    RecFormat2=${container}
    RecEncoder=${recordEncoderId}
    RecAudioEncoder=ffmpeg_aac
    RecTracks=7
    RecUseRescale=false
    RecRescaleRes=${toString width}x${toString height}
    RecFileNameWithoutSpace=true
    RecSplitFile=false
    RecSplitFileType=Time
    RecSplitFileTime=15
    RecSplitFileSize=2048
    RecRB=false
    RecRBTime=20
    RecRBSize=512
    ApplyServiceSettings=true
    UseRescale=false
    TrackIndex=1
    VodTrackIndex=2
    Encoder=obs_x264
    AudioEncoder=ffmpeg_aac
    FLVTrack=1
    StreamMultiTrackAudioMixes=1
    Track1Bitrate=${toString audioTrackBitrate}
    Track2Bitrate=${toString audioTrackBitrate}
    Track3Bitrate=${toString audioTrackBitrate}
    Track4Bitrate=${toString audioTrackBitrate}
    Track5Bitrate=${toString audioTrackBitrate}
    Track6Bitrate=${toString audioTrackBitrate}

    [SimpleOutput]
    FilePath=${recordingPath}
    RecFormat2=${container}
    RecQuality=HQ
    RecEncoder=${recordEncoderId}
    RecAudioEncoder=aac
    RecTracks=1
    RecRB=false

    [Stream1]
    IgnoreRecommended=false
    EnableMultitrackVideo=false

    [Video]
    BaseCX=${toString width}
    BaseCY=${toString height}
    OutputCX=${toString width}
    OutputCY=${toString height}
    FPSType=0
    FPSCommon=${toString fps}
    FPSInt=${toString fps}
    FPSNum=${toString fps}
    FPSDen=1
    ScaleType=bicubic
    ColorFormat=NV12
    ColorSpace=709
    ColorRange=Partial
    SdrWhiteLevel=300
    HdrNominalPeakLevel=1000

    [Audio]
    MonitoringDeviceId=default
    MonitoringDeviceName=Default
    SampleRate=48000
    ChannelSetup=Stereo
    MeterDecayRate=23.53
    PeakMeterType=0

    [Hotkeys]
    ${hotkeyLines}
  '';

  /**
    CQP 18 is visually lossless for screen content while staying far below the
    card's throughput at 1440p60; `psycho_aq` and the lookahead spend the spare
    headroom on the flat UI regions that banding shows up in.

    `p5` is as far as this card goes — asking for p6 or p7 gets logged back as
    p5, since the slower presets need encoder features Pascal does not have.
  */
  recordEncoder = {
    rate_control = "CQP";
    cqp = 18;
    preset2 = "p5";
    tune = "hq";
    multipass = "qres";
    profile = "high";
    bf = 2;
    lookahead = true;
    psycho_aq = true;
    keyint_sec = 2;
    gpu = 0;
  };
}
