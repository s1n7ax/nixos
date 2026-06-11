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
      deno
      nodejs_22
      pnpm
      yarn
      emmet-language-server
      vscode-langservers-extracted
      tailwindcss-language-server
      prettierd
      prettier
      biome
      typescript
      eslint_d
      typescript-language-server
      supabase-cli
      pkgs-unstable.typescript-go
      pkgs-unstable.svelte-language-server
      vtsls
    ];
  };
}
