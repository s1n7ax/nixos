{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "CodeNewRoman:size=18";
      };

      border.radius = 0;
      key-bindings = {
        prev = "Up Control+t";
        next = "Down Control+n";
      };

      colors = {
        background = "1e1e2eff";
        text = "cdd6f4ff";
        match = "f38ba8ff";
        selection = "585b70ff";
        selection-match = "f38ba8ff";
        selection-text = "cdd6f4ff";
        border = "b4befeff";
      };
    };
  };
}
