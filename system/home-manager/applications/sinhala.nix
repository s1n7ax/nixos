{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.desktop.sinhala.enable {
  # Singlish is a transliteration keymap shipped by m17n-db; fcitx5-m17n exposes
  # si-singlish as m17n_si_singlish. Super+Space (a Hyprland bind) toggles
  # English <-> Sinhala.
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
            DefaultIM = "m17n_si_singlish";
          };

          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "m17n_si_singlish";
        };
      };
    };
  };
}
