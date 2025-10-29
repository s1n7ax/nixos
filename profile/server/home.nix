{ ... }:
{
  # Override git difftastic display mode for server
  programs.git.difftastic.display = "inline";

  imports = [
    ./options.nix
    ../common/git.nix
    ../common/home.nix
    ../../system/home-manager/profile/server
    ../../system/home-manager/homelab
  ];
}
