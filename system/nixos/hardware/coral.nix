{ config, ... }:
{
  hardware.coral.pcie.enable = config.features.hardware.coral.enable;
}
