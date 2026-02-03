{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.nix.enable {
    home.packages = with pkgs; [
      nixpkgs-fmt
      nil
      nixfmt
    ];
  };
}
