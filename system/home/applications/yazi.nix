{ ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    keymap = {
      manager.prepend_keymap = [
        {
          on = "n";
          run = "arrow -1";
          desc = "Move cursor up";
        }
        {
          on = "e";
          run = "arrow 1";
          desc = "Move cursor down";
        }
      ];
    };
  };
}
