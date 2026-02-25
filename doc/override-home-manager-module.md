# Overriding Home-Manager Modules with a Specific Commit

When a home-manager module has issues or you need a newer version of a specific module without updating all flakes.

## 1. Add a pinned home-manager input in `flake.nix`

```nix
inputs = {
  home-manager = {
    url = "github:nix-community/home-manager/master";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # Pinned version for specific module
  home-manager-pinned = {
    url = "github:nix-community/home-manager/<COMMIT_HASH>";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

## 2. In the module file, import the pinned version and disable the original

```nix
{
  config,
  lib,
  inputs,
  ...
}:
{
  # Import module from pinned home-manager
  imports = [
    "${inputs.home-manager-pinned}/modules/programs/<module-name>.nix"
  ];

  # Disable the module from main home-manager to avoid conflicts
  disabledModules = [
    "programs/<module-name>.nix"
  ];

  config = lib.mkIf config.features.<feature>.enable {
    programs.<module-name> = {
      # ... configuration
    };
  };
}
```

## Example

See `system/home-manager/packages/dev/ai/claude.nix` for claude-code module from commit `91be7cc`.
