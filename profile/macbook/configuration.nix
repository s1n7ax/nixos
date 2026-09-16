{
  pkgs,
  inputs,
  pkgs-unstable,
  ...
}:
let
  username = "s1n7ax";
in
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  # Apple Silicon (M1) on the latest macOS.
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
    # macOS ships its own dotfiles (~/.zshrc, ~/.config/fish/config.fish); back
    # them up instead of failing activation on the first switch.
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs pkgs-unstable;
    };
    users.${username} = import ./home.nix;
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
