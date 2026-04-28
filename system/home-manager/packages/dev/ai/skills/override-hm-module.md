---
name: override-hm-module
description: Override a home-manager module with a specific commit. Use when a module has bugs or missing features and you need a newer version without updating all flakes.
---

# Override Home-Manager Module

## Steps

1. Add pinned input in `flake.nix`:
```nix
home-manager-<name> = {
  url = "github:nix-community/home-manager/<COMMIT_HASH>";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

2. In the module file:
```nix
{
  inputs,
  ...
}:
{
  imports = [
    "${inputs.home-manager-<name>}/modules/programs/<module>.nix"
  ];

  disabledModules = [
    "programs/<module>.nix"
  ];

  # ... rest of config
}
```
