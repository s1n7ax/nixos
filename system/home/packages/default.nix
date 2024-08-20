{ settings, ... }:
{
  imports = [
    ../applications/mpv.nix
    ../applications/${settings.shell}.nix
    ../applications/${settings.wm}.nix

    ../packages/dev/c.nix
    ../packages/dev/container.nix
    ../packages/dev/java.nix
    ../packages/dev/javascript.nix
    ../packages/dev/lua.nix
    ../packages/dev/markdown.nix
    ../packages/dev/nix.nix
    ../packages/dev/python.nix
    ../packages/dev/rust.nix
    ../packages/dev/sh.nix
    ../packages/dev/toml.nix
    ../packages/dev/yaml.nix
    ../packages/dev/database.nix
    ../packages/dev/env.nix
    ../packages/dev/web.nix
    ../packages/dev/ide.nix

    ../packages/camera.nix
    ../packages/screen-capture.nix
    ../packages/fonts.nix
    ../packages/rust-alternatives.nix
    ../packages/utility.nix
    ../packages/terminal.nix
    ../packages/players.nix
    ../packages/multi-media.nix
    ../packages/office.nix
  ];

}
