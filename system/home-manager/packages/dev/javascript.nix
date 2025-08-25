{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  ...
}:
{
  config = lib.mkIf config.features.development.javascript.enable {
    home.sessionVariables = {
      PNPM_HOME = "$HOME/.local/share/pnpm";
      PATH = "$HOME/.local/share/pnpm:$PATH";
    };
    home.packages = with pkgs; [
      pkgs-unstable.deno
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
      pkgs-unstable.typescript-go
      svelte-language-server
      vtsls
    ];
  };
}
