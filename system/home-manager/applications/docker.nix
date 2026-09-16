{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.virtualization.docker;
in
{
  # On NixOS the daemon comes from system/nixos/utils/docker.nix. macOS has no
  # Linux kernel to run it, so colima supplies the VM and the CLI talks to that.
  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    programs.docker-cli.enable = true;
    services.colima.enable = true;
    home.packages = [ pkgs.docker ];
  };
}
