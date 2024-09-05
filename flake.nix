{
  description = "My NixOS Configuration";

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      devenv,
      home-manager,
      neovim-nightly-overlay,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-stable = import nixpkgs-stable { inherit system; };
      pkgs-devenv = import devenv { inherit system; };

      settings = {
        username = "s1n7ax";
        shell = "zsh";
        wm = {
          name = "hyprland";
          package = pkgs.hyprland;
        };
        cursor = {
          name = "Bibata-Modern-Ice";
          package = pkgs.bibata-cursors;
          size = 32;
        };
        font = {
          name = "JetBrainsMonoNL Nerd Font Mono";
          size = "28";
        };
        icon = {
          name = "Tela-circle-dark";
          package = pkgs.tela-circle-icon-theme;
        };
      };
      extraSpecialArgs = {
        inherit
          inputs
          pkgs-stable
          pkgs-devenv
          settings
          ;
      };
    in
    {
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit system;

          modules = [
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
          specialArgs = {
            inherit pkgs-stable settings;
          };
        };

        work = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit system;

          modules = [
            ./profile/work/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                useUserPackages = true;
                users.s1n7ax = import ./profile/work/home.nix;
              };
            }
          ];
          specialArgs = {
            inherit pkgs-stable settings;
          };
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-my.url = "github:s1n7ax/nix-flakes";
    devenv.url = "github:cachix/devenv";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };
}
