{ ... }:
{
  programs.firefox.profiles.s1n7ax.id = 0;
  programs.firefox.profiles.work.id = 1;

  # Override git difftastic display mode for desktop
  programs.git.difftastic.display = "side-by-side";

  imports = [
    ./options.nix
    ../common/git.nix
    ../common/home.nix
    ../../system/home-manager/profile/desktop
    # ../../system/home-manager/homelab
  ];
}
