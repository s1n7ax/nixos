{ ... }:
{
  # allow users in wheel group to use udisks2 to mount device without root
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  services.udisks2.enable = true;
}
