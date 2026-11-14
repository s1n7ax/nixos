/**
  Flake check: runs tmux-workspace (writeShellApplication shellchecks it)
  against a real tmux server, with a fake ssh standing in for the remote
  hosts (see test.sh).
*/
{
  runCommand,
  callPackage,
  procps,
  shellcheck,
  tmux,
}:
runCommand "tmux-workspace-check"
  {
    nativeBuildInputs = [
      (callPackage ./package.nix { })
      procps
      shellcheck
      tmux
    ];
  }
  ''
    shellcheck -s bash ${./test.sh}
    bash ${./test.sh}
    touch $out
  ''
