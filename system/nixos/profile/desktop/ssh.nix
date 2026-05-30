{ ... }:
{
  programs.ssh = {
    knownHosts = {
      "github.com ssh-ed25519" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };

      "codeberg.org ssh-ed25519" = {
        hostName = [ "codeberg.org" ];
        publicKey = "SHA256:mIlxA9k46MmM6qdJOdMnAQpzGxF4WIVVL+fj+wZbw0g";
      };

      "192.168.1.110 ssh-ed25519" = {
        hostNames = [ "192.168.1.110 " ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHAsksMYthB3wMx9p1PQU/WNtVdfVt3dNXIE/CXUKB45";
      };

    };
  };
}
