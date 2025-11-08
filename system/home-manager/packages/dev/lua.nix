{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  config = lib.mkIf config.features.development.lua.enable {
    home.packages = with pkgs; [
      pkgs-unstable.stylua
      lua-language-server
      luajitPackages.luacheck
    ];
  };
}
