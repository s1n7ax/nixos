{ ... }:
{
  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  package = {
    dev = {
      nix.enable = true;
    };
  };

  features = {
    homelab.frigate.enable = true;
  };

  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home-manager/profile/server
    ../../system/home-manager/homelab

    ./options.nix
  ];
}
