{ ... }:
{
  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  imports = [
    ../common/home.nix
    ./git.nix
    ../../system/home-manager/profile/desktop

    ./options.nix
  ];
}
