{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.lua.enable = lib.mkEnableOption "lua depelopment environment";

  config = lib.mkIf config.package.dev.lua.enable {
    home.packages = with pkgs; [
      stylua
      lua-language-server
      luajitPackages.luacheck
    ];
  };
}
