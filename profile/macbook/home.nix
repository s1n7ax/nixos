{ ... }:
{
  # Import the entire home-manager tree. Every feature is gated behind a
  # `features.*.enable` option (default off), so importing everything installs
  # nothing on its own — host-options.nix flips on only what this machine needs.
  #
  # profile/common is deliberately not imported: it pulls in the sops secrets
  # module from the private nix-secrets input, which this host has no key for.
  imports = [
    ./host-options.nix
    ../../system/home-manager
  ];

  dconf.enable = false;

  home.username = "s1n7ax";
  home.homeDirectory = "/Users/s1n7ax";
  home.stateVersion = "26.05";

  # Suppresses the "Last login: ..." banner macOS prints on new login shells.
  home.file.".hushlogin".text = "";

  # nix-darwin no longer materializes
  # users.users.<name>.openssh.authorizedKeys (its authorizedKeysFiles option
  # was removed), so the desktop-only key is enforced here instead.
  # Must stay in sync with profile/macbook/configuration.nix.
  home.file.".ssh/authorized_keys".text = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTyz+PybkD53ewO5SZQCwgFIJlq1MvirnvEFOQ7SIpE srineshnisala@gmail.com
  '';

}
