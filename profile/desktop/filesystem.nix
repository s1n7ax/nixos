{ pkgs, settings, ... }:
let
  username = settings.username;
in
{
  environment.systemPackages = with pkgs; [ rclone ];

  systemd.mounts = [
    {
      description = "Dropbox Mount";
      what = "Dropbox:/";
      where = "/home/${username}/Drives/Dropbox";
      type = "rclone";
      wants = [ "network-online.target" ];
      options = "nodev,nofail,allow_other,args2env,config=/etc/rclone-mnt.conf";
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
