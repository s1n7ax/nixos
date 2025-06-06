{
  services.podman.enable = true;
  services.podman.enableTypeChecks = true;

  systemd.user.tmpfiles.rules = [
    "d %h/.homelab 0700 - - -"
  ];

  imports = [
    ./frigate.nix
    ./mqtt.nix
  ];
}
