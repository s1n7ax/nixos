{ ... }:
{
  # Aggregates every gated home-manager application/package module. Profiles import
  # this directory once; each leaf stays off until a `features.*.enable` flips it on.
  imports = [
    # Every plain `home.packages` list lives here, gated per feature.
    ./packages.nix

    ./mpv.nix
    ./eza.nix
    ./gitleaks.nix
    ./fish.nix
    ./hyprland.nix
    ./bluetui.nix
    ./zellij.nix
    ./tmux.nix

    # dev modules that still carry non-package config (sessionVariables, programs.*, …)
    ./dev/javascript.nix
    ./dev/env.nix
    ./dev/llm.nix
    ./dev/ai
    ./dev/editorconfig.nix

    ./fuzzel.nix
    ./screen-capture.nix
    ./fonts.nix
    ./utility.nix
    ./terminal.nix
    ./web.nix
    ./presenterm
    ./nnn.nix
    ./nushell
    ./wezterm.nix
    ./st/st.nix
    ./zed/zed.nix
  ];
}
