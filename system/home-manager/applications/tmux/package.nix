/**
  tmux-workspace: one tmux session of project workspaces on this machine and
  SSH hosts, remembered across restarts (see workspace.sh). ssh comes from
  PATH, so the user's own ssh and its config are used.

  The tools go in $tools rather than runtimeInputs: runtimeInputs would put
  them in front of PATH before the script could keep the user's PATH for the
  tmux server and the workspace shells.
*/
{
  lib,
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
  text = ''
    tools=${
      lib.makeBinPath [
        coreutils
        findutils
        fzf
        gnused
        tmux
        util-linux
      ]
    }
  ''
  + builtins.readFile ./workspace.sh;
}
