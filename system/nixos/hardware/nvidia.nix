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
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    hardware.nvidia-container-toolkit.enable = true;

    services.xserver.videoDrivers = [ "nvidia" ];
    boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
  };
}
