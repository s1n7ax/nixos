{
  config,
  lib,
  pkgs,
  ...
}:
{

  config = lib.mkIf config.package.present.enable {
    home.packages = with pkgs; [
      presenterm
    ];

    home.file = {
      ".config/presenterm/config.yaml".source = ./config/config.yaml;
    };
  };
}
