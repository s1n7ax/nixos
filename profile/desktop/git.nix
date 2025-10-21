{ config, ... }:
{
  programs.git = {
    enable = true;
    difftastic = {
      enable = true;
      display = "side-by-side";
    };
    lfs.enable = true;

    userName = config.settings.username;
    userEmail = "srineshnisala@gmail.com";
    signing.key = "srineshnisala@gmail.com";
    signing.signByDefault = true;

    extraConfig = {
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
}
