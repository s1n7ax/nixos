{
  description = "My NixOS Configuration";

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      sops-nix,
      quadlet-nix,
      microvm,
      nix-darwin,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      darwinPlatform = "aarch64-darwin";

      importPkgs =
        nixpkgsInput: targetSystem:
        import nixpkgsInput {
          system = targetSystem;
          config.allowUnfree = true;
        };

      pkgs = importPkgs nixpkgs system;

      pkgs-unstable = importPkgs nixpkgs-unstable system;

      args = {
        inherit inputs pkgs-unstable;
      };
      specialArgs = args;
      extraSpecialArgs = args;

      darwinArgs = {
        inherit inputs;
        pkgs-unstable = importPkgs nixpkgs-unstable darwinPlatform;
      };
    in
    {
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit specialArgs;

          modules = [
            ./system/options.nix
            ./profile/desktop/configuration.nix
            quadlet-nix.nixosModules.quadlet
            microvm.nixosModules.host
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                useUserPackages = true;
                users.s1n7ax = import ./profile/desktop/home.nix;
              };
            }
          ];
        };

        server = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit specialArgs;

          modules = [
            ./system/options.nix
            ./profile/server/configuration.nix
            quadlet-nix.nixosModules.quadlet
            microvm.nixosModules.host
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                useUserPackages = true;
                users.s1n7ax = import ./profile/server/home.nix;
              };
            }
          ];
        };
      };

      darwinConfigurations = {
        macbook = nix-darwin.lib.darwinSystem {
          specialArgs = darwinArgs;

          modules = [
            ./profile/macbook/configuration.nix
          ];
        };
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    hardware.url = "github:nixos/nixos-hardware";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/s1n7ax/nix-secrets.git?ref=main&shallow=1";
      flake = false;
    };
  };
}
