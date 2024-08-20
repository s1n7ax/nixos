{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;

    font = {
      name = "Maple Mono NF";
      size = 18;
      package = pkgs.maple-mono-NF;
    };
    settings = {
      "ctrl+c" = "copy_or_interrupt";
      "cursor_blink_interval" = 0;
    };
    theme = "Catppuccin-Mocha";
    shellIntegration.enableZshIntegration = true;
  };
}
