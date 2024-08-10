{
  pkgs,
  # enableNvidia ? false,
  ...
}:
{

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  # ];
  # This is used to downgrade the docker version to something older
  # Newer version causes docker buildx to throw an error
  # More info:
  # https://github.com/devcontainers/feature-starter/issues/72
  # nixpkgs.overlays = [
  #   (
  #     let
  #       pinnedPkgs = import (pkgs.fetchFromGitHub {
  #         owner = "NixOS";
  #         repo = "nixpkgs";
  #         rev = "b6bbc53029a31f788ffed9ea2d459f0bb0f0fbfc";
  #         sha256 = "sha256-JVFoTY3rs1uDHbh0llRb1BcTNx26fGSLSiPmjojT+KY=";
  #       }) { };
  #     in
  #     final: prev: { docker = pinnedPkgs.docker; }
  #   )
  # ];

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_27;
    # enableNvidia = enableNvidia;
  };
}
