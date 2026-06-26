{ ... }:
{
  # Aggregates every gated home-manager application/package module. Profiles import
  # this directory once; each leaf stays off until a `features.*.enable` flips it on.
  imports = [
    ./mpv.nix
    ./eza.nix
    ./fish.nix
    ./hyprland.nix
    ./bluetui.nix
    ./zellij.nix
    ./tmux.nix

    ./dev/c.nix
    ./dev/github.nix
    ./dev/virtualization.nix
    ./dev/java.nix
    ./dev/javascript.nix
    ./dev/lua.nix
    ./dev/markdown.nix
    ./dev/nix.nix
    ./dev/python.nix
    ./dev/rust.nix
    ./dev/sh.nix
    ./dev/toml.nix
    ./dev/yaml.nix
    ./dev/database.nix
    ./dev/env.nix
    ./dev/web.nix
    ./dev/ide.nix
    ./dev/llm.nix
    ./dev/ci.nix
    ./dev/ai
    ./dev/network.nix

    ./camera.nix
    ./screen-capture.nix
    ./fonts.nix
    ./rust-alternatives.nix
    ./utility.nix
    ./terminal.nix
    ./players.nix
    ./multi-media.nix
    ./gaming.nix
    ./mobile.nix
    ./web.nix
    ./present.nix
    ./storage.nix
  ];

}
