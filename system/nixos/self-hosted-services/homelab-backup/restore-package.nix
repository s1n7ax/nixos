{
  writeShellApplication,
  age,
  coreutils,
  gnutar,
  jq,
  zstd,
}:
writeShellApplication {
  name = "homelab-restore";
  runtimeInputs = [
    age
    coreutils
    gnutar
    jq
    zstd
  ];
  text = builtins.readFile ./homelab-restore.sh;
}
