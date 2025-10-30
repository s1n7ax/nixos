{
  services.podman.enable = true;
  services.podman.enableTypeChecks = true;

  systemd.user.tmpfiles.rules = [
    "d %h/.homelab 0700 - - -"
  ];

  imports = [
    ./mqtt.nix
    ./z2m.nix
    ./home-assistant.nix
    ./frigate.nix
    ./homepage.nix
    ./filepizza.nix
    ./entertainment
  ];
}
