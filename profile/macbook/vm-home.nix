{ lib, ... }:
{
  # Home-manager config for the dev user *inside* the Mac's linux-builder VM
  # (aarch64-linux). It replicates the microvm (dev-vm) feature set by reusing the
  # same options files, then swaps Claude Code for the Cursor CLI. The secrets
  # module is intentionally omitted: only the self-hosted-service features need
  # sops, and none of those are enabled here, so the VM needs no age key.
  dconf.enable = false;

  home.username = "s1n7ax";
  home.homeDirectory = "/home/s1n7ax";
  home.stateVersion = "24.05";

  imports = [
    ../common/options.nix # settings block + base features (fish, neovim, cli.*, fonts, xdg)
    ../dev-vm/options.nix # dev features (docker, llm, ai, git, github, langs, database, web, ide)
    ../../system/home-manager
  ];

  # This profile uses the Cursor CLI in place of Claude Code.
  features.development.ai.claude.enable = lib.mkForce false;
  features.development.ai.cursor-cli.enable = true;
}
