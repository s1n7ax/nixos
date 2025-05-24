{ ... }:
{
  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home-manager/packages/default.nix
  ];

  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  package = {
    dev = {
      nix.enable = true;
    };
  };
}
