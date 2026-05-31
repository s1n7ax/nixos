{ pkgs, ... }:
{
  xdg.configFile."nvim".source = pkgs.fetchFromGitHub {
    owner = "s1n7ax";
    repo = "nvim";
    rev = "5533d4e36e7a456a8af781e439488b97fa4aed1d";
    hash = "sha256-Kh70YogU06Fe93/w627mquQ0meWMHADk7oNmOdF6SHU=";
  };
}
