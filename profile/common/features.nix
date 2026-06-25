{ ... }:
{
  # Behavior-preserving baseline for the Linux profiles (desktop, server, dev-vm).
  #
  # The shared home-manager tree used to force-import these modules
  # unconditionally via packages/default.nix. They are now each gated behind a
  # `features.*.enable` option that defaults off, so enabling them here keeps the
  # Linux profiles' home-manager output identical. The macbook profile does not
  # import this file (or packages/default.nix), so it stays minimal.
  #
  # PR 2 moves these flags into the individual profiles and prunes what a headless
  # server never needed.
  features = {
    terminal = {
      kitty.enable = true;
      alacritty.enable = true;
      ghostty.enable = true;
    };

    shell = {
      fish.enable = true;
      zsh.enable = true;
    };

    editor.neovim.enable = true;

    cli = {
      eza.enable = true;
      mpv.enable = true;
      lazygit.enable = true;
      scripts.enable = true;
      starship.enable = true;
      zoxide.enable = true;
      direnv.enable = true;
      fzf.enable = true;
      vifm.enable = true;
      yazi.enable = true;
      zathura.enable = true;
      htop.enable = true;
      alias.enable = true;
      pet.enable = true;
      utilities.enable = true;
      rustAlternatives.enable = true;
    };

    desktop = {
      dunst.enable = true;
      rofi.enable = true;
      cursor.enable = true;
      styles.enable = true;
      hyprland.enable = true;
    };

    fonts.enable = true;

    xdg.enable = true;
  };
}
