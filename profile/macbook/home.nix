{ ... }:
{
  imports = [
    # Declares settings.* (font, shell, ...) consumed by the shared modules
    # below. Package-typed defaults (wm/cursor/icon) are Linux-only but stay
    # lazily unevaluated since nothing here reads them.
    ../../system/options.nix
    # Reuse the exact kitty config the NixOS hosts use — single source of truth.
    ../../system/home-manager/applications/kitty.nix
  ];

  home.stateVersion = "26.05";
}
