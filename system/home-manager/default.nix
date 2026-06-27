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

    # Foundational modules the gated tree depends on: self-hosted services
    # (frigate, z2m) declare `sops.secrets.*`/`sops.templates.*`, so the sops
    # option set must exist even when those features are disabled.
    inputs.sops-nix.homeManagerModules.sops

    # Full application aggregator (all leaves gated).
    ./applications

    # Server self-hosted-service containers (gated behind virtualization.podman + per-service).
    ./self-hosted-services

  ];
}
