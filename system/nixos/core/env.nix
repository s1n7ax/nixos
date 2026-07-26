{ config, ... }:
{
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    EDITOR = "nvim";
    TERM = config.settings.terminal;
  };
}
