# Flake check: runs homelab-backup and homelab-restore against fake service
# data in the sandbox (see test.sh).
{
  runCommand,
  callPackage,
  age,
  fakeroot,
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
      (callPackage ./restore-package.nix { })
      age
      fakeroot
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
