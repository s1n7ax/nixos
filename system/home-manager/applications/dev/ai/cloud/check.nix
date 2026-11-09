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
    cp -r ${../.} ai
    chmod -R u+w ai
    shellcheck ai/cloud/setup.sh ai/cloud/test.sh
    bash ai/cloud/test.sh "$PWD/ai"
    touch $out
  ''
