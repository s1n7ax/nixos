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
