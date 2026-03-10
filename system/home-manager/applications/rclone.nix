{
  lib,
  config,
  ...
}:

let
  username = config.settings.username;
  cfg = config.features.storage;
in

lib.mkMerge [
  (lib.mkIf cfg.dropbox.enable {
    sops.secrets."rclone/dropbox/token" = { };
    programs.rclone = {
      enable = true;
      remotes."dropbox" = {
        config = {
          type = "dropbox";
        };
        mounts."" = {
          enable = true;
          mountPoint = "/home/${username}/Storage/dropbox";
        };
        secrets = {
          token = config.sops.secrets."rclone/dropbox/token".path;
        };
      };
    };
  })

  (lib.mkIf cfg.googlePhotos.enable {
    sops.secrets."rclone/google-photos/token" = { };
    programs.rclone = {
      enable = true;
      remotes."google-photos" = {
        config = {
          type = "google photos";
        };
        mounts."" = {
          enable = true;
          mountPoint = "/home/${username}/Storage/photos";
        };
        secrets = {
          token = config.sops.secrets."rclone/google-photos/token".path;
        };
      };
    };
  })
]
