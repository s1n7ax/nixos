{
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  username = config.settings.username;
in
{
  config = lib.mkIf config.features.desktop.hyprwhspr.enable {
    services.hyprwhspr-rs = {
      enable = true;
      package = pkgs-unstable.hyprwhspr-rs;
    };

    environment.systemPackages = [ pkgs-unstable.hyprwhspr-rs ];

    users.users.${username}.extraGroups = [ "input" ];
  };
}
