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
            {
              features = {
                desktop.enable = true;
                desktop.hyprland.enable = true;
                desktop.xdg.enable = true;
                desktop.kdeconnect.enable = true;
                security.gpg.enable = true;
                hardware.bluetooth.enable = true;
                hardware.audio.enable = true;
                hardware.openrgb.enable = true;
                development.virtualbox.enable = true;
                development.virt-manager.enable = true;
                services.enable = true;
                storage.cloud.enable = true;
                network.ssh.enable = true;
              };
            }
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

        work = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit system;
          inherit specialArgs;

          modules = [
            ./system/options.nix
            ./profile/work/configuration.nix
            {
              features = {
                desktop.enable = true;
                desktop.hyprland.enable = true;
                desktop.xdg.enable = true;
                desktop.kdeconnect.enable = true;
                security.gpg.enable = true;
                hardware.bluetooth.enable = true;
                hardware.audio.enable = true;
                hardware.openrgb.enable = true;
                development.virtualbox.enable = false;
                development.virt-manager.enable = false;
                services.enable = true;
                storage.cloud.enable = true;
                network.ssh.enable = true;
              };
            }
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
        };

        server = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          inherit system;
          inherit specialArgs;

          modules = [
            ./system/options.nix
            ./profile/server/configuration.nix
            {
              features = {
                desktop.enable = false;
                desktop.hyprland.enable = false;
                desktop.xdg.enable = false;
                desktop.kdeconnect.enable = false;
                security.gpg.enable = false;
                hardware.bluetooth.enable = false;
                hardware.audio.enable = false;
                hardware.openrgb.enable = false;
                development.virtualbox.enable = false;
                development.virt-manager.enable = false;
                services.enable = false;
                storage.cloud.enable = false;
                network.ssh.enable = true;
              };
            }
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
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };
}
