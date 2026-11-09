# Flake check: shellchecks setup.sh and runs it against a throwaway HOME and a
# local copy of the skills and agents (see test.sh).
{
  runCommand,
  git,
  python3,
  shellcheck,
}:
runCommand "claude-cloud-setup-check"
  {
    nativeBuildInputs = [
      git
      python3
      shellcheck
    ];
  }
  ''
    shellcheck ${../.}/cloud/setup.sh ${../.}/cloud/test.sh
    bash ${../.}/cloud/test.sh
    touch $out
  ''
