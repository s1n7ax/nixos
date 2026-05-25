{ config, lib, inputs, pkgs-unstable, ... }:

with lib;

{
  config = mkIf config.features.virtualization.microvm.enable {
    microvm.host.enable = true;

    systemd.tmpfiles.rules = [
      "d /var/lib/microvms           0755 root root -"
      "d /var/lib/microvms/dev-vm    0755 root root -"
    ];

    microvm.vms.dev-vm = {
      autostart = true;
      specialArgs = { inherit inputs pkgs-unstable; };

      config = { config, ... }: {
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
          vcpu = 4;
          mem = 8192;
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
              size = 20480;
              fsType = "ext4";
              autoCreate = true;
            }
          ];

          shares = [{
            proto = "virtiofs";
            tag = "store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }];

          interfaces = [{
            type = "user";
            id = "qemu-dev-vm";
            mac = "02:00:00:00:00:01";
          }];

          forwardPorts = [
            { from = "host"; host.port = 2222; guest.port = 22; }
          ] ++ map (p: {
            from = "host";
            host.port = p;
            guest.port = p;
          }) (lib.range 3000 3100);
        };
      };
    };
  };
}
