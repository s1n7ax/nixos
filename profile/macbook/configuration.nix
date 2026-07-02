{ pkgs, inputs, ... }:
let
  username = "s1n7ax";

  # The linux-builder VM is aarch64-linux, so its home-manager modules need an
  # aarch64-linux unstable package set (the host darwinArgs pkgs-unstable is
  # aarch64-darwin). cursor-cli lives in unstable only.
  pkgsUnstableLinux = import inputs.nixpkgs-unstable {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };
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
  #
  # We also repurpose it as a headless dev box: a dedicated `s1n7ax` user runs the
  # shared home-manager tree with the same features as the microvm (dev-vm), so
  # dev tooling lives in the VM instead of on macOS. The `builder` user stays
  # reserved for Nix remote builds. See README for the bootstrap caveat (a
  # customized builder must be built by an already-running builder) and login.
  nix.linux-builder = {
    enable = true;
    maxJobs = 4;

    config =
      { ... }:
      {
        imports = [ inputs.home-manager.nixosModules.home-manager ];

        # A dev env is heavier than a build-only VM.
        virtualisation = {
          cores = 6;
          darwin-builder = {
            memorySize = 8 * 1024;
            diskSize = 60 * 1024;
          };
        };

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        # Docker daemon so the home-manager `virtualization.docker` feature works.
        virtualisation.docker.enable = true;

        # fish is the login shell for the dev user.
        programs.fish.enable = true;

        # Local-only VM: allow first login by password, then switch to keys.
        services.openssh.settings.PasswordAuthentication = true;

        users.users.${username} = {
          isNormalUser = true;
          home = "/home/${username}";
          extraGroups = [
            "wheel"
            "docker"
          ];
          shell = pkgs.fish;
          # Change immediately after first login (or add an SSH key).
          initialPassword = "changeme";
        };

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs;
            pkgs-unstable = pkgsUnstableLinux;
          };
          users.${username} = import ./vm-home.nix;
        };
      };
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
