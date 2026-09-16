{
  lib,
  config,
  pkgs,
  ...
}:
lib.mkIf config.features.shell.fish.enable {
  # HM's fish module defaults generateCaches=true for `man -k` completions, but
  # on Darwin (stateVersion >= 26.05) programs.man.package is null — macOS ships
  # its own man and Nix's GNU man-db breaks apropos there.
  programs.man.generateCaches = lib.mkIf pkgs.stdenv.isDarwin (lib.mkForce false);

  programs.fish = {
    enable = true;
    shellInit = ''
      fish_add_path -gm ~/.local/bin
    ''
    # macOS login shells don't inherit the Nix profile dirs the way NixOS does,
    # and Homebrew lives outside Nix entirely.
    + lib.optionalString pkgs.stdenv.isDarwin ''
      fish_add_path -gm /etc/profiles/per-user/${config.home.username}/bin /run/current-system/sw/bin $HOME/.nix-profile/bin /opt/homebrew/bin /opt/homebrew/sbin
    ''
    + ''
      stty -ixon

      set -x PATH $PATH ~/.cargo/bin

      # disable greeting
      set -g fish_greeting

      bind ctrl-n backward-word and backward-word and forward-word
      bind ctrl-e forward-word
      bind ctrl-w backward-kill-word
      bind ctrl-a beginning-of-line
      bind ctrl-o end-of-line
    '';
  };

  # macOS: a pre-existing ~/.config/fish/config.fish would otherwise block activation.
  xdg.configFile."fish/config.fish".force = true;
}
