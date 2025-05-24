{ ... }: {
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        scrollHeight = 1;
        skipNoStagedFilesWarning = true;
        showIcons = true;
      };
      git = {
        mainBranches = [ "main" ];
        disableForcePushing = true;
      };
      keybinding = {
        universal = {
          prevItem = "e";
          nextItem = "n";
          prevBlock = "m";
          nextBlock = "i";

          nextMatch = "k";
          prevMatch = "K";
          edit = "E";
        };

        files = { ignoreFile = "I"; };

        branches = { viewGitFlowOptions = "I"; };

        submodules = { init = "I"; };
      };
    };
  };
}
