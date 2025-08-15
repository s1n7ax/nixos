{ settings, ... }:
{
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    EDITOR = "nvim";
    TERM = settings.terminal;
  };
}
