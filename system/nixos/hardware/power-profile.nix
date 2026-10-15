{
  config,
  lib,
  pkgs,
  ...
}:
# Runtime CPU + GPU power profiles for the desktop (Ryzen on amd-pstate-epp,
# NVIDIA power limit). `power-profile set <profile>` saves the pick in
# /var/lib/power-profile/state and starts the root unit
# power-profile-apply@<profile>, which polkit lets the main user start
# without a password. The picked profile is re-applied at boot and the
# applied one after resume. Stock CPU values are saved once per boot in
# /run/power-profile/stock; `disabled` restores them.
#
# The CLI also switches Hyprland between display.ecoMode without effects and
# display.fullMode (Hyprland's power-display.lua) and shows a notification on
# every change. `power-profile menu` (SUPER+ALT+E) is the rofi front end.
#
# Journal: `journalctl -b -u 'power-profile-*'`.
let
  cfg = config.features.hardware.power-profile;
  username = config.settings.username;

  stateDir = "/var/lib/power-profile";
  runDir = "/run/power-profile";

  nvidiaSmi = lib.optionalString config.features.hardware.nvidia.enable "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";

  env = {
    POWER_PROFILE_STATE_FILE = "${stateDir}/state";
    POWER_PROFILE_RUN_DIR = runDir;
    POWER_PROFILE_DEFAULT = cfg.defaultProfile;
    POWER_PROFILE_SHORT_BOOSTS_MAX_KHZ = toString cfg.shortBoostsMaxFreq;
    POWER_PROFILE_STRICT_MAX_KHZ = toString cfg.strictMaxFreq;
    POWER_PROFILE_SHORT_BOOSTS_GPU_W = toString cfg.shortBoostsGpuPowerLimit;
    POWER_PROFILE_NVIDIA_SMI = nvidiaSmi;
  };

  exportEnv = lib.concatStrings (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") env
  );

  # Display switching and notifications run in the user CLI only (boot and
  # resume have no Hyprland session). hyprctl comes from the system Hyprland,
  # the compositor that actually runs.
  cliEnv = {
    POWER_PROFILE_DISPLAY_FILE = cfg.display.file;
    POWER_PROFILE_DISPLAY_ECO_MODE = cfg.display.ecoMode;
    POWER_PROFILE_DISPLAY_FULL_MODE = cfg.display.fullMode;
    POWER_PROFILE_HYPRCTL = lib.optionalString config.programs.hyprland.enable "${config.programs.hyprland.package}/bin/hyprctl";
  };

  exportCliEnv = lib.concatStrings (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") cliEnv
  );

  ctl = pkgs.writeShellApplication {
    name = "power-profile-ctl";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
    text = exportEnv + builtins.readFile ./power-profile/power-profile-ctl.sh;
  };

  cli = pkgs.writeShellApplication {
    name = "power-profile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      config.systemd.package
      # notify-send; rofi (menu) comes from the user's PATH.
      pkgs.libnotify
    ];
    text = exportEnv + exportCliEnv + builtins.readFile ./power-profile/power-profile.sh;
  };

  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];

  unitRegex = "^power-profile-apply@(${lib.concatStringsSep "|" cfg.profiles})\\.service$";
in
{
  config = lib.mkIf cfg.enable {
    # On in every profile, "disabled" included, like a BIOS toggle.
    boot.kernelParams = lib.optional (
      cfg.pcieAspmPolicy != null
    ) "pcie_aspm.policy=${cfg.pcieAspmPolicy}";

    environment.systemPackages = [ cli ];

    # The CLI writes the state as the main user; the root side only reads it
    # and accepts known profile names.
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0775 root ${config.users.users.${username}.group} -"
      "d ${runDir} 0755 root root -"
    ];

    systemd.services = {
      # %i, not %I: unescaping would turn "short-boosts" into "short/boosts".
      "power-profile-apply@" = {
        description = "Apply power profile %i";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe ctl} apply %i";
        };
      };

      power-profile-boot = {
        description = "Save stock power settings and apply the picked power profile";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        # Runs once per boot; a switch must not re-apply over a game's
        # full power.
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe ctl} boot";
        };
      };

      power-profile-resume = {
        description = "Re-apply the power profile after resume";
        wantedBy = sleepTargets;
        after = sleepTargets ++ [ "nvidia-resume.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe ctl} resume";
        };
      };
    };

    # No `subject.active` check, so a user service (the game watcher) can
    # switch profiles too.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${username}") {
          var verb = action.lookup("verb");
          if ((verb == "start" || verb == "restart") &&
              /${unitRegex}/.test(action.lookup("unit"))) {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };
}
