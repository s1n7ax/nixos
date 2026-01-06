{ ... }:
{
  networking.networkmanager.enable = true;

  networking.networkmanager.ensureProfiles.profiles = {
    s1n7ax = {
      connection = {
        id = "s1n7ax";
        type = "wifi";
      };
      wifi = {
        ssid = "s1n7ax";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "testing123";
      };
    };
  };
}
