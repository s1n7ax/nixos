{
  config,
  lib,
  pkgs,
  ...
}:
let
  data_path = "${config.home.homeDirectory}/.homelab/paperless";
  secret_env = "${data_path}/secret.env";

  # Single source of truth for the layout: the same paths feed the tmpfiles
  # rules below and the bind mounts further down, so the two cannot drift.
  paths = {
    data = "${data_path}/data";
    media = "${data_path}/media";
    consume = "${data_path}/consume";
    export = "${data_path}/export";
    redis = "${data_path}/redis";
  };

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
    # Before the mkdir, so the directory holding the key is never briefly
    # world-readable when activation wins the race against systemd-tmpfiles.
    umask 077
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
    trap '${pkgs.coreutils}/bin/rm -f "$target.tmp"' EXIT
    # Materialise the key in its own statement and write via a temp file: a
    # failed `openssl` inside the printf arguments would otherwise leave an
    # empty PAPERLESS_SECRET_KEY behind, and the [ -s ] guard above would then
    # treat that empty key as already generated forever after.
    key="$(${pkgs.openssl}/bin/openssl rand -hex 48)"
    if [ -z "$key" ]; then
      echo "paperless: openssl produced an empty secret key, refusing to write $target" >&2
      exit 1
    fi
    ${pkgs.coreutils}/bin/printf 'PAPERLESS_SECRET_KEY=%s\n' "$key" > "$target.tmp"
    ${pkgs.coreutils}/bin/mv -f "$target.tmp" "$target"
  '';
in
with lib;
{
  config = mkIf config.features.homelab.paperless.enable {
    systemd.user.tmpfiles.rules = map (p: "d ${p} 0700 - - -") ([ data_path ] ++ attrValues paths);

    # Must land before reloadSystemd: that is what starts the container units,
    # and podman-paperless.service dies on a missing EnvironmentFile. Plain
    # entryAfter "writeBoundary" leaves the two unordered siblings.
    home.activation.paperlessSecretKey = hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${generateSecretKey} ${secret_env}
    '';

    services.podman.networks.paperless-network = {
      autoStart = true;
      driver = "bridge";
    };

    services.podman.containers.paperless-redis = {
      image = "docker.io/valkey/valkey:9-alpine";
      # The `.network` suffix is what makes the home-manager module emit the
      # Wants=/After= on podman-paperless-network.service; a bare name is
      # passed through untouched and leaves the units unordered.
      network = [ "paperless-network.network" ];

      volumes = [
        "${paths.redis}:/data:Z"
      ];

      # No User=/Group=: --userns=keep-id already defaults the container
      # process to the host user's own uid:gid, which is what keeps files on
      # the bind mounts owned by that user. Naming a gid here would pick one
      # keep-id does not map (the host's primary group is not 1000).
      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];

      autoStart = true;
    };

    services.podman.containers.paperless = {
      # Pinned rather than :latest -- this owns a SQLite database that a major
      # version bump migrates in place, with no way back.
      image = "ghcr.io/paperless-ngx/paperless-ngx:3.1.3";
      network = [ "paperless-network.network" ];

      volumes = [
        "${paths.data}:/usr/src/paperless/data:Z"
        "${paths.media}:/usr/src/paperless/media:Z"
        "${paths.consume}:/usr/src/paperless/consume:Z"
        "${paths.export}:/usr/src/paperless/export:Z"
      ];

      environmentFile = [ secret_env ];

      environment = {
        PAPERLESS_REDIS = "redis://paperless-redis:6379";
        PAPERLESS_DBENGINE = "sqlite";
        PAPERLESS_URL = "http://192.168.1.110:8000";
        # PAPERLESS_URL alone would make that one IP the whole of Django's
        # ALLOWED_HOSTS, so reaching the service from the server itself 400s.
        PAPERLESS_ALLOWED_HOSTS = "192.168.1.110,localhost,127.0.0.1";
        PAPERLESS_TIME_ZONE = "Asia/Colombo";
        PAPERLESS_OCR_LANGUAGE = "eng";
      };

      ports = [
        "8000:8000"
      ];

      # Upstream's rootless recipe: keep-id runs the process directly as the
      # host user (see the broker above) rather than letting the image's
      # entrypoint remap UIDs. USERMAP_UID / USERMAP_GID are the rooted
      # alternative and must not be combined with it.
      extraPodmanArgs = [
        "--userns=keep-id"
        "--tz=local"
      ];

      # Wants= as well as After=: ordering alone would let a manual restart of
      # this unit bring the webserver up without the broker, and the image's
      # init-wait-for-redis step then blocks forever instead of failing.
      extraConfig = {
        Unit = {
          Wants = [ "podman-paperless-redis.service" ];
          After = [ "podman-paperless-redis.service" ];
        };
      };

      autoStart = true;
    };
  };
}
