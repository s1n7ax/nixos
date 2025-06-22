{
  description = "My NixOS Configuration";

  outputs =
    {
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      args = {
        inherit
          inputs
          pkgs-stable
          ;
      };
      specialArgs = args;
      extraSpecialArgs = args;
    in
    {
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit system;
          inherit specialArgs;

          modules = [
            ./system/options.nix
            ./profile/desktop/configuration.nix

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
          inherit system;
          inherit specialArgs;

          modules = [
            ./system/options.nix
            ./profile/server/configuration.nix

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
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    hardware.url = "github:nixos/nixos-hardware";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
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
