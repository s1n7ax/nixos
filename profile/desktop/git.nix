{ settings, ... }:
{
  programs.git = {
    enable = true;
    difftastic = {
      enable = true;
      display = "inline";
    };
    lfs.enable = true;

    userName = settings.username;
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
