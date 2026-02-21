{ ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    programs.yazi.shellWrapperName = "y";
    keymap = {
      mgr.prepend_keymap = [
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
          on = "<Enter>";
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
          on = [
            "g"
            "s"
          ];
          for = "unix";
          run = ''shell 'kc-share "$@"' --confirm'';
          desc = "Share selected files via KDEConnect";
        }
        {
          on = "!";
          for = "unix";
          run = ''shell "$SHELL" --block'';
          desc = "Open $SHELL here";
        }
        {
          on = [
            "'"
            "h"
          ];
          run = "cd ~";
          desc = "Go home";
        }
        {
          on = [
            "'"
            "a"
          ];
          run = "cd /run/media/s1n7ax";
          desc = "Go mounts";
        }
        {
          on = [
            "'"
            "c"
          ];
          run = "cd ~/.config";
          desc = "Go ~/.config";
        }
        {
          on = [
            "'"
            "l"
          ];
          run = "cd ~/.local";
          desc = "Go ~/.local";
        }
        {
          on = [
            "'"
            "d"
          ];
          run = "cd ~/.cache";
          desc = "Go ~/.cache";
        }
        {
          on = [
            "'"
            "d"
          ];
          run = "cd ~/Downloads";
          desc = "Go ~/Downloads";
        }
        {
          on = [
            "'"
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
