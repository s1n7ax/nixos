/**
  tmux-workspace: one tmux session of project workspaces on this machine and
  SSH hosts, remembered across restarts (see workspace.sh). ssh comes from
  PATH, so the user's own ssh and its config are used.
*/
{
  writeShellApplication,
  coreutils,
  findutils,
  fzf,
  gnused,
  tmux,
  util-linux,
}:
writeShellApplication {
  name = "tmux-workspace";
  runtimeInputs = [
    coreutils
    findutils
    fzf
    gnused
    tmux
    util-linux
  ];
  text = builtins.readFile ./workspace.sh;
}
