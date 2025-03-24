{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "NixOS";
        bookmarks = [
          {
            name = "Nix";
            bookmarks = [
              {
                name = "Writers | Nix";
                tags = [ "nix" ];
                url = "https://ryantm.github.io/nixpkgs/builders/trivial-builders/#trivial-builder-writeText";
              }
              {
                name = "NixOS Options";
                tags = [ "nix" ];
                url = "https://search.nixos.org/options";
              }
              {
                name = "NixOS Packages";
                tags = [ "nix" ];
                url = "https://search.nixos.org/packages";
              }
              {
                name = "Overriding | Nix";
                tags = [ "nix" ];
                url = "https://ryantm.github.io/nixpkgs/using/overrides/#chap-overrides";
              }
              {
                name = "makeWrapper | Nix";
                tags = [ "nix" ];
                url = "https://gist.github.com/CMCDragonkai/9b65cbb1989913555c203f4fa9c23374";
              }
              {
                name = "Fetchers | Nix";
                tags = [ "nix" ];
                url = "https://ryantm.github.io/nixpkgs/builders/fetchers/";
              }
              {
                name = "Home Manager Options";
                tags = [ "nix" ];
                url = "https://home-manager-options.extranix.com/";
              }
            ];
          }
        ];
      }
    ];
  };
}
