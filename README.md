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

#### macOS (macbook Profile)

This profile is managed by [nix-darwin](https://github.com/nix-darwin/nix-darwin),
so use `darwin-rebuild` instead of `nixos-rebuild`. The flake output is named
`macbook`, **not** the machine's hostname — always select it with `#macbook`.

First-time bootstrap (before `darwin-rebuild` exists on the system):

```shell
# Run darwin-rebuild straight from the nix-darwin flake to install it
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/nixos#macbook
```

After the first successful switch, `darwin-rebuild` is installed at
`/run/current-system/sw/bin`. Subsequent rebuilds:

```shell
# Build and switch to the macbook profile
sudo darwin-rebuild switch --flake ~/nixos#macbook

# Build the macbook configuration without switching
sudo darwin-rebuild build --flake ~/nixos#macbook

# Check what would change (dry run)
sudo darwin-rebuild switch --flake ~/nixos#macbook --dry-run
```

> **PATH caveats**
> - If `darwin-rebuild` isn't found, open a new shell (so `/etc/profiles` /
>   `/run/current-system/sw/bin` is picked up) or invoke it by full path:
>   `/run/current-system/sw/bin/darwin-rebuild`.
> - `sudo` may strip these directories via `secure_path`; if a plain `sudo
>   darwin-rebuild` fails, call it with the full path above.

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
