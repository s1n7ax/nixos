# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Building and Testing
```shell
# Update flakes to latest versions
nix flake update

# Build and switch to desktop profile
sudo nixos-rebuild switch --upgrade --flake ./#desktop

# Build and switch to work profile  
sudo nixos-rebuild switch --upgrade --flake ./#work

# Build and switch to server profile
sudo nixos-rebuild switch --upgrade --flake ./#server

# Test configuration without switching
sudo nixos-rebuild test --flake ./#desktop

# Build configuration without switching
sudo nixos-rebuild build --flake ./#desktop

# Check flake syntax and evaluate
nix flake check
```

### Development Workflow
```shell
# Apply home-manager changes only
home-manager switch --flake ./#desktop

# Garbage collect old generations
sudo nix-collect-garbage -d

# Show what would be built/downloaded
nixos-rebuild switch --flake ./#desktop --dry-run
```

## Architecture Overview

This is a modular NixOS configuration using flakes with profile-based system management.

### Core Structure
- **flake.nix**: Main entry point defining system configurations for `desktop` and `work` profiles
- **profile/**: Contains profile-specific configurations that import from common and system modules
- **system/**: Reusable system modules organized by category
- **settings**: Global configuration object passed to all modules via specialArgs

### Configuration Hierarchy
1. **flake.nix** defines global settings (username, shell, WM, theming) and profile configurations
2. **profile/{desktop,work}/configuration.nix** imports common config + profile-specific system modules
3. **profile/{desktop,work}/home.nix** imports common home config + profile-specific package sets
4. **profile/common/** contains shared configuration between all profiles
5. **system/** contains modular system configurations imported by profiles

### Key Settings Object
The `settings` object in flake.nix contains:
- `username`: System username (s1n7ax)
- `shell`: Default shell (fish)  
- `wm`: Window manager config (hyprland)
- `cursor`, `font`, `icon`: Theming configuration
- `terminal`: Default terminal (ghostty)

### Module Organization
- **system/core/**: Essential system services (boot, networking, audio, polkit)
- **system/hardware/**: Hardware-specific configurations (bluetooth, nvidia, openrgb)
- **system/home/**: Home-manager configurations and package collections
- **system/home/packages/**: Modular package sets with enable flags
- **system/utils/**: Optional utilities (docker, virtualization, applications)
- **system/mounts/**: Storage and mount configurations

### Package Management
The package system uses enable flags in profile home.nix files:
```nix
package = {
  dev.nix.enable = true;
  dev.python.enable = true;
  gaming.enable = true;
  # etc.
};
```

Each package module in `system/home/packages/` checks these flags to conditionally install packages.

### Feature Flag System
The configuration uses a custom options system (`system/options.nix`) to control features across all profiles:

#### Available Feature Categories
- **desktop**: Desktop environment features (hyprland, xdg, kdeconnect)
- **security**: Security tools (gpg)
- **hardware**: Hardware support (bluetooth, nvidia, openrgb, audio)
- **development**: Development tools (docker, virtualbox, virt-manager)
- **services**: System services (fwupd, flatpak)
- **storage**: Storage features (cloud mounts)
- **network**: Network services (ssh)

#### Feature Configuration
Features are configured in `flake.nix` for each profile:
```nix
features = {
  desktop.enable = true;
  desktop.hyprland.enable = true;
  hardware.bluetooth.enable = false;  # Disable for server
  development.virtualbox.enable = true;
};
```

### Profile Differences
- **desktop**: Full desktop environment with gaming, multimedia, development tools
- **work**: Work-focused profile with development tools but minimal virtualization
- **server**: Minimal server profile with most desktop features disabled
- All profiles share common base configuration and can be extended independently

### Hardware Configuration
Each profile requires its own `hardware-configuration.nix` that must be updated for the target hardware before installation.
