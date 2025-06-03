{
  services.podman.enable = true;
  services.podman.enableTypeChecks = true;

  imports = [
    ./frigate.nix
  ];
}
