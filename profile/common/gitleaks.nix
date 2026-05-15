{ pkgs, ... }:
let
  preCommit = pkgs.writeShellScript "gitleaks-pre-commit" ''
    set -e

    if [ "''${GITLEAKS_SKIP:-0}" = "1" ]; then
      exit 0
    fi

    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$repo_root" ] && [ -x "$repo_root/.git/hooks/pre-commit" ]; then
      "$repo_root/.git/hooks/pre-commit" "$@"
    fi

    exec ${pkgs.gitleaks}/bin/gitleaks protect --staged --redact --verbose
  '';

  hooksDir = pkgs.runCommand "global-git-hooks" { } ''
    mkdir -p $out
    ln -s ${preCommit} $out/pre-commit
  '';
in
{
  home.packages = [ pkgs.gitleaks ];

  programs.git.settings.core.hooksPath = "${hooksDir}";
}
