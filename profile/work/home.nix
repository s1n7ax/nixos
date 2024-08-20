{ ... }:
{
  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home/packages/default.nix
  ];

  package = {
    office.enable = true;

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
