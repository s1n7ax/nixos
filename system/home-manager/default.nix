{ inputs, ... }:
{
  # Single entrypoint for the entire home-manager tree.
  #
  # Every module below is gated behind a `features.*.enable` option (default off,
  # except `features.core`). A profile imports this once and flips on only what it
  # wants, e.g. the macbook profile enables `features.terminal.kitty` and nothing
  # else, so only kitty is installed.
  imports = [
    ../options.nix

    # Foundational modules the gated tree depends on: rclone declares
    # `sops.secrets.*`, so the sops option set must exist even when those features
    # are disabled.
    inputs.sops-nix.homeManagerModules.sops

    # Full package/application aggregator (all leaves gated).
    ./packages

    # Server homelab containers (gated behind virtualization.podman + per-service).
    ./homelab

    # Applications not pulled in by ./packages, made available here so any profile
    # can enable them.
    ./applications/nnn.nix
    ./applications/nushell
    ./applications/wezterm.nix
    ./applications/st/st.nix
  ];
}
