{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.package.dev.ide.enable {
    home.packages = with pkgs; [
      zed-editor
    ];

    home.file.".config/zed/keymap.json".text = builtins.toJSON [
      {
        context = "vim_mode == normal || vim_mode == visual";
        bindings = {
          ctrl-q = "pane::CloseActiveItem";
          n = "vim::Down";
          shift-n = "vim::JoinLines";
          e = "vim::Up";
          m = "vim::Left";
          i = "vim::Right";
          h = "vim::InsertBefore";
          shift-h = "vim::InsertFirstNonWhitespace";
          k = "vim::MoveToNextMatch";
          shift-k = "vim::MoveToPrevMatch";
          l = "vim::NextWordEnd";
          shift-l = [
            "vim::NextWordEnd"
            {
              ignorePunctuation = true;
            }
          ];
          j = [
            "vim::PushOperator"
            "Mark"
          ];
          ctrl-m = [
            "workspace::ActivatePaneInDirection"
            "Left"
          ];
          ctrl-i = [
            "workspace::ActivatePaneInDirection"
            "Right"
          ];
          ctrl-e = [
            "workspace::ActivatePaneInDirection"
            "Up"
          ];
          ctrl-n = [
            "workspace::ActivatePaneInDirection"
            "Down"
          ];
          "] space" = "vim::InsertLineBelow";
          ", a" = "workspace::ToggleZoom";
          "shift-i" = "editor::Hover";
          ", ," = "file_finder::Toggle";
          "0" = "vim::FirstNonWhitespace";
          # "shift-y" = [
          #   "vim::PushOperator"
          #   "Yank"
          #   "vim::EndOfLine"
          # ];
        };
      }
      {
        context = "vim_mode == insert";
        bindings = {
          ctrl-v = "vim::Paste";
        };
      }
      {
        context = "BufferSearchBar && !in_replace";
        bindings = {
          ctrl-c = "buffer_search::Dismiss";
        };
      }
      {
        context = "vim_operator == y";
        bindings = {
          l = "vim::NextWordEnd";
        };
      }
    ];
  };
}
