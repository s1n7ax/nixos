/**
  Flake check: runs remote-agent (writeShellApplication shellchecks it)
  against a fake tailscale, Chrome, notify-send and xdg-open (see test.sh).
*/
{
  runCommand,
  callPackage,
  writeShellScriptBin,
  jq,
  shellcheck,
}:
let
  # tailscale --socket=<path> <command>: state in $FAKE_DIR/state (a
  # BackendState, or Unreachable), every call logged to $FAKE_DIR/calls.
  # `up` fails while $FAKE_DIR/up-fails exists; in NeedsLogin it only
  # reports a login URL, like the real one waiting for the sign-in.
  tailscale = writeShellScriptBin "tailscale" ''
    echo "$*" >>"$FAKE_DIR/calls"
    case $1 in
      --socket=*/tailscale/tailscaled.sock) shift ;;
      *) echo "fake tailscale: no --socket" >&2; exit 9 ;;
    esac
    state=$(cat "$FAKE_DIR/state")
    case $1 in
      status)
        if [ "$state" = Unreachable ]; then
          echo "failed to connect to local tailscaled" >&2
          exit 1
        fi
        printf '{"BackendState":"%s","AuthURL":"%s"}\n' "$state" "$(cat "$FAKE_DIR/authurl" 2>/dev/null)"
        ;;
      up)
        if [ "$state" = NeedsLogin ]; then
          echo https://login.tailscale.com/a/fake >"$FAKE_DIR/authurl"
          exit 0
        fi
        if [ -f "$FAKE_DIR/up-fails" ]; then
          printf 'backend error: no internet\n\n' >&2
          exit 1
        fi
        echo Running >"$FAKE_DIR/state"
        ;;
      down) echo Stopped >"$FAKE_DIR/state" ;;
    esac
  '';

  google-chrome = writeShellScriptBin "google-chrome-stable" ''
    printf '%s\n' "$@" >"$FAKE_DIR/chrome"
  '';

  libnotify = writeShellScriptBin "notify-send" ''
    echo "$*" >>"$FAKE_DIR/notify"
  '';

  xdg-utils = writeShellScriptBin "xdg-open" ''
    echo "$1" >"$FAKE_DIR/opened"
  '';
in
runCommand "remote-agent-check"
  {
    nativeBuildInputs = [
      (callPackage ./package.nix {
        inherit
          tailscale
          google-chrome
          libnotify
          xdg-utils
          ;
        url = "https://remote-agent.example.ts.net";
        hostname = "desktop";
        proxyPort = 1055;
        connectTimeout = 2;
      })
      jq
      shellcheck
    ];
  }
  ''
    shellcheck -s bash ${./test.sh}
    bash ${./test.sh}
    touch $out
  ''
