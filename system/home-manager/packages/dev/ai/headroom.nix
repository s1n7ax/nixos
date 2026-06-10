{
  config,
  lib,
  ...
}:
let
  cfg = config.features.development.ai.headroom;
in
{
  config = lib.mkIf cfg.enable {
    services.podman.enable = true;
    services.podman.autoUpdate.enable = true;

    systemd.user.tmpfiles.rules = [
      "d %h/.headroom 0700 - - -"
    ];

    services.podman.containers.headroom-proxy = {
      image = "ghcr.io/chopratejas/headroom:latest";
      ports = [
        "127.0.0.1:${toString cfg.port}:8787"
      ];
      volumes = [
        "${config.home.homeDirectory}/.headroom:/data:Z"
      ];
      environment = {
        HEADROOM_HOME = "/data";
      };
      extraPodmanArgs = [ "--tz=local" ];
      autoStart = true;
    };
  };
}
