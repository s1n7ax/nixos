{
  config,
  lib,
  pkgs,
  ...
}:
let
  data_path = "${config.home.homeDirectory}/.homelab/paperless";
  secret_env = "${data_path}/secret.env";

  # PAPERLESS_SECRET_KEY has no upstream default -- paperless refuses to start
  # without it, and rotating it invalidates every session and API token. The
  # secrets flake is not the right home for a value nothing else consumes and
  # that only this host ever needs, so mint it once on first activation and
  # leave it alone afterwards.
  generateSecretKey = pkgs.writeShellScript "paperless-generate-secret-key" ''
    set -eu
    target="$1"
    if [ -s "$target" ]; then
      exit 0
    fi
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
    umask 077
    # Materialise the key in its own statement and write via a temp file: a
    # failed `openssl` inside the printf arguments would otherwise leave an
    # empty PAPERLESS_SECRET_KEY behind, and the [ -s ] guard above would then
    # treat that empty key as already generated forever after.
    key="$(${pkgs.openssl}/bin/openssl rand -hex 48)"
    [ -n "$key" ]
    ${pkgs.coreutils}/bin/printf 'PAPERLESS_SECRET_KEY=%s\n' "$key" > "$target.tmp"
    ${pkgs.coreutils}/bin/mv -f "$target.tmp" "$target"
  '';
in
with lib;
{
  config = mkIf config.features.homelab.paperless.enable {
    systemd.user.tmpfiles.rules = [
      "d %h/.homelab/paperless 0700 - - -"
      "d %h/.homelab/paperless/data 0700 - - -"
      "d %h/.homelab/paperless/media 0700 - - -"
      "d %h/.homelab/paperless/export 0700 - - -"
      "d %h/.homelab/paperless/redis 0700 - - -"
      # Drop-in target for documents to scan; kept group/world readable so a
      # scanner or another host user can write into it over a share.
      "d %h/.homelab/paperless/consume 0755 - - -"
    ];

    home.activation.paperlessSecretKey = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${generateSecretKey} ${secret_env}
    '';

    services.podman.networks.paperless-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.paperless-redis = {
      image = "docker.io/valkey/valkey:9-alpine";
      network = [ "paperless-network" ];

      volumes = [
        "${data_path}/redis:/data:Z"
      ];

      user = 1000;
      group = 1000;

      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];

      autoStart = true;
    };

    services.podman.containers.paperless = {
      image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
      network = [ "paperless-network" ];

      volumes = [
        "${data_path}/data:/usr/src/paperless/data:Z"
        "${data_path}/media:/usr/src/paperless/media:Z"
        "${data_path}/consume:/usr/src/paperless/consume:Z"
        "${data_path}/export:/usr/src/paperless/export:Z"
      ];

      environmentFile = [ secret_env ];

      environment = {
        PAPERLESS_REDIS = "redis://paperless-redis:6379";
        PAPERLESS_DBENGINE = "sqlite";
        PAPERLESS_URL = "http://192.168.1.110:8000";
        PAPERLESS_TIME_ZONE = "Asia/Colombo";
        PAPERLESS_OCR_LANGUAGE = "eng";
      };

      # Upstream's rootless recipe: run the process directly as the host user
      # instead of letting the image's entrypoint remap UIDs, so everything
      # written to the bind mounts stays owned by that user. USERMAP_UID /
      # USERMAP_GID are the rooted alternative and must not be combined with it.
      user = 1000;
      group = 1000;

      ports = [
        "8000:8000"
      ];

      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];

      # The broker has to answer before the webserver's celery workers connect;
      # podman-paperless-redis.service is the generated unit name for the
      # container above.
      extraConfig = {
        Unit.After = [ "podman-paperless-redis.service" ];
      };

      autoStart = true;
    };
  };
}
