{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  config = mkIf config.features.hardware.mt7921e.enable {
    boot.extraModprobeConfig = ''
      options mt7921e disable_aspm=1
    '';

    systemd.services.mt7921e-recover = {
      description = "Reload mt7921e when the Wi-Fi device fails to probe at boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      path = [ pkgs.kmod ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        have_wifi() {
          for netdir in /sys/bus/pci/drivers/mt7921e/0000:*/net/*; do
            [ -e "$netdir" ] && return 0
          done
          return 1
        }

        wait_for_wifi() {
          for _ in $(seq 1 15); do
            have_wifi && return 0
            sleep 1
          done
          return 1
        }

        wait_for_wifi && exit 0

        for attempt in 1 2 3; do
          echo "mt7921e: no Wi-Fi interface found, reloading module (attempt $attempt)"
          modprobe -r mt7921e || true
          sleep 2
          modprobe mt7921e
          wait_for_wifi && exit 0
        done

        echo "mt7921e: Wi-Fi interface still missing after 3 reloads" >&2
        exit 1
      '';
    };
  };
}
