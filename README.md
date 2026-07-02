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
# Run darwin-rebuild straight from the nix-darwin flake to install it.
# --extra-experimental-features is required if nix-command/flakes aren't
# already enabled in the stock macOS Nix install.
sudo nix run --extra-experimental-features 'nix-command flakes' \
  nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/nixos#macbook
```

After the first successful switch, `darwin-rebuild` is installed at
`/run/current-system/sw/bin`. Subsequent rebuilds:

`sudo` strips the Nix directories from `PATH` via `secure_path`, so a plain
`sudo darwin-rebuild` fails with `command not found`. Invoke it by full path:

```shell
# Build and switch to the macbook profile
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook

# Build the macbook configuration without switching
sudo /run/current-system/sw/bin/darwin-rebuild build --flake ~/nixos#macbook

# Check what would change (dry run)
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook --dry-run
```

> **Note:** the `--flake ~/nixos#macbook` argument is required. A bare
> `darwin-rebuild switch` defaults to the flake at `/etc/nix-darwin` keyed by
> hostname and will fail with a missing-`darwinConfigurations` attribute error.

##### Dev VM (linux-builder)

`microvm.nix` can't run on macOS, so the macbook profile repurposes nix-darwin's
`linux-builder` (an aarch64-linux NixOS VM) as a headless dev box. A dedicated
`s1n7ax` user inside the VM runs the same home-manager feature set as the Linux
`dev-vm`, except **Claude Code is replaced by the Cursor CLI** (`cursor-agent`).
The `builder` user is left untouched for Nix remote builds; dev tooling lives in
the VM, not on the macOS host.

> **Bootstrap caveat:** a customized `linux-builder` must be built by an
> *already-running* Linux builder. Run the normal switch while the current
> builder is up so it builds its own replacement:
>
> ```shell
> sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook
> ```
>
> If the builder ever can't rebuild itself, set `nix.linux-builder.enable =
> false`, switch, then re-enable it and switch again.

The VM runs as a launchd daemon after a switch — no manual start needed. Log in
as the dev user (find the port in `/etc/ssh/ssh_config.d/*linux-builder*`,
default `31022`):

```shell
# First login uses the password `changeme` — change it, or add an SSH key.
ssh -p 31022 s1n7ax@localhost
```

Inside the VM `cursor-agent`, `nvim`, `fish`, `git`, `docker`, and the language
toolchains are all available.

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
