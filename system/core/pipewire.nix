{ ... }: {
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;

    wireplumber.enable = true;

    alsa.support32Bit = true;
  };
}
