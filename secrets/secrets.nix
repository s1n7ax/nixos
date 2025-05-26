let
  publicKeys = import ../system/nixos/constants/ssh-public-keys.nix;
  desktop = publicKeys.desktop;
  users = [
    desktop
  ];
in
{
  "secret1.age".publicKeys = users;
}
