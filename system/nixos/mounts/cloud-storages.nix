{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  username = config.settings.username;
in

mkIf config.features.storage.cloud.enable {
  environment.systemPackages = with pkgs; [ rclone ];

  # The mount's rclone config, rendered from nix-secrets on every activation.
  # sops-nix replaces whatever is at /etc/rclone-mnt.conf with a link to the
  # rendered file; rclone writes refreshed tokens through that link.
  sops.secrets."rclone/dropbox/token" = { };
  sops.templates."rclone-mnt.conf" = {
    path = "/etc/rclone-mnt.conf";
    content = ''
      [Dropbox]
      type = dropbox
      token = ${config.sops.placeholder."rclone/dropbox/token"}
    '';
  };

  systemd.mounts = [
    {
      description = "Dropbox Mount";
      what = "Dropbox:/";
      where = "/home/${username}/Drives/Dropbox";
      type = "rclone";
      wants = [ "network-online.target" ];
      options = "nodev,nofail,allow_other,args2env,config=${
        config.sops.templates."rclone-mnt.conf".path
      }";
    }
  ];
  systemd.automounts = [
    {
      description = "Dropbox Auto-mount";
      where = "/home/${username}/Drives/Dropbox";
      wantedBy = [ "multi-user.target" ];
    }
  ];
}
