{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.javascript.enable = lib.mkEnableOption "javascript depelopment environment";

  config = lib.mkIf config.package.dev.javascript.enable {
    home.packages = with pkgs; [
      nodejs_22
      nodePackages.pnpm
      yarn
      emmet-language-server
      vscode-langservers-extracted
      tailwindcss-language-server
      prettierd
      typescript
      eslint_d
      nodePackages.typescript-language-server
    ];
  };
}
