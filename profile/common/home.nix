{ settings, ... }:
{
  home.username = settings.username;
  home.homeDirectory = "/home/${settings.username}";
  home.stateVersion = "24.05";

  age = {
    # identityPaths = [ "/home/s1n7ax/.ssh/id_ed25519" ];
    secrets = {
      secret1 = {
        file = ../../secrets/secret1.age;
      };
    };
  };
}
