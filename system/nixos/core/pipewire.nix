{ config, lib, ... }:

with lib;

{
  security.rtkit.enable = mkIf config.features.hardware.audio.enable true;

  services.pipewire = mkIf config.features.hardware.audio.enable {
    enable = true;
    audio.enable = true; # makes pipewire the default audio server
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    wireplumber.extraConfig.bluetoothEnhancements = {
      /**
        Keep A2DP even when an app opens the mic; HFP is only registered so
        headsets can reconnect on power-on.
      */
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [
          "sbc-xq"
          "aac"
        ];
        /**
          Headsets reconnect on power-on over HFP/HSP first, so the AG roles
          must be registered or bluez rejects the connection.
        */
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
          "hfp_ag"
          "hsp_ag"
        ];
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = false;
        "bluez5.enable-hw-volume" = true;
      };
    };
  };
}
