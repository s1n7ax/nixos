{ pkgs, settings, ... }:
let
  username = "s1n7ax";
in
{
  networking.hostName = username;
  time.timeZone = settings.timezone;
  programs.zsh.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "si_LK/UTF-8" ];
  };

  users.users.${username} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    group = username;
    extraGroups = [
      "audio"
      "docker"
      "libvirtd"
      "network"
      "networkmanager"
      "pipewire"
      "plugdev"
      "podman"
      "video"
      "wheel"
      "adbusers"
    ];
  };

  users.groups.${username} = { };

  environment.systemPackages = [ pkgs.home-manager ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
