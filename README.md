# Welcome to my NixOS configuration

## Prerequisites

- You have to change the hardware-configuration.nix inside the profile to match
  your hardware

## How to use

- Clone the repository

```shell
git clone https://github.com/s1n7ax/nixos.git
```

- Update flakes

```shell
nix flake update
```

- Install the system

```shell
sudo nixos-rebuild switch --upgrade --flake ./#desktop
                                              #^^^^^^^^ profile name here
```

## Rebuilding Profiles

### Available Profiles

This configuration supports multiple profiles:
- **desktop**: Full desktop environment with gaming, multimedia, and development tools
- **server**: Minimal server profile with most desktop features disabled
- **macbook**: nix-darwin profile for Apple Silicon macOS (built with `darwin-rebuild`, not `nixos-rebuild`)

### Rebuild Commands

#### Desktop Profile
```shell
# Build and switch to desktop profile
sudo nixos-rebuild switch --upgrade --flake ./#desktop

# Test desktop configuration without switching
sudo nixos-rebuild test --flake ./#desktop

# Build desktop configuration without switching
sudo nixos-rebuild build --flake ./#desktop
```

#### Server Profile
```shell
# Build and switch to server profile
sudo nixos-rebuild switch --upgrade --flake ./#server

# Test server configuration without switching
sudo nixos-rebuild test --flake ./#server

# Build server configuration without switching
sudo nixos-rebuild build --flake ./#server
```

#### macOS (macbook profile)

The `macbook` profile is a [nix-darwin](https://github.com/nix-darwin/nix-darwin)
configuration for Apple Silicon (`aarch64-darwin`) and is built with
`darwin-rebuild` instead of `nixos-rebuild`.

```shell
# 1. Install Nix (the Determinate Systems installer enables flakes by default)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Bootstrap nix-darwin (first build, before darwin-rebuild exists on PATH)
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ./#macbook

# 3. Subsequent rebuilds
sudo darwin-rebuild switch --flake ./#macbook

# Build without switching
sudo darwin-rebuild build --flake ./#macbook
```

> The profile expects the `s1n7ax` user at `/Users/s1n7ax`; adjust
> `profile/macbook/configuration.nix` and the flake's `darwinConfigurations`
> for a different username.

### Additional Commands

```shell
# Apply home-manager changes only (faster for user-level changes)
home-manager switch --flake ./#desktop

# Update flakes to latest versions
nix flake update

# Check flake syntax and evaluate
nix flake check

# Show what would be built/downloaded (dry run)
nixos-rebuild switch --flake ./#desktop --dry-run

# Garbage collect old generations
sudo nix-collect-garbage -d
```
