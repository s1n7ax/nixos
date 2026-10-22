{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  keymap = inputs.open-unicode-converter-m17n.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
lib.mkIf config.features.desktop.sinhala.enable {
  # si-ouc is a Singlish transliteration keymap that types exactly like Open
  # Unicode Converter (sinhalaunicode.org). It comes from the
  # open-unicode-converter-m17n flake input
  # (github.com/s1n7ax/open-unicode-converter-m17n) and is installed into
  # ~/.m17n.d, where m17n-lib picks up user keymaps; fcitx5-m17n exposes it as
  # m17n_si_ouc. Super+Space (a Hyprland bind) toggles English <-> Sinhala.
  #
  # No binding uses Shift: holding Space produces Shift on this keymap, so a
  # Shift+Space chord is impossible to press. fcitx5's default TriggerKeys
  # (Ctrl+Space) and AltTriggerKeys (lone Shift tap) are cleared for the same
  # reason; dropping Ctrl+Space also stops fcitx5 from swallowing the editor
  # "Trigger Suggest" shortcut.
  #
  # fcitx5 treats the *first* group item as the inactive (keyboard) state and
  # DefaultIM as the input method the toggle activates, so keyboard-us must stay
  # first and DefaultIM must name the Sinhala scheme.
  home.file.".m17n.d/si-ouc.mim".source = "${keymap}/share/m17n/si-ouc.mim";

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      addons = [ pkgs.fcitx5-m17n ];

      settings = {
        globalOptions.Hotkey = {
          TriggerKeys = "";
          AltTriggerKeys = "";
        };

        inputMethod = {
          GroupOrder."0" = "Default";

          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "m17n_si_ouc";
          };

          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "m17n_si_ouc";
        };
      };
    };
  };
}
