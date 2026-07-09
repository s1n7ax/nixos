{ ... }:
{
  settings.font.size =  26;

  features = {
    terminal.kitty.enable = true;

    shell = {
      fish.enable = true;
    };

    editor.neovim.enable = true;

    development = {
      github.enable = true;
      atlassian.enable = true;
      lua.enable = true;
      python.enable = true;
      virtualization.enable = true;
    };

    virtualization = {
      docker.enable = true;
    };

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
      rustAlternatives.enable = true;
    };

    fonts.enable = true;
  };
}
