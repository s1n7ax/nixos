{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.git.enable {
    programs.git = {
      enable = true;
      lfs.enable = true;

      ignores = [
        ".claude/worktrees/"
        ".ship/"
      ];

      settings = {
        user = {
          name = config.settings.username;
          email = "srineshnisala@gmail.com";
        };
        signing = {
          key = "srineshnisala@gmail.com";
          signByDefault = true;
        };
        core = {
          untrackedcache = true;
          # Linux's inotify daemon cold-starts per repo slowly enough to time out prompt git calls.
          fsmonitor = pkgs.stdenv.isDarwin;
          compression = 0;
        };
        init = {
          defaultBranch = "main";
        };
        pull = {
          rebase = true;
        };
        push = {
          autoSetupRemote = true;
        };
        safe = {
          directory = [ "/etc/nixos" ];
        };
        maintainance = {
          auto = false;
          strategy = "incremental";
        };
        http = {
          lowSpeedLimit = 1;
          lowSpeedTime = 500;
        };
      };
    };

    programs.difftastic = {
      enable = true;
      git.enable = true;
      options = {
        display = "side-by-side";
      };
    };
  };
}
