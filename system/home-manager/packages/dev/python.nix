{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.python.enable {
    home.packages = with pkgs; [
      (python3.withPackages (py-packages: with py-packages; [ pip ]))
      isort
      ruff
      black
      virtualenv
    ];
  };
}
