{ pkgs, ... }:
{
  settings = {
    username = "s1n7ax";
    shell = "fish";
    wm = {
      name = "hyprland";
      package = pkgs.hyprland;
    };
    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 32;
    };
    font = {
      name = "Iosevka Nerd Font Mono";
      size = 14;
    };
    icon = {
      name = "Tela-circle-dark";
      package = pkgs.tela-circle-icon-theme;
    };
  };

  # Feature flags shared by every Linux profile (desktop, server, dev-vm).
  #
  # The shared home-manager tree gates each module behind a `features.*.enable`
  # option that defaults off. This enables the modules a headless box still wants
  # (terminals, shell, editor, CLI tooling, fonts, xdg). Desktop-only modules (a
  # window manager, launcher, notifications, cursor, GTK styles) are *not* enabled
  # here — profiles with a display opt into them via their own `options.nix` (see
  # profile/desktop and profile/dev-vm). The server profile imports nothing extra,
  # so it never pulls in a desktop environment.
  features = {
    shell = {
      fish.enable = true;
    };

    editor.neovim.enable = true;

    cli = {
      eza.enable = true;
      lazygit.enable = true;
      scripts.enable = true;
      starship.enable = true;
      zoxide.enable = true;
      direnv.enable = true;
      fzf.enable = true;
      yazi.enable = true;
      vifm.enable = true;
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
