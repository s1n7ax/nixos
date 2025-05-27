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
          run = "leave";
          desc = "Go back";
        }
        {
          on = "i";
          run = "enter";
          desc = "Enter directory";
        }
        {
          on = "<cr>";
          run = "enter";
          desc = "Enter directory";
        }
        {
          on = "<c-q>";
          run = "quit";
          desc = "Quit";
        }
        {
          on = "s";
          run = "search --via=rg";
          desc = "Search files by content via ripgrep";
        }
        {
          on = "!";
          for = "unix";
          run = ''shell "$SHELL" --block'';
          desc = "Open $SHELL here";
        }
        {
          on = [
            "g"
            "h"
          ];
          run = "cd ~";
          desc = "Go home";
        }
        {
          on = [
            "g"
            "c"
          ];
          run = "cd ~/.config";
          desc = "Go ~/.config";
        }
        {
          on = [
            "g"
            "d"
          ];
          run = "cd ~/Downloads";
          desc = "Go ~/Downloads";
        }
        {
          on = [
            "g"
            "<Space>"
          ];
          run = "cd --interactive";
          desc = "Jump interactively";
        }
        {
          on = [
            "g"
            "f"
          ];
          run = "follow";
          desc = "Follow hovered symlink";
        }
      ];
      pick.prepend_keymap = [
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
      ];
    };
  };
}
