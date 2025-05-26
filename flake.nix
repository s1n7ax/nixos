{
  description = "My NixOS Configuration";

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      settings = {
        username = "s1n7ax";
        shell = "fish";
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
          name = "Iosevka Nerd Font Mono";
          size = 18;
        };
        icon = {
          name = "Tela-circle-dark";
          package = pkgs.tela-circle-icon-theme;
        };
        terminal = "kitty";
      };
      args = {
        inherit
          inputs
          settings
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
            inputs.agenix.nixosModules.default

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${settings.username} = import ./profile/desktop/home.nix;
                sharedModules = [
                  inputs.agenix.homeManagerModules.default
                ];
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
            inputs.agenix.nixosModules.default

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                inherit extraSpecialArgs;
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${settings.username} = import ./profile/server/home.nix;
              };
            }
          ];
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    agenix.url = "github:ryantm/agenix";
  };
}
