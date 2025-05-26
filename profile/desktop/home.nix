{ config, ... }:
{
  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  package = {
    camera.enable = true;
    screen-capture.enable = true;
    players.enable = true;
    multi-media.enable = true;
    gaming.enable = true;
    web.enable = true;
    present.enable = true;
    # firefox.librewolf.enable = false;

    dev = {
      llm.enable = true;
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
      ci.enable = true;
    };
  };

  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home-manager/packages
    ../../system/home-manager/profile/desktop
  ];

  age = {
    identityPaths = [ "/home/s1n7ax/.ssh/id_ed25519" ];
    secrets = {
      secret3 = {
        file = ../../secrets/secret1.age;
      };
    };
  };

  home.file."hello.txt".text = config.age.secrets.secret3.path;
}
