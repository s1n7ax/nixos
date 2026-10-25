{
  config,
  lib,
  inputs,
  pkgs-unstable,
  ...
}:

with lib;

{
  config = mkIf config.features.virtualization.microvm.enable {
    microvm.host.enable = true;

    # Serve the desktop's PipeWire PulseAudio protocol on loopback so the
    # dev-vm guest can play its TTS through the host's speakers. The guest
    # reaches this on the QEMU user-network host gateway (10.0.2.2, see
    # profile/dev-vm/options.nix). Anonymous auth is safe: the listener is
    # bound to 127.0.0.1, so only local processes and the guest's SLIRP
    # connections can reach it.
    services.pipewire.extraConfig.pipewire-pulse."10-microvm-tcp" =
      mkIf config.features.hardware.audio.enable
        {
          "pulse.cmd" = [
            {
              cmd = "load-module";
              args = "module-native-protocol-tcp listen=127.0.0.1 port=4713 auth-anonymous=1";
            }
          ];
        };

    systemd.tmpfiles.rules = [
      "d /var/lib/microvms           0755 root root -"
      "d /var/lib/microvms/dev-vm    0755 microvm kvm -"
    ];

    microvm.vms.dev-vm = {
      autostart = true;
      specialArgs = { inherit inputs pkgs-unstable; };

      config =
        { config, ... }:
        {
          imports = [
            ../../../profile/dev-vm/configuration.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.quadlet-nix.nixosModules.quadlet
          ];

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = { inherit inputs pkgs-unstable; };
            users.${config.settings.username} = import ../../../profile/dev-vm/home.nix;
          };

          microvm = {
            hypervisor = "qemu";
            vcpu = 16;
            mem = 16384;
            writableStoreOverlay = "/nix/.rw-store";

            volumes = [
              {
                mountPoint = "/home";
                image = "/var/lib/microvms/dev-vm/home.img";
                size = 51200;
                fsType = "ext4";
                autoCreate = true;
              }
              {
                mountPoint = "/nix/.rw-store";
                image = "/var/lib/microvms/dev-vm/nix-store.img";
                size = 40960;
                fsType = "ext4";
                autoCreate = true;
                mkfsExtraArgs = [
                  "-i"
                  "4096"
                ];
              }
              {
                mountPoint = "/var/lib/docker";
                image = "/var/lib/microvms/dev-vm/docker.img";
                size = 20480;
                fsType = "ext4";
                autoCreate = true;
              }
              {
                mountPoint = "/persist/ssh-host-keys";
                image = "/var/lib/microvms/dev-vm/ssh-host-keys.img";
                size = 64;
                fsType = "ext4";
                autoCreate = true;
              }
            ];

            shares = [
              {
                proto = "virtiofs";
                tag = "store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              }
            ];

            interfaces = [
              {
                type = "user";
                id = "qemu-dev-vm";
                mac = "02:00:00:00:00:01";
              }
            ];

            # Bound to loopback so only desktop itself can reach the guest.
            # Nothing on the LAN can ssh to the microvm directly.
            forwardPorts = [
              {
                from = "host";
                host.address = "127.0.0.1";
                host.port = 2222;
                guest.port = 22;
              }
              {
                from = "host";
                host.address = "127.0.0.1";
                host.port = 5173;
                guest.port = 5173;
              }
            ]
            ++ optionals config.features.development.ai.headroom.enable [
              {
                from = "host";
                host.address = "127.0.0.1";
                host.port = config.features.development.ai.headroom.port;
                guest.port = config.features.development.ai.headroom.port;
              }
            ]
            ++ map (p: {
              from = "host";
              host.address = "127.0.0.1";
              host.port = p;
              guest.port = p;
            }) (lib.range 3000 3100);
          };
        };
    };
  };
}
