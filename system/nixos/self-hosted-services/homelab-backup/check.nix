# Flake check: runs homelab-backup against fake service data in the sandbox
# (see test.sh).
{
  runCommand,
  callPackage,
  age,
  gnutar,
  jq,
  openssh,
  python3,
  sops,
  sqlite,
  ssh-to-age,
  zstd,
}:
runCommand "homelab-backup-check"
  {
    nativeBuildInputs = [
      (callPackage ./package.nix { })
      age
      gnutar
      jq
      openssh
      python3
      sops
      sqlite
      ssh-to-age
      zstd
    ];
  }
  ''
    bash ${./test.sh}
    touch $out
  ''
