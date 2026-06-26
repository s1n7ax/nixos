{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.rust.enable {
    home.packages = with pkgs; [
      cargo
      cargo-leptos
      cargo-generate
      rust-analyzer
      stylance-cli
    ];
  };
}
