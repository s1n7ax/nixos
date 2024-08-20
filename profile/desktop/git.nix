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
    signing.key = "168D1103741F3CE3862B4F4BB0F715E8C4A30F1E";
    signing.signByDefault = true;

    extraConfig = {
      core = {
        untrackedcache = true;
        fsmonitor = true;
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
    };
  };
}
