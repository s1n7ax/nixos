{ ... }:
{
  # Import the entire home-manager tree. Every feature is gated behind a
  # `features.*.enable` option (default off), so importing everything installs
  # nothing on its own — the profile flips on only what this machine needs.
  imports = [ ../../system/home-manager ];

  home.stateVersion = "26.05";

  # Only kitty activates from the shared tree.
  features.terminal.kitty.enable = true;
}
