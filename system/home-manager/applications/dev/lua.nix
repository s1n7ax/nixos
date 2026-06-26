{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.lua.enable {
    home.packages = with pkgs; [
      stylua
      lua-language-server
      luajitPackages.luacheck
    ];
  };
}
