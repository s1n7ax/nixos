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
    "ssh/do/homelab_hub/host" = { };
  };

  # homelab-hub droplet. Its IP lives in nix-secrets, so the Host block is
  # rendered outside the store and pulled into ~/.ssh/config via Include
  # (see profile/desktop/home.nix).
  sops.templates."ssh-homelab-hub" = {
    owner = config.settings.username;
    mode = "0400";
    path = "/home/${config.settings.username}/.ssh/homelab-hub.conf";
    content = ''
      Host homelab-hub
        HostName ${config.sops.placeholder."ssh/do/homelab_hub/host"}
        User s1n7ax
        IdentityFile ~/.ssh/id_ed25519
        IdentitiesOnly yes
    '';
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

      };
    };

    gnupg.agent.settings = {
      # expires after 15 min
      default-cache-ttl = 900000;
    };
  };
}
