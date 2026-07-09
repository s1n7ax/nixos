# s1n7ax's Nix configuration

Declarative config for a Linux desktop, a Linux server, and an Apple Silicon MacBook.

## macOS setup (Apple Silicon)

### First-time setup

```shell
sh <(curl -L https://nixos.org/nix/install) --daemon
exec $SHELL -l
git clone https://github.com/s1n7ax/nixos.git ~/nixos
cd ~/nixos
sudo nix run --extra-experimental-features 'nix-command flakes' \
  nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/nixos#macbook
```

### Update and rebuild

```shell
cd ~/nixos
nix flake update
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook
```

### Common macOS commands

```shell
nix flake update                                                                   # update inputs
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook --dry-run
sudo /run/current-system/sw/bin/darwin-rebuild switch --rollback                   # undo
sudo nix-collect-garbage -d                                                        # free space
```

## NixOS (Linux) setup

Replace `hardware-configuration.nix` in the profile to match your hardware first.

Profiles: `desktop` (full DE), `server` (minimal), `macbook` (see above).

```shell
git clone https://github.com/s1n7ax/nixos.git
cd nixos

sudo nixos-rebuild switch --upgrade --flake ./#desktop   # or ./#server
sudo nixos-rebuild test --flake ./#desktop               # test, no boot default
sudo nixos-rebuild build --flake ./#desktop              # build only

home-manager switch --flake ./#desktop                   # user-level only
nix flake update
nix flake check
sudo nix-collect-garbage -d
```
