{ ... }: {
  programs.zathura = {
    enable = true;
    mappings = {
      "f" = "toggle_fullscreen";
      "[fullscreen] f" = "toggle_fullscreen";

      "n" = "scroll down";
      "e" = "scroll up";
      "[fullscreen] n" = "scroll down";
      "[fullscreen] e" = "scroll up";

      "<C-n>" = "zoom out";
      "<C-e>" = "zoom in";
      "[fullscreen] <C-n>" = "zoom out";
      "[fullscreen] <C-e>" = "zoom in";
    };
    options = {
      font = "FiraCode";
      default-bg = "#1c1c1c";
      default-fg = "#e0e0e0";

      statusbar-fg = "#B0B0B0";
      statusbar-bg = "#202020";

      inputbar-bg = "#151515";
      inputbar-fg = "#FFFFFF";

      notification-error-bg = "#AC4142";
      notification-error-fg = "#151515";

      notification-warning-bg = "#AC4142";
      notification-warning-fg = "#151515";

      highlight-color = "#F4BF75";
      highlight-active-color = "#6A9FB5";

      completion-highlight-fg = "#151515";
      completion-highlight-bg = "#90A959";

      completion-bg = "#303030";
      completion-fg = "#E0E0E0";

      notification-bg = "#90A959";
      notification-fg = "#151515";

      recolor = "true";
      recolor-lightcolor = "#1f1f1f";
      recolor-darkcolor = "#E0E0E0";
      recolor-reverse-video = "true";
      recolor-keephue = "true";
    };
  };
}
