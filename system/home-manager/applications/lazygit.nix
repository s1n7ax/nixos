{ lib, config, ... }:
lib.mkIf config.features.cli.lazygit.enable {
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        scrollHeight = 1;
        skipNoStagedFilesWarning = true;
        showIcons = true;
        # status panel omitted to hide it; jump keys 1-4 map to these in order
        sidePanels = [
          [
            "files"
            "worktrees"
            "submodules"
          ]
          [
            "branches"
            "remotes"
            "tags"
          ]
          [
            "commits"
            "reflog"
          ]
          [ "stash" ]
        ];
      };
      git = {
        mainBranches = [ "main" ];
        disableForcePushing = true;
      };
      keybinding = {
        universal = {
          prevItem = "e";
          nextItem = "n";
          # only number keys (jumpToBlock) switch panels; the deprecated
          # *-alt keys are merged into prevBlock/nextBlock, so disable them too
          prevBlock = "<disabled>";
          nextBlock = "<disabled>";
          prevBlock-alt = "<disabled>";
          nextBlock-alt = "<disabled>";
          prevBlock-alt2 = "<disabled>";
          nextBlock-alt2 = "<disabled>";

          nextMatch = "k";
          prevMatch = "K";
          edit = "E";
        };

        files = {
          ignoreFile = "I";
        };

        branches = {
          viewGitFlowOptions = "I";
        };

        submodules = {
          init = "I";
        };
      };
    };
  };
}
