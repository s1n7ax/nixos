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

      atlassian.enable = true;
            llm.enable = true;
      ai = {
        enable = true;
        opencode.enable = false;
        claude.enable = false;
        headroom.enable = false;
      };
      git.enable = true;
      github.enable = true;
      c.enable = true;
      java.enable = true;
      javascript.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      python.enable = true;
      rust.enable = true;
      sh.enable = true;
      toml.enable = true;
      yaml.enable = true;
      database.enable = true;
      web.enable = true;
      ide.enable = false;
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
