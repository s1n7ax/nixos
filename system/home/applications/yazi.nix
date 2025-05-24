{ ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    keymap = {
      manager.prepend_keymap = [
        {
          on = "n";
          run = "arrow 1";
          desc = "Move cursor up";
        }
        {
          on = "e";
          run = "arrow -1";
          desc = "Move cursor down";
        }
        {
          on = "m";
          run = "back";
          desc = "Go back";
        }
        {
          on = "i";
          run = "enter";
          desc = "Enter directory";
        }
        # {
        #   on = "l";
        #   run = "open";
        #   desc = "Open file or directory";
        # }
        # {
        #   on = "c";
        #   run = "copy";
        #   desc = "Copy file or directory";
        # }
        # {
        #   on = "v";
        #   run = "paste";
        #   desc = "Paste file or directory";
        # }
        # {
        #   on = "d";
        #   run = "delete";
        #   desc = "Delete file or directory";
        # }
      ];
    };
  };
}
