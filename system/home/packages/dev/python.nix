{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.python.enable = lib.mkEnableOption "python development environment";

  config = lib.mkIf config.package.dev.python.enable {
    home.packages = with pkgs; [
      (python3.withPackages (py-packages: with py-packages; [ pip ]))
      isort
      black
      virtualenv
    ];
  };
}
