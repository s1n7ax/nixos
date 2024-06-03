{
  description = "My desktop system";

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }:
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

      #--------------------------------------------------------------------#
      #                              SETTINGS                              #
      #--------------------------------------------------------------------#
      settings = {
        profile = "desktop";
        timezone = "Asia/Colombo";
        shell = "zsh";
        locale = "en_US.UTF-8";
      };
    in
    {
      nixosConfigurations = {
        inherit system;
        s1n7ax = nixpkgs.lib.nixosSystem {
          modules = [ (./. + "/profile" + ("/" + settings.profile) + "/configuration.nix") ];
          specialArgs = {
            inherit
              pkgs
              pkgs-unstable
              home-manager
              settings
              ;
          };
        };
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
}
