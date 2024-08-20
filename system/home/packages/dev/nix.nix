{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.nix.enable = lib.mkEnableOption "nix development environment";

  config = lib.mkIf config.package.dev.nix.enable {
    home.packages = with pkgs; [
      nixpkgs-fmt
      nil
      nixfmt-rfc-style
    ];
  };
}
