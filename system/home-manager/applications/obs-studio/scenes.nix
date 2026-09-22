/**
  Builds the OBS scene collection as a plain attribute set, ready for
  `builtins.toJSON`.

  Item transforms are written in absolute canvas pixels only. OBS 31+ stores a
  second, canvas-relative copy of every transform (`pos_rel`, `scale_rel`, ...)
  but derives it on load from `resolution` when it is missing, so leaving those
  fields out keeps this file readable and lets OBS own the conversion.
*/
{
  lib,
  canvas,
  recordingPath,
  collectionName,
  cameraDevice,
}:
let
  inherit (canvas) width height;

  uuid = {
    desktopAudio = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a11";
    mic = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a12";
    screen = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a13";
    camera = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a14";
    cameraFrame = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a15";
    sceneDesktopCam = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a16";
    sceneCamera = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a17";
    sceneDesktop = "9f2c1a40-6d1b-4f8e-9a30-1c4b7e5d0a18";
  };

  name = {
    screen = "Screen";
    camera = "Facecam";
    cameraFrame = "Facecam Frame";
    desktopCam = "Desktop + Facecam";
    cameraOnly = "Facecam Fullscreen";
    desktopOnly = "Desktop";
  };

  /**
    Audio tracks the recording is split across: track 1 is the mix you can
    upload as-is, tracks 2 and 3 are the isolated mic and desktop stems so a
    bad take can be fixed in the edit instead of re-shot. `mixers` is a bitmask
    over those tracks.
  */
  tracks = {
    mixAndMic = 3;
    mixAndDesktop = 5;
  };

  /**
    OBS bounding-box modes. `scaleInner` letterboxes a source inside the box
    (nothing is cropped); `scaleOuter` fills the box and clips the overflow.
    Both keep the layout correct whatever resolution the source reports, which
    matters for a webcam that is not plugged in at activation time.
  */
  bounds = {
    none = 0;
    scaleInner = 2;
    scaleOuter = 3;
  };

  /**
    The facecam overlay is square rather than the camera's native 16:9 frame.
    `scaleOuter` bounds fill the box and clip the overflow, so the sides of the
    picture are cropped away and the middle is kept.
  */
  cameraBox = {
    size = 480;
    margin = 48;
    border = 6;
  };

  cameraBoxLeft = width - cameraBox.size - cameraBox.margin;
  cameraBoxTop = height - cameraBox.size - cameraBox.margin;

  borderSpeed = 0.12;

  /**
    Paints the facecam's border as a hue wheel that rotates once every
    `1 / speed` seconds, on the colour source sitting behind the camera. Only
    the outer `border` pixels are drawn; everything further in is transparent
    (premultiplied, which is what obs-shaderfilter's alpha-divide output pass
    expects) and would be hidden under the camera anyway.

    obs-shaderfilter declares `uv_size` and `elapsed_time` itself, so the
    shader must not redeclare them.
  */
  borderShader = ''
    float3 hue(float h)
    {
      float3 rgb = clamp(abs(frac(h + float3(0.0, 0.66666667, 0.33333333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
      return rgb * rgb * (3.0 - 2.0 * rgb);
    }

    float4 mainImage(VertData v_in) : TARGET
    {
      float2 px = v_in.uv * uv_size;
      float edge = min(min(px.x, uv_size.x - px.x), min(px.y, uv_size.y - px.y));

      float2 centred = v_in.uv - 0.5;
      float angle = atan2(centred.y, centred.x) * 0.15915494 + 0.5;
      float3 colour = hue(frac(angle + elapsed_time * ${toString borderSpeed}));

      float thickness = ${toString cameraBox.border}.0;
      float alpha = 1.0 - smoothstep(thickness - 1.0, thickness + 1.0, edge);
      return float4(colour * alpha, alpha);
    }
  '';

  sourceDefaults = {
    prev_ver = 536936450;
    mixers = 0;
    sync = 0;
    flags = 0;
    volume = 1.0;
    balance = 0.5;
    enabled = true;
    muted = false;
    "push-to-mute" = false;
    "push-to-mute-delay" = 0;
    "push-to-talk" = false;
    "push-to-talk-delay" = 0;
    hotkeys = { };
    deinterlace_mode = 0;
    deinterlace_field_order = 0;
    monitoring_type = 0;
    private_settings = { };
  };

  mkSource = attrs: sourceDefaults // { versioned_id = attrs.id; } // attrs;

  mkFilter =
    {
      name,
      id,
      settings ? { },
      versioned_id ? id,
    }:
    mkSource {
      inherit
        name
        id
        settings
        versioned_id
        ;
    };

  itemDefaults = {
    visible = true;
    locked = false;
    rot = 0.0;
    scale_ref = {
      x = 1920.0;
      y = 1080.0;
    };
    align = 5;
    bounds_type = bounds.none;
    bounds_align = 0;
    bounds_crop = false;
    crop_left = 0;
    crop_top = 0;
    crop_right = 0;
    crop_bottom = 0;
    group_item_backup = false;
    pos = {
      x = 0.0;
      y = 0.0;
    };
    scale = {
      x = 1.0;
      y = 1.0;
    };
    bounds = {
      x = 0.0;
      y = 0.0;
    };
    scale_filter = "disable";
    blend_method = "default";
    blend_type = "normal";
    show_transition.duration = 0;
    hide_transition.duration = 0;
    private_settings = { };
  };

  mkItem = attrs: itemDefaults // attrs;

  /**
    Fills the whole canvas with the source, cropping whatever does not fit.
    Used for the fullscreen facecam. The camera only offers 1024x576, so this
    is a 3.4x upscale of a 16:9 frame into a 21:9 canvas — the top and bottom
    are cropped away and it needs a real resampler rather than the nearest-
    neighbour `disable` that every other item can afford.
  */
  fillCanvas = {
    bounds_type = bounds.scaleOuter;
    bounds = {
      x = width * 1.0;
      y = height * 1.0;
    };
    scale_filter = "lanczos";
  };

  /**
    Fits the whole source inside the canvas, centred. The canvas is the
    monitor's own resolution, so this is a 1:1 fit with no bars; it stays a
    bounding box rather than a bare 1.0 scale so a different display still
    lands inside the frame instead of overflowing it.
  */
  fitCanvas = {
    bounds_type = bounds.scaleInner;
    bounds = {
      x = width * 1.0;
      y = height * 1.0;
    };
    scale_filter = "area";
  };

  cameraOverlay = {
    bounds_type = bounds.scaleOuter;
    pos = {
      x = cameraBoxLeft * 1.0;
      y = cameraBoxTop * 1.0;
    };
    bounds = {
      x = cameraBox.size * 1.0;
      y = cameraBox.size * 1.0;
    };
    scale_filter = "area";
  };

  cameraFrameOverlay = {
    pos = {
      x = (cameraBoxLeft - cameraBox.border) * 1.0;
      y = (cameraBoxTop - cameraBox.border) * 1.0;
    };
  };

  mkScene =
    {
      name,
      uuid,
      hotkey,
      items,
    }:
    mkSource {
      inherit name uuid;
      id = "scene";
      settings = {
        id_counter = builtins.length items;
        custom_size = false;
        items = lib.imap1 (index: item: item // { id = index; }) items;
      };
      hotkeys."OBSBasic.SelectScene" = [ { key = "OBS_KEY_${hotkey}"; } ];
      canvas_uuid = "6c69626f-6273-4c00-9d88-c5136d61696e";
    };

  screenItem = mkItem (
    fitCanvas
    // {
      name = name.screen;
      source_uuid = uuid.screen;
    }
  );

  micFilters = [
    (mkFilter {
      name = "Noise Suppression";
      id = "noise_suppress_filter";
      versioned_id = "noise_suppress_filter_v2";
    })
    (mkFilter {
      name = "Noise Gate";
      id = "noise_gate_filter";
      settings = {
        open_threshold = -21.0;
        /**
          Must sit below `open_threshold`. Level 0.0 (the value this chain used
          to carry) closes the gate the instant it opens, clipping the tail off
          every phrase.
        */
        close_threshold = -26.0;
        attack_time = 0;
      };
    })
    (mkFilter {
      name = "3-Band Equalizer";
      id = "basic_eq_filter";
      settings = {
        low = -1.4;
        mid = -5.7;
      };
    })
    (mkFilter {
      name = "Expander";
      id = "expander_filter";
      settings = {
        ratio = 3.0;
        threshold = -37.2;
        attack_time = 1;
        output_gain = 10.4;
      };
    })
    (mkFilter {
      name = "Compressor";
      id = "compressor_filter";
      settings = {
        ratio = 3.0;
        threshold = -21.7;
        attack_time = 1;
      };
    })
    (mkFilter {
      name = "Limiter";
      id = "limiter_filter";
      settings.threshold = -10.0;
    })
  ];

  /**
    Ducks anything playing on the desktop whenever the mic picks up speech, so
    a demo's own audio does not fight the voiceover.
  */
  desktopDucking = mkFilter {
    name = "Duck Under Voice";
    id = "compressor_filter";
    settings = {
      ratio = 10.0;
      threshold = -30.0;
      attack_time = 10;
      release_time = 250;
      output_gain = 0.0;
      sidechain_source = "Mic/Aux";
    };
  };
in
{
  name = collectionName;

  DesktopAudioDevice1 = mkSource {
    name = "Desktop Audio";
    uuid = uuid.desktopAudio;
    id = "pulse_output_capture";
    settings.device_id = "default";
    mixers = tracks.mixAndDesktop;
    filters = [ desktopDucking ];
  };

  AuxAudioDevice1 = mkSource {
    name = "Mic/Aux";
    uuid = uuid.mic;
    id = "pulse_input_capture";
    settings.device_id = "default";
    mixers = tracks.mixAndMic;
    filters = micFilters;
  };

  sources = [
    (mkSource {
      name = name.screen;
      uuid = uuid.screen;
      id = "pipewire-screen-capture-source";
      settings = { };
    })

    (mkSource {
      name = name.camera;
      uuid = uuid.camera;
      id = "v4l2_input";
      settings = {
        device_id = cameraDevice;
        input = 0;
        pixelformat = 1196444237;
      };
      /**
        Writes the raw camera feed to its own file alongside the programme
        recording, so the edit can cut to an unscaled talking head that was
        never a 640x360 corner box.
      */
      filters = [
        (mkFilter {
          name = "Source Record";
          id = "source_record_filter";
          settings = {
            record_mode = 3;
            scale_type = 3;
            path = recordingPath;
            filename_formatting = "%CCYY-%MM-%DD_%hh-%mm-%ss-facecam";
            encoder = "x264";
            rate_control = "CRF";
            crf = 18;
            preset = "veryfast";
          };
        })
      ];
    })

    (mkSource {
      name = name.cameraFrame;
      uuid = uuid.cameraFrame;
      id = "color_source_v3";
      settings = {
        color = 4294967295;
        width = cameraBox.size + (2 * cameraBox.border);
        height = cameraBox.size + (2 * cameraBox.border);
      };
      filters = [
        (mkFilter {
          name = "Animated Border";
          id = "shader_filter";
          settings = {
            from_file = false;
            shader_text = borderShader;
          };
        })
      ];
    })

    (mkScene {
      name = name.desktopCam;
      uuid = uuid.sceneDesktopCam;
      hotkey = "F1";
      items = [
        screenItem
        (mkItem (
          cameraFrameOverlay
          // {
            name = name.cameraFrame;
            source_uuid = uuid.cameraFrame;
          }
        ))
        (mkItem (
          cameraOverlay
          // {
            name = name.camera;
            source_uuid = uuid.camera;
          }
        ))
      ];
    })

    (mkScene {
      name = name.cameraOnly;
      uuid = uuid.sceneCamera;
      hotkey = "F2";
      items = [
        (mkItem (
          fillCanvas
          // {
            name = name.camera;
            source_uuid = uuid.camera;
          }
        ))
      ];
    })

    (mkScene {
      name = name.desktopOnly;
      uuid = uuid.sceneDesktop;
      hotkey = "F3";
      items = [ screenItem ];
    })
  ];

  groups = [ ];

  scene_order = [
    { name = name.desktopCam; }
    { name = name.cameraOnly; }
    { name = name.desktopOnly; }
  ];

  current_scene = name.desktopCam;
  current_program_scene = name.desktopCam;

  current_transition = "Fade";
  transition_duration = 200;
  transitions = [ ];

  quick_transitions = [
    {
      name = "Cut";
      duration = 300;
      hotkeys = [ ];
      id = 1;
      fade_to_black = false;
    }
    {
      name = "Fade";
      duration = 300;
      hotkeys = [ ];
      id = 2;
      fade_to_black = false;
    }
  ];

  saved_projectors = [ ];
  preview_locked = false;
  scaling_enabled = false;
  scaling_level = 0;
  scaling_off_x = 0.0;
  scaling_off_y = 0.0;

  "virtual-camera".type2 = 3;

  modules = { };

  resolution = {
    x = width;
    y = height;
  };
}
