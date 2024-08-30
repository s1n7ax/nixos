{ ... }:
{
  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home/packages/default.nix
  ];

  package = {
    camera.enable = true;
    screen-capture.enable = true;
    players.enable = true;
    multi-media.enable = true;
    gaming.enable = true;

    dev = {
      c.enable = true;
      container.enable = true;
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
      ide.enable = true;
    };
  };
}
