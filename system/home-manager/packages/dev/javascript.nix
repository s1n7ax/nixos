{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.package.dev.javascript.enable = lib.mkEnableOption "javascript depelopment environment";

  config = lib.mkIf config.package.dev.javascript.enable {
    home.sessionVariables = {
      PNPM_HOME = "$HOME/.local/share/pnpm";
      PATH = "$HOME/.local/share/pnpm:$PATH";
    };
    home.packages = with pkgs; [
      deno
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
      supabase-cli
      typescript-go
    ];
  };
}
