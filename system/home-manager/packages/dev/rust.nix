{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.rust.enable = lib.mkEnableOption "rust development environment";

  config = lib.mkIf config.package.dev.rust.enable {
    home.packages = with pkgs; [
      cargo
      cargo-leptos
      cargo-generate
      rust-analyzer
      stylance-cli
    ];
  };
}
