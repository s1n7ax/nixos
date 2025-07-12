{
  lib,
  config,
  pkgs,
  pkgs-stable,
  ...
}:
{
  config = lib.mkIf config.features.development.javascript.enable {
    home.sessionVariables = {
      PNPM_HOME = "$HOME/.local/share/pnpm";
      PATH = "$HOME/.local/share/pnpm:$PATH";
    };
    home.packages = with pkgs; [
      pkgs-stable.deno
      nodejs_22
      nodePackages.pnpm
      yarn
      emmet-language-server
      vscode-langservers-extracted
      tailwindcss-language-server
      prettierd
      biome
      typescript
      eslint_d
      nodePackages.typescript-language-server
      supabase-cli
      typescript-go
    ];
  };
}
