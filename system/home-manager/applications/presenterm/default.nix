{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.features.presentation.enable {
    home.packages = with pkgs; [
      presenterm
    ];

    home.file = {
      ".config/presenterm/config.yaml".source = ./config/config.yaml;
    };
  };
}
