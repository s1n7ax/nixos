{ config, ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;

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
        fsmonitor = true;
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
}
