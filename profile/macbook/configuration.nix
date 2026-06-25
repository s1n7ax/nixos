{ pkgs, ... }:
let
  username = "s1n7ax";
in
{
  # Apple Silicon (M1) on the latest macOS.
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Required so the user may use the linux-builder as a remote builder.
    trusted-users = [
      "@admin"
      username
    ];
  };

  # microvm.nix cannot run on Darwin (NixOS/KVM only); the linux-builder is
  # nix-darwin's supported lightweight NixOS VM, doubling as a Linux remote
  # builder for aarch64-linux derivations.
  nix.linux-builder = {
    enable = true;
    maxJobs = 4;
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
  # nix-darwin applies user-scoped defaults (e.g. the Dock) for this user.
  system.primaryUser = username;

  # Auto-hide the Dock.
  system.defaults.dock.autohide = true;

  programs.fish.enable = true;

  # Make the terminal font available system-wide for kitty.
  fonts.packages = [ pkgs.nerd-fonts.iosevka ];

  # Used for backwards compatibility; read the nix-darwin changelog before
  # changing.
  system.stateVersion = 6;
}
