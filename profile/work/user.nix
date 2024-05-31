{ pkgs, settings, ... }:
let username = "s1n7ax";
in {
  networking.hostName = "s1n7ax";
  time.timeZone = settings.timezone;

  users.groups.${username} = { };
  users.users.${username} = {
    shell = pkgs.${settings.shell};
    isNormalUser = true;
    group = username;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "pipewire" "docker" ];
    packages = with pkgs; [ qt6.qtwayland pass-wayland swaybg home-manager ];
  };
}
