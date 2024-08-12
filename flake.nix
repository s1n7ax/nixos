{
  description = "My NixOS Configuration";

  outputs =
    { nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      settings = {
        username = "s1n7ax";
      };
    in
    {
      nixosConfigurations = {
        inherit system;

        desktop = nixpkgs.lib.nixosSystem {
          modules = [
            ./profile/common/configuration.nix
            ./profile/desktop/configuration.nix
            ./profile/desktop/filesystem.nix
            ./profile/desktop/hardware-configuration.nix

          ];
          specialArgs = {
            inherit pkgs pkgs-unstable settings;
          };
        };

        work = nixpkgs.lib.nixosSystem {
          modules = [
            ./profile/common/configuration.nix
            ./profile/work/configuration.nix
            ./profile/work/hardware-configuration.nix
          ];
          specialArgs = {
            inherit pkgs pkgs-unstable settings;
          };
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
