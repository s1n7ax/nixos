# Flake check: shellchecks setup.sh and runs it against a throwaway HOME and a
# local copy of the skills and agents (see test.sh). awk is mawk, as on the
# cloud VM's Ubuntu, so the agent conversion is tested with the awk it gets.
{
  runCommand,
  git,
  mawk,
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
    mkdir bin
    ln -s ${mawk}/bin/mawk bin/awk
    export PATH=$PWD/bin:$PATH
    cp -r ${../.} ai
    chmod -R u+w ai
    shellcheck ai/cloud/setup.sh ai/cloud/test.sh
    bash ai/cloud/test.sh "$PWD/ai"
    touch $out
  ''
