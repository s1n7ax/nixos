{ ... }:
{
  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home/packages/default.nix
  ];

  programs.firefox.profiles.work.isDefault = true;

  package = {
    office.enable = true;
    screen-capture.enable = true;
    web.enable = true;

    dev = {
      container.enable = true;
      javascript.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      database.enable = true;
      web.enable = true;
    };
  };
}
