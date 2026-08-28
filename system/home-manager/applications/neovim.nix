{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
lib.mkIf config.features.editor.neovim.enable {
  # Also expose tree-sitter as a standalone CLI (grammar generation, `tree-sitter parse`, etc.),
  # not just wired into Neovim's own extraPackages environment.
  home.packages = [ pkgs.tree-sitter ];

  programs.neovim = {
    enable = true;
    # package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
    # Keep our own ~/.config/nvim/init.lua (cloned from github.com/s1n7ax/nvim)
    # instead of letting HM write its provider config there and clobber it.
    sideloadInitLua = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
    extraPackages = with pkgs; [
      nodejs_24
      python3
      gcc
      tree-sitter
    ];
  };
}
