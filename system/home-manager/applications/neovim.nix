{ pkgs, lib, config, inputs, ... }:
let
  neovimPkg = if config.features.editor.neovim.useNightly
    then inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default
    else pkgs.neovim;
in
lib.mkIf config.features.editor.neovim.enable {
  programs.neovim = {
    enable = true;
    package = neovimPkg;
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
