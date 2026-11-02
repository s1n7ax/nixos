{
  config,
  lib,
  pkgs,
  ...
}:
let
  fievel = pkgs.callPackage ./package.nix { };
in
{
  # Moves, clicks and scrolls the pointer from the keyboard: hold F3 for Free
  # Mouse Mode, Super+O/Super+U for click hints. It grabs every keyboard and
  # re-types through uinput, so the NixOS side (system/nixos/utils/fievel.nix)
  # grants the input and uinput groups.
  config = lib.mkIf config.features.desktop.fievel.enable {
    home.packages = [ fievel ];

    xdg.configFile."fievel/fievel.config".source = ./fievel.config;

    systemd.user.services.fievel = {
      Unit = {
        Description = "Fievel keyboard and mouse control";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        # Restart on config changes; fievel only reads it at startup.
        X-Restart-Triggers = [ "${./fievel.config}" ];
      };
      Service = {
        ExecStart = lib.getExe fievel;
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
