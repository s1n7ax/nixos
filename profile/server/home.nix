{ ... }:
{
  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home/packages/default.nix
  ];

  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  package = {
    camera.enable = false;
    screen-capture.enable = false;
    players.enable = false;
    multi-media.enable = false;
    gaming.enable = false;
    web.enable = false;
    present.enable = false;
    # firefox.librewolf.enable = false;

    dev = {
      llm.enable = false;
      c.enable = false;
      container.enable = false;
      java.enable = false;
      javascript.enable = false;
      lua.enable = false;
      markdown.enable = false;
      nix.enable = false;
      python.enable = false;
      rust.enable = false;
      sh.enable = false;
      toml.enable = false;
      yaml.enable = false;
      database.enable = false;
      web.enable = false;
      ide.enable = false;
      ci.enable = false;
    };
  };
}
