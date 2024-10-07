{ ... }:
{
  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home/packages/default.nix
  ];

  programs.firefox.profiles.s1n7ax.id = 1;
  programs.firefox.profiles.work.id = 0;

  package = {
    office.enable = true;
    screen-capture.enable = true;
    web.enable = true;

    dev = {
      llm.enable = true;
      container.enable = true;
      javascript.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      database.enable = true;
      web.enable = true;
      ide.enable = true;
    };
  };
}
