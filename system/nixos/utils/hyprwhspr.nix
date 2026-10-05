{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  username = config.settings.username;

  hyprwhspr-rs =
    (pkgs-unstable.hyprwhspr-rs.override {
      # Run whisper on the GPU. Vulkan works on the GTX 1060 through the
      # proprietary driver without pulling in the unfree CUDA toolchain.
      whisper-cpp = pkgs-unstable.whisper-cpp.override { vulkanSupport = true; };
    }).overrideAttrs
      (old: {
        # Paste the transcription with Hyprland's Lua dispatch syntax. The
        # legacy syntax fails under the Lua config, so hyprwhspr-rs fell back
        # to a virtual keyboard that sometimes dropped Ctrl and typed a bare V.
        patches = (old.patches or [ ]) ++ [ ./hyprwhspr/lua-sendshortcut.patch ];
      });
in
{
  config = lib.mkIf config.features.desktop.hyprwhspr.enable {
    services.hyprwhspr-rs = {
      enable = true;
      package = hyprwhspr-rs;
    };

    environment.systemPackages = [ hyprwhspr-rs ];

    users.users.${username}.extraGroups = [ "input" ];
  };
}
