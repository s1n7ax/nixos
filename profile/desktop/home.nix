{ ... }:
{
  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  imports = [
    ./options.nix
    ./git.nix
    ../common/home.nix
    ../../system/home-manager/profile/desktop
    # ../../system/home-manager/homelab
  ];
}
