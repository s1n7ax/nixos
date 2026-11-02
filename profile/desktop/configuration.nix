{ config, ... }:
{
  imports = [
    ../common/configuration.nix
    ./hardware-configuration.nix
    ./options.nix
  ];

  # Operator key for the riya-mandiya staging droplet (Syntxio/riya-mandiya,
  # infra/keys/s1n7ax.pub holds the public half). Decrypted from nix-secrets
  # into /run/secrets on every activation and linked into ~/.ssh, so the
  # private half never sits on disk unencrypted.
  sops.secrets = {
    "ssh/do/riyamandiya_staging/private" = {
      owner = config.settings.username;
      mode = "0400";
      path = "/home/${config.settings.username}/.ssh/riyamandiya-staging";
    };
    "ssh/do/riyamandiya_staging/public" = {
      owner = config.settings.username;
      mode = "0444";
      path = "/home/${config.settings.username}/.ssh/riyamandiya-staging.pub";
    };
  };

  programs = {
    ssh = {
      knownHosts = {
        "github.com ssh-ed25519" = {
          hostNames = [ "github.com" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };

        "codeberg.org ssh-ed25519" = {
          hostNames = [ "codeberg.org" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
        };

        "homelab ssh-ed25519" = {
          hostNames = [
            "homelab"
            "homelab.local"
            "192.168.1.110"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHAsksMYthB3wMx9p1PQU/WNtVdfVt3dNXIE/CXUKB45";
        };

        # Pre-generated in Syntxio/riya-mandiya (infra/keys/staging_host_ed25519.pub)
        # and installed on the droplet by nixos-anywhere, so it survives a
        # destroy-and-recreate. Name only: the IP changes with every droplet.
        "staging.riyamandiya.com ssh-ed25519" = {
          hostNames = [ "staging.riyamandiya.com" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGn7fcJcvg5/ZJpd/p6CVDmz2eG8LAAKODSydkOd7oej";
        };

      };
    };

    gnupg.agent.settings = {
      # expires after 15 min
      default-cache-ttl = 900000;
    };
  };
}
