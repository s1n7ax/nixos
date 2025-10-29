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
