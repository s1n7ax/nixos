/**
  remote-agent: opens the remote-agent app and drives its tailnet connection
  (see remote-agent.sh). The tools are arguments so the flake check can swap
  tailscale, Chrome, notify-send and xdg-open for fakes.
*/
{
  lib,
  writeShellApplication,
  coreutils,
  gnused,
  jq,
  procps,
  util-linux,
  libnotify,
  xdg-utils,
  tailscale,
  google-chrome,
  url,
  hostname,
  proxyPort,
  connectTimeout ? 15,
  barSignal ? 8,
}:
writeShellApplication {
  name = "remote-agent";
  runtimeInputs = [
    coreutils
    gnused
    jq
    procps
    util-linux
    libnotify
    xdg-utils
    tailscale
    google-chrome
  ];
  text = ''
    export REMOTE_AGENT_URL=${lib.escapeShellArg url}
    export REMOTE_AGENT_PROXY=socks5://127.0.0.1:${toString proxyPort}
    export REMOTE_AGENT_HOSTNAME=${lib.escapeShellArg hostname}
    export REMOTE_AGENT_CONNECT_TIMEOUT=${toString connectTimeout}
    export REMOTE_AGENT_BAR_SIGNAL=${toString barSignal}
  ''
  + builtins.readFile ./remote-agent.sh;
}
