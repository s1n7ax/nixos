{ pkgs, inputs, pkgs-unstable, pkgs-node20, ... }:
let
  username = "s1n7ax";
in
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "@admin"
      username
    ];
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs pkgs-unstable pkgs-node20;
    };
    users.${username} = import ./home.nix;
  };

  system.primaryUser = username;
  system.defaults.dock.autohide = true;
  system.stateVersion = 6;

  programs.fish.enable = true;
  fonts.packages = [ pkgs.nerd-fonts.iosevka ];
}
