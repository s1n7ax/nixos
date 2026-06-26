{ ... }:
{
  # Feature flags shared by every Linux profile (desktop, server, dev-vm).
  #
  # The shared home-manager tree gates each module behind a `features.*.enable`
  # option that defaults off. This file enables the modules a headless box still
  # wants (terminals, shell, editor, CLI tooling, fonts, xdg). Desktop-only
  # modules (a window manager, launcher, notifications, cursor, GTK styles) are
  # *not* enabled here — profiles with a display opt into them via their own
  # `features.nix` (see profile/desktop and profile/dev-vm). The server profile
  # imports nothing extra, so it never pulls in a desktop environment.
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

    fonts.enable = true;

    xdg.enable = true;
  };
}
