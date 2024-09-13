{ ... }:
{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true; # makes pipewire the default audio server
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [
          "sbc-xq"
          "aac"
        ];
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
        ];
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = false;
        "bluez5.enable-hw-volume" = true;
      };
    };
  };
}
