{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.ghostty.packages.${pkgs.system}.default
  ];

}
