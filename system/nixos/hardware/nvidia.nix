{ lib, config, ... }:
{
  options.package.nvidia.enable = lib.mkEnableOption "Nvidia";

  config = lib.mkIf config.features.hardware.nvidia.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      # GTX 1060 (Pascal) was dropped from the 595.xx "stable" branch in 26.05;
      # 580.xx is the legacy branch that still supports Pascal.
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      powerManagement.enable = true;
    };

    hardware.nvidia-container-toolkit.enable = true;

    services.xserver.videoDrivers = [ "nvidia" ];
    boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
  };
}
