{
  writeShellApplication,
  age,
  coreutils,
  gnugrep,
  gnutar,
  jq,
  rclone,
  sops,
  sqlite,
  ssh-to-age,
  zstd,
}:
writeShellApplication {
  name = "homelab-backup";
  runtimeInputs = [
    age
    coreutils
    gnugrep
    gnutar
    jq
    rclone
    sops
    sqlite
    ssh-to-age
    zstd
  ];
  text = builtins.readFile ./homelab-backup.sh;
}
