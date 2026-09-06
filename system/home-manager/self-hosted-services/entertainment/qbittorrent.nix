{
  config,
  lib,
  pkgs,
  ...
}:
let
  data_path = "${config.home.homeDirectory}/.homelab/qbittorrent";
  download_path = config.settings.mediaPaths.downloads;

  # qBittorrent owns qBittorrent.conf -- it rewrites the whole file on shutdown,
  # so the setting can't be a nix-store symlink. Stamp it in just before the
  # container starts instead: qBittorrent is stopped at that point, so the write
  # can't be clobbered, and it survives every restart.
  sessionTimeout = 31536000;
  setSessionTimeout = pkgs.writeShellScript "qbittorrent-session-timeout" ''
    conf="${data_path}/config/qBittorrent/qBittorrent.conf"
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$conf")"

    if [ -f "$conf" ] && ${pkgs.gnugrep}/bin/grep -qF 'WebUI\SessionTimeout=' "$conf"; then
      ${pkgs.gnused}/bin/sed -i 's|^WebUI\\SessionTimeout=.*|WebUI\\SessionTimeout=${toString sessionTimeout}|' "$conf"
    elif [ -f "$conf" ] && ${pkgs.gnugrep}/bin/grep -qxF '[Preferences]' "$conf"; then
      ${pkgs.gnused}/bin/sed -i 's|^\[Preferences\]$|[Preferences]\nWebUI\\SessionTimeout=${toString sessionTimeout}|' "$conf"
    else
      printf '\n[Preferences]\n%s\n' 'WebUI\SessionTimeout=${toString sessionTimeout}' >> "$conf"
    fi
  '';
in
with lib;
{
  config = mkIf config.features.homelab.entertainment.qbittorrent.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/qbittorrent 0700 - - -"
      "d %h/.homelab/qbittorrent/config 0755 - - -"
    ];

    services.podman.containers.qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      network = [ "entertainment-network" ];

      environment = {
        PUID = "1000";
        PGID = "1000";
        # if you want to change the host port, make sure the container port is the same
        # just mapping host to a different container port won't work
        WEBUI_PORT = "8001";
        TORRENTING_PORT = "6881";
      };

      volumes = [
        "${data_path}/config:/config"
        "${download_path}:/downloads:z"
      ];

      ports = [
        "8001:8001"
        "6881:6881"
        "6881:6881/udp"
      ];

      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
        "--stop-timeout 10"
      ];

      extraConfig = {
        Service.ExecStartPre = "${setSessionTimeout}";
      };
    };
  };
}
