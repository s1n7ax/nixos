{...}:
{
  systemd.user.services = {
    "rclone@" = {
      Unit = {
        Description = "rclone: Remote FUSE filesystem for cloud storage config %i";
        Documentation = "man:rclone(1)";
        After = "network-online.target";
        Wants = "network-online.target";
      };
      Service = {
        Type = "notify";
        ExecStartPre = "mkdir -p %h/Mount/%i";
        ExecStart = "rclone mount %i: %h/Mount/%i";
        ExecStop = "umount %h/Mount/%i";
        Restart = "always";
        RestartSec = "10";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
